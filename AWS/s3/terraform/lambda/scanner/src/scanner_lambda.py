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


# Collect environment variables
tags = [os.environ['sdk_tags'].replace('~', ',')]
v1fs_region = os.environ['v1fs_region']

def lambda_handler(event, context):
        
    records = event['Records']
    
    # Iterate through the records
    for record in records:
        message_body = json.loads(record['body'])
    
    # Set the variables based on the event received
    topic_arn = os.environ['topic_arn']
    secret_id = os.environ['secret_name']
    queue_url = os.environ['queue_url']
    receipt_handle = event["Records"][0]['receiptHandle']
    bucket = message_body["detail"]["bucket"]["name"]
    key = message_body["detail"]["object"]["key"]
    aws_region = event["Records"][0]["awsRegion"]

        
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
    
    # Create a buffer for the file
    def create_buffer(key, bucket):
        s3_object = s3.Object(bucket, key)
        object_buffer = s3_object.get().get('Body').read()
        return object_buffer

    # Scan the file using the V1FS gRPC client   
    def scan_file(key, bucket):
        init = amaas.grpc.init_by_region(v1fs_region, apikey, True)
        s = time.perf_counter()
        object = s3.Object(bucket, key)
        buffer = create_buffer(key, bucket)
        result = amaas.grpc.scan_buffer(init,buffer,key,tags, pml=True, feedback=True)
        elapsed = time.perf_counter() - s
        result_json = json.loads(result)
        result_json['scanDuration'] = f"{elapsed:0.2f}s"
        amaas.grpc.quit(init)
        return json.dumps(result_json)
    
    # Scan the file and store the result
    scan_result = json.loads(scan_file(key, bucket))
    
    # Format the event to be send to SNS
    processed_event = str({
    "timestamp": message_body["time"],
    "sqs_message_id": event["Records"][0]["messageId"],
    "xamz_request_id": message_body["id"],
    "file_url": f"https://{bucket}.s3.{aws_region}.amazonaws.com/{key}",
    "file_attributes": {
        "etag": message_body["detail"]["object"]["etag"]
    },
    "scanning_result": scan_result,
    "source_ip": message_body["detail"]["source-ip-address"]
    })
    
    # Print to Lambda Logs
    print(processed_event)
    
    # Publish the event to SNS
    sns.publish(TopicArn=topic_arn,Message=processed_event)
