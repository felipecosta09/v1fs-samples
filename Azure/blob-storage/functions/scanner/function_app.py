import azure.functions as func
import amaas.grpc
import json
import os
import time
import logging
from azure.storage.blob import BlobServiceClient
from azure.storage.queue import QueueClient
import base64

app = func.FunctionApp()

# Environment variables
v1fs_region = os.environ.get('V1FS_REGION', 'us-east-1')
v1fs_apikey = os.environ.get('V1FS_APIKEY', '')
sdk_tags = os.environ.get('SDK_TAGS', '').split(',')
queue_connection = os.environ.get('SCAN_RESULTS_QUEUE_CONNECTION', '')
queue_name = os.environ.get('SCAN_RESULTS_QUEUE_NAME', 'scan-results')
storage_connection = os.environ.get('MONITORED_STORAGE_CONNECTION', '')

_blob_client = None


def get_blob_service_client():
    """Get or create a BlobServiceClient."""
    global _blob_client
    if _blob_client is None and storage_connection:
        _blob_client = BlobServiceClient.from_connection_string(storage_connection)
    return _blob_client


def download_blob(container: str, blob_name: str) -> bytes:
    """Download blob content into memory."""
    client = get_blob_service_client()
    if not client:
        raise ValueError("Storage connection not configured")
    blob_client = client.get_blob_client(container=container, blob=blob_name)
    return blob_client.download_blob().readall()


def scan_file(blob_content: bytes, blob_name: str) -> dict:
    """Scan file using V1FS gRPC client."""
    init = amaas.grpc.init_by_region(v1fs_region, v1fs_apikey, True)
    try:
        s = time.perf_counter()
        result = amaas.grpc.scan_buffer(init, blob_content, blob_name, sdk_tags, pml=True, feedback=True)
        elapsed = time.perf_counter() - s
        result_json = json.loads(result)
        result_json['scanDuration'] = f"{elapsed:0.2f}s"
        return result_json
    finally:
        amaas.grpc.quit(init)


def send_to_queue(message: dict) -> None:
    """Send scan result to the results queue."""
    if not queue_connection:
        logging.warning("Queue connection not configured, skipping queue send")
        return
    queue_client = QueueClient.from_connection_string(queue_connection, queue_name)
    message_bytes = json.dumps(message).encode('utf-8')
    encoded_message = base64.b64encode(message_bytes).decode('utf-8')
    queue_client.send_message(encoded_message)


def parse_blob_url(url: str) -> tuple:
    """Parse blob URL into container and blob name."""
    # URL: https://<account>.blob.core.windows.net/<container>/<blob>
    from urllib.parse import urlparse, unquote
    parsed = urlparse(url)
    path_parts = parsed.path.lstrip('/').split('/', 1)
    container = path_parts[0]
    blob_name = unquote(path_parts[1]) if len(path_parts) > 1 else ''
    return container, blob_name


@app.function_name(name="scanner")
@app.event_grid_trigger(arg_name="event")
def scanner(event: func.EventGridEvent) -> None:
    """
    Azure Function triggered by Event Grid for blob creation.
    Monitors ALL containers in the storage account.
    """
    logging.info(f"Event Grid trigger: {event.event_type}")

    # Only process blob created events
    if event.event_type != "Microsoft.Storage.BlobCreated":
        logging.info(f"Ignoring event type: {event.event_type}")
        return

    event_data = event.get_json()
    blob_url = event_data.get('url', '')

    if not blob_url:
        logging.error("No blob URL in event data")
        return

    # Parse container and blob name from URL
    try:
        container, blob_name = parse_blob_url(blob_url)
    except Exception as e:
        logging.error(f"Error parsing blob URL: {e}")
        return

    logging.info(f"Processing blob: {container}/{blob_name}")

    try:
        # Download the blob
        blob_content = download_blob(container, blob_name)
        blob_size = len(blob_content)
        logging.info(f"Downloaded blob, size: {blob_size} bytes")

        # Scan the file
        scan_result = scan_file(blob_content, blob_name)
        scan_verdict = scan_result.get('scanResult', 'unknown')
        logging.info(f"Scan result: {scan_verdict}")

        # Format the result message
        result_message = {
            "timestamp": event.event_time.isoformat() if event.event_time else time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
            "event_id": event.id,
            "blob_url": blob_url,
            "container": container,
            "object_name": blob_name,
            "blob_attributes": {
                "content_length": blob_size,
                "content_type": event_data.get('contentType', ''),
                "etag": event_data.get('eTag', ''),
            },
            "scanning_result": scan_result,
        }

        logging.info(f"Scan complete: {json.dumps(result_message)}")

        # Send to queue for tag function
        send_to_queue(result_message)
        logging.info(f"Sent result to queue: {queue_name}")

    except Exception as e:
        logging.error(f"Error processing blob: {e}")
        raise
