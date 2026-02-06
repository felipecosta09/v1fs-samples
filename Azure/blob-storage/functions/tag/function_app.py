import azure.functions as func
import json
import os
import re
import base64
import logging
from datetime import datetime
from azure.storage.blob import BlobServiceClient

app = func.FunctionApp()

# Environment variables
queue_connection = os.environ.get('SCAN_RESULTS_QUEUE_CONNECTION', '')
storage_connection = os.environ.get('MONITORED_STORAGE_CONNECTION', '')
quarantine_container = os.environ.get('QUARANTINE_CONTAINER', '')
delete_malicious = os.environ.get('DELETE_MALICIOUS', 'false').lower() == 'true'

# Blob service client
_blob_client = None


def get_blob_service_client():
    """Get or create a BlobServiceClient."""
    global _blob_client
    if _blob_client is None and storage_connection:
        _blob_client = BlobServiceClient.from_connection_string(storage_connection)
    return _blob_client


def sanitize_metadata_value(value: str) -> str:
    """Sanitize metadata values for Azure Blob compatibility."""
    sanitized = str(value)
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
    sanitized = re.sub(r'[^\x20-\x7E]', '', sanitized)
    sanitized = re.sub(r'\s+', ' ', sanitized)
    return sanitized.strip()[:256]


def sanitize_metadata_key(key: str) -> str:
    """Sanitize metadata key for Azure Blob compatibility."""
    sanitized = key.replace('-', '_')
    sanitized = re.sub(r'[^a-zA-Z0-9_]', '', sanitized)
    if sanitized and sanitized[0].isdigit():
        sanitized = '_' + sanitized
    return sanitized


def apply_metadata(container: str, blob_name: str, metadata: dict) -> None:
    """Apply metadata to blob, preserving non-fss metadata."""
    client = get_blob_service_client()
    if not client:
        raise ValueError("Storage connection not configured")

    blob_client = client.get_blob_client(container=container, blob=blob_name)

    # Get existing metadata
    properties = blob_client.get_blob_properties()
    existing_metadata = properties.metadata or {}

    # Remove existing fss_ keys
    cleaned_metadata = {
        k: v for k, v in existing_metadata.items()
        if not k.startswith('fss_')
    }

    # Add new metadata (with sanitized keys)
    for key, value in metadata.items():
        clean_key = sanitize_metadata_key(key)
        cleaned_metadata[clean_key] = sanitize_metadata_value(value)

    # Apply metadata
    blob_client.set_blob_metadata(metadata=cleaned_metadata)


def quarantine_blob(container: str, blob_name: str, scan_result: dict) -> bool:
    """Copy malicious blob to quarantine container."""
    if not quarantine_container:
        logging.info("Quarantine container not configured, skipping")
        return False

    try:
        client = get_blob_service_client()
        if not client:
            raise ValueError("Storage connection not configured")

        source_blob = client.get_blob_client(container=container, blob=blob_name)

        # Create quarantine path with timestamp
        timestamp = datetime.utcnow().strftime('%Y/%m/%d/%H%M%S')
        quarantine_path = f"{timestamp}/{container}/{blob_name}"

        dest_blob = client.get_blob_client(container=quarantine_container, blob=quarantine_path)

        # Copy blob to quarantine
        dest_blob.start_copy_from_url(source_blob.url)

        # Wait for copy to complete
        import time
        props = dest_blob.get_blob_properties()
        while props.copy.status == 'pending':
            time.sleep(0.5)
            props = dest_blob.get_blob_properties()

        if props.copy.status != 'success':
            logging.error(f"Copy failed: {props.copy.status}")
            return False

        # Set quarantine metadata
        quarantine_metadata = {
            'fss_quarantine_source': f"{container}/{blob_name}",
            'fss_quarantine_date': datetime.utcnow().isoformat(),
            'fss_scan_result': 'malicious',
            'fss_malwares': sanitize_metadata_value(
                ', '.join([m.get('malwareName', 'unknown') for m in scan_result.get('foundMalwares', [])])
            ),
        }
        dest_blob.set_blob_metadata(metadata=quarantine_metadata)

        logging.info(f"Quarantined: {container}/{blob_name} -> {quarantine_container}/{quarantine_path}")

        # Delete original if configured
        if delete_malicious:
            source_blob.delete_blob()
            logging.info(f"Deleted malicious blob: {container}/{blob_name}")

        return True

    except Exception as e:
        logging.error(f"Error quarantining blob: {e}")
        return False


@app.queue_trigger(arg_name="msg", queue_name="scan-results",
                   connection="SCAN_RESULTS_QUEUE_CONNECTION")
def tag(msg: func.QueueMessage) -> None:
    """
    Azure Function triggered by queue message.
    Applies scan result metadata to blobs.
    """
    try:
        # Decode message
        message_body = msg.get_body().decode('utf-8')
        try:
            decoded = base64.b64decode(message_body).decode('utf-8')
            data = json.loads(decoded)
        except Exception:
            data = json.loads(message_body)

        container = data.get('container', '')
        object_name = data.get('object_name', '')
        scanning_result = data.get('scanning_result', {})

        logging.info(f"Processing metadata for: {container}/{object_name}")

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

        # Determine scan result
        is_malicious = scan_result_code == 1 or bool(found_malwares)

        if scan_result_code == 0 and not found_malwares:
            scan_result_message = "clean"
            scan_detail_message = "-"
        elif is_malicious:
            scan_result_message = "malicious"
            malware_names = [m.get('malwareName', 'unknown') for m in found_malwares]
            scan_detail_message = ', '.join(malware_names) if malware_names else "-"
        else:
            scan_result_message = "unknown"
            scan_detail_message = f"Scan code: {scan_result_code}"

        # Quarantine if malicious
        quarantined = False
        if is_malicious and quarantine_container:
            quarantined = quarantine_blob(container, object_name, scanning_result)
            if quarantined and delete_malicious:
                logging.info("Blob deleted after quarantine, skipping metadata")
                return

        # Build metadata
        metadata = {
            'fss_scan_result': scan_result_message,
            'fss_scan_detail_code': str(scan_result_code),
            'fss_scan_date': scan_date_formatted,
            'fss_scan_detail_message': scan_detail_message,
            'fss_scanned': 'true',
        }

        if quarantined:
            metadata['fss_quarantined'] = 'true'

        logging.info(f"Applying metadata: {metadata}")

        try:
            apply_metadata(container, object_name, metadata)
            logging.info(f"Successfully applied metadata to {container}/{object_name}")
        except Exception as e:
            logging.error(f"Error applying metadata: {e}")
            raise

    except Exception as e:
        logging.error(f"Error processing message: {e}")
        raise
