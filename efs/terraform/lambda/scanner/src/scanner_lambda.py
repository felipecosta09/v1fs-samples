import amaas.grpc
import json
import os
import boto3
import time

cloudone_region = os.environ.get('cloudone_region')
cloudone_endpoint = f"antimalware.{cloudone_region}.cloudone.trendmicro.com:443"
mount_dir = "/mnt/efs"
secret_manager = boto3.client('secretsmanager')
sns = boto3.client('sns')
topic_arn = os.environ['topic_arn']

def lambda_handler(event, context):
    # Get the API key from AWS Secrets Manager
    def get_apikey():
        secret_manager_response = secret_manager.get_secret_value(SecretId=secret_id)
        apikey_secret = secret_manager_response["SecretString"]
        return apikey_secret
    
    # init the gRPC client
    def init(cloudone_endpoint, apikey):
        return amaas.grpc.init(cloudone_endpoint, apikey, True)

    # quit the gRPC client
    def quit(init):
        return amaas.grpc.quit(init)
        
    def calc_file_size(file):
        size = os.path.getsize(file)
        return size

    def scan_file(file, init):
        s = time.perf_counter()
        size = calc_file_size(file)
        try:
            result = amaas.grpc.scan_file(file, init)
            elapsed = time.perf_counter() - s
        except Exception as e:
            print(e)
            return None
        result_json = json.loads(result)
        result_json['scanDuration'] = f"{elapsed:0.2f}s"
        result_json['size'] = size
        return json.dumps(result_json, indent=2)
        
    # Assign the API key to a variable
    secret_id = os.environ['secret_name']
    apikey = get_apikey()
    
    # Init the Scan
    init = init(cloudone_endpoint, apikey)
    
    # dictionary to store all scan results
    all_scan_results = {}

    # for each file in the mount directory, if is a file, scan it
    for root, dirs, files in os.walk(mount_dir):
        for file in files:
            file = f"{root}/"+file
            scan = json.loads(scan_file(file, init))
            all_scan_results[file] = scan
    print(all_scan_results)

    # quit the gRPC client
    quit = quit(init)

    # Prepare scan results to SNS
    processed_event = str(all_scan_results)

    # Publish the scan results to SNS
    sns.publish(TopicArn=topic_arn,Message=processed_event)