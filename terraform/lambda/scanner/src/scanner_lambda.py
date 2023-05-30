import boto3
import amaas.grpc
import json
import os
import time

# Create the boto3 clients
s3 = boto3.resource('s3')
sns = boto3.client('sns')
secret_manager = boto3.client('secretsmanager')
sqs = boto3.client('sqs')

def lambda_handler(event, context):
        
    records = event['Records']
    
    # Iterate through the records
    for record in records:
        message_body = json.loads(record['body'])
    
    # Set the variables
    topic_arn = os.environ['topic_arn']
    secret_id = os.environ['secret_name']
    queue_url = os.environ['queue_url']
    receipt_handle = event["Records"][0]['receiptHandle']
    bucket = message_body["detail"]["bucket"]["name"]
    key = message_body["detail"]["object"]["key"]
    cloudone_endpoint = f"antimalware.{os.environ['cloudone_region']}.cloudone.trendmicro.com:443"
    region = event["Records"][0]["awsRegion"]
        
    # Function to delete the sqs message after consumption
    def delete_message(queue_url, receipt_handle):
        sqs.delete_message(
            QueueUrl=queue_url,
            ReceiptHandle=receipt_handle
            )

    # Get the API key from AWS Secrets Manager
    def get_apikey():
        secret_manager_response = secret_manager.get_secret_value(SecretId=secret_id)
        apikey_secret = secret_manager_response["SecretString"]
        return apikey_secret

    # Assign the API key to a variable
    apikey = get_apikey()
    
    # Delete the message
    delete_message(queue_url, receipt_handle)

    # Scan the file using the AMAAS gRPC client   
    def scan_file(key, bucket):
        init = amaas.grpc.init(cloudone_endpoint, apikey, True)
        s = time.perf_counter()
        object = s3.Object(bucket, key)
        buffer = object.get().get('Body').read()
        result = amaas.grpc.scan_buffer(buffer, key, init)
        elapsed = time.perf_counter() - s
        result_json = json.loads(result)
        result_json['scanDuration'] = f"{elapsed:0.2f}s"
        amaas.grpc.quit(init)
        return json.dumps(result_json)
    
    # Scan the file ad store the result
    scan_result = json.loads(scan_file(key, bucket))
    
    processed_event = str({
    "timestamp": message_body["time"],
    "sqs_message_id": event["Records"][0]["messageId"],
    "xamz_request_id": message_body["id"],
    "file_url": f"https://{bucket}.s3.{region}.amazonaws.com/{key}",
    "file_attributes": {
        "etag": message_body["detail"]["object"]["etag"]
    },
    "scanner_status": 0,
    "scanner_status_message": "successful scan",
    "scanning_result": {
        "TotalBytesOfFile": message_body["detail"]["object"]["size"],
        "Findings": [scan_result],
        "Error": "",
        "Codes": []
    },
    "source_ip": message_body["detail"]["source-ip-address"]
    })
    
    # Print to Lambda Logs
    print(processed_event)
    
    # Publish the event to SNS
    sns.publish(TopicArn=topic_arn,Message=processed_event)
