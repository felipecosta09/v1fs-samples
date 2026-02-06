import json
import base64
import os
import re
from datetime import datetime
import functions_framework
from google.cloud import storage
from cloudevents.http import CloudEvent

storage_client = storage.Client()

# Environment variables
QUARANTINE_BUCKET = os.environ.get('QUARANTINE_BUCKET', '')
DELETE_MALICIOUS = os.environ.get('DELETE_MALICIOUS', 'false').lower() == 'true'


def sanitize_metadata_value(value: str) -> str:
    """
    Sanitize metadata values for GCS compatibility.
    GCS custom metadata values must be valid HTTP header values.
    """
    sanitized = str(value)

    # Replace invalid characters
    sanitized = sanitized.replace(',', ' ')
    sanitized = sanitized.replace('(', ' ')
    sanitized = sanitized.replace(')', ' ')
    sanitized = sanitized.replace('[', ' ')
    sanitized = sanitized.replace(']', ' ')
    sanitized = sanitized.replace('{', ' ')
    sanitized = sanitized.replace('}', ' ')
    sanitized = sanitized.replace("'", '')
    sanitized = sanitized.replace('"', '')
    sanitized = sanitized.replace('\n', ' ')
    sanitized = sanitized.replace('\r', ' ')
    sanitized = sanitized.replace('\t', ' ')

    # Keep only printable ASCII characters
    sanitized = re.sub(r'[^\x20-\x7E]', '', sanitized)

    # Clean up multiple spaces
    sanitized = re.sub(r'\s+', ' ', sanitized)

    # Strip leading/trailing spaces and limit length
    return sanitized.strip()[:256]


def parse_gcs_path(file_url: str) -> tuple[str, str]:
    """Parse gs:// URL into bucket and object name."""
    # Handle gs://bucket/object format
    if file_url.startswith('gs://'):
        path = file_url[5:]
        parts = path.split('/', 1)
        bucket_name = parts[0]
        object_name = parts[1] if len(parts) > 1 else ''
        return bucket_name, object_name
    raise ValueError(f"Invalid GCS URL: {file_url}")


def apply_metadata(bucket_name: str, object_name: str, metadata: dict) -> None:
    """Apply metadata to GCS object, preserving non-fss metadata."""
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(object_name)
    blob.reload()

    # Get existing metadata and filter out fss- keys
    existing_metadata = blob.metadata or {}
    cleaned_metadata = {
        k: v for k, v in existing_metadata.items()
        if not k.startswith('fss-')
    }

    # Merge with new metadata
    cleaned_metadata.update(metadata)

    # Apply metadata
    blob.metadata = cleaned_metadata
    blob.patch()


def quarantine_file(source_bucket: str, object_name: str, scan_result: dict) -> bool:
    """
    Move malicious file to quarantine bucket.
    Returns True if quarantined successfully.
    """
    if not QUARANTINE_BUCKET:
        print("Quarantine bucket not configured, skipping quarantine")
        return False

    try:
        source_bucket_obj = storage_client.bucket(source_bucket)
        source_blob = source_bucket_obj.blob(object_name)

        # Create quarantine path with timestamp
        timestamp = datetime.utcnow().strftime('%Y/%m/%d/%H%M%S')
        quarantine_path = f"{timestamp}/{source_bucket}/{object_name}"

        dest_bucket = storage_client.bucket(QUARANTINE_BUCKET)

        # Copy to quarantine bucket with scan metadata
        new_blob = source_bucket_obj.copy_blob(
            source_blob,
            dest_bucket,
            quarantine_path
        )

        # Add quarantine metadata
        new_blob.metadata = {
            'fss-quarantine-source': f"gs://{source_bucket}/{object_name}",
            'fss-quarantine-date': datetime.utcnow().isoformat(),
            'fss-scan-result': 'malicious',
            'fss-malwares': sanitize_metadata_value(
                ', '.join([m.get('malwareName', 'unknown') for m in scan_result.get('foundMalwares', [])])
            ),
        }
        new_blob.patch()

        print(f"Quarantined: gs://{source_bucket}/{object_name} -> gs://{QUARANTINE_BUCKET}/{quarantine_path}")

        # Delete from source if configured
        if DELETE_MALICIOUS:
            source_blob.delete()
            print(f"Deleted malicious file from source: gs://{source_bucket}/{object_name}")

        return True

    except Exception as e:
        print(f"Error quarantining file: {e}")
        return False


@functions_framework.cloud_event
def tag(cloud_event: CloudEvent) -> None:
    """
    Cloud Function triggered by Pub/Sub message.
    Applies scan result metadata to GCS objects.
    Optionally quarantines malicious files.
    """
    # Decode Pub/Sub message
    message_data = cloud_event.data.get('message', {}).get('data', '')
    if not message_data:
        print("No message data received")
        return

    decoded_data = base64.b64decode(message_data).decode('utf-8')
    data = json.loads(decoded_data)

    # Extract scan results
    file_url = data.get('file_url', '')
    scanning_result = data.get('scanning_result', {})

    # Parse bucket and object from URL
    try:
        bucket_name, object_name = parse_gcs_path(file_url)
    except ValueError as e:
        print(f"Error parsing file URL: {e}")
        return

    print(f"Processing metadata for: gs://{bucket_name}/{object_name}")

    # Extract scan details
    scan_result_code = scanning_result.get('scanResult', -1)
    found_malwares = scanning_result.get('foundMalwares', [])
    scan_timestamp = scanning_result.get('scanTimestamp', '')

    # Format scan date
    scan_date_formatted = ''
    if scan_timestamp:
        try:
            scan_datetime = datetime.fromisoformat(scan_timestamp.replace('Z', '+00:00'))
            scan_date_formatted = scan_datetime.strftime('%Y/%m/%d %H:%M:%S')
        except (ValueError, TypeError):
            scan_date_formatted = scan_timestamp

    # Determine scan result message
    is_malicious = scan_result_code == 1 or bool(found_malwares)

    if scan_result_code == 0 and not found_malwares:
        scan_result_message = "clean"
        scan_detail_message = "-"
    elif is_malicious:
        scan_result_message = "malicious"
        malware_names = [m.get('malwareName', 'unknown') for m in found_malwares]
        scan_detail_message = sanitize_metadata_value(', '.join(malware_names)) if malware_names else "-"
    else:
        scan_result_message = "unknown"
        scan_detail_message = f"Scan code: {scan_result_code}"

    # Handle malicious files - quarantine before tagging
    quarantined = False
    if is_malicious and QUARANTINE_BUCKET:
        quarantined = quarantine_file(bucket_name, object_name, scanning_result)

        # If file was deleted, we can't tag it
        if quarantined and DELETE_MALICIOUS:
            print(f"File deleted after quarantine, skipping metadata tagging")
            return

    # Build metadata tags
    metadata = {
        'fss-scan-result': sanitize_metadata_value(scan_result_message),
        'fss-scan-detail-code': sanitize_metadata_value(str(scan_result_code)),
        'fss-scan-date': sanitize_metadata_value(scan_date_formatted),
        'fss-scan-detail-message': sanitize_metadata_value(scan_detail_message),
        'fss-scanned': 'true',
    }

    if quarantined:
        metadata['fss-quarantined'] = 'true'

    print(f"Applying metadata: {metadata}")

    try:
        apply_metadata(bucket_name, object_name, metadata)
        print(f"Successfully applied metadata to gs://{bucket_name}/{object_name}")
    except Exception as e:
        print(f"Error applying metadata: {e}")
        raise
