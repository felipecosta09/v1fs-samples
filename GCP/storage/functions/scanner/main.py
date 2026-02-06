import amaas.grpc
import json
import os
import time
import functions_framework
from google.cloud import storage
from google.cloud import pubsub_v1
from cloudevents.http import CloudEvent

# Initialize clients
storage_client = storage.Client()
publisher = pubsub_v1.PublisherClient()

# Environment variables
v1fs_region = os.environ.get('V1FS_REGION', 'us-east-1')
v1fs_apikey = os.environ.get('V1FS_APIKEY')
pubsub_topic = os.environ.get('PUBSUB_TOPIC')
sdk_tags = os.environ.get('SDK_TAGS', '').split(',')


def create_buffer(bucket_name: str, object_name: str) -> bytes:
    """Download object content into memory buffer."""
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(object_name)
    return blob.download_as_bytes()


def scan_file(bucket_name: str, object_name: str) -> dict:
    """Scan file using V1FS gRPC client."""
    init = amaas.grpc.init_by_region(v1fs_region, v1fs_apikey, True)
    try:
        s = time.perf_counter()
        buffer = create_buffer(bucket_name, object_name)
        result = amaas.grpc.scan_buffer(init, buffer, object_name, sdk_tags, pml=True, feedback=True)
        elapsed = time.perf_counter() - s
        result_json = json.loads(result)
        result_json['scanDuration'] = f"{elapsed:0.2f}s"
        return result_json
    finally:
        amaas.grpc.quit(init)


def publish_result(message: dict) -> None:
    """Publish scan result to Pub/Sub topic."""
    message_bytes = json.dumps(message).encode('utf-8')
    future = publisher.publish(pubsub_topic, message_bytes)
    future.result()


@functions_framework.cloud_event
def scanner(cloud_event: CloudEvent) -> None:
    """
    Cloud Function triggered by GCS object finalization.
    Scans the uploaded file and publishes results to Pub/Sub.
    """
    data = cloud_event.data

    bucket_name = data['bucket']
    object_name = data['name']
    event_time = cloud_event['time']
    event_id = cloud_event['id']

    # Get object metadata
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(object_name)
    blob.reload()

    print(f"Processing file: gs://{bucket_name}/{object_name}")

    # Scan the file
    scan_result = scan_file(bucket_name, object_name)

    # Format the event for Pub/Sub
    processed_event = {
        "timestamp": event_time,
        "event_id": event_id,
        "file_url": f"gs://{bucket_name}/{object_name}",
        "file_attributes": {
            "etag": blob.etag,
            "size": blob.size,
            "content_type": blob.content_type,
            "md5_hash": blob.md5_hash,
        },
        "scanning_result": scan_result,
    }

    print(f"Scan result: {json.dumps(processed_event)}")

    # Publish to Pub/Sub
    publish_result(processed_event)
    print(f"Published scan result for gs://{bucket_name}/{object_name}")
