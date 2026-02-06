import amaas.grpc
import json
import os
import boto3
import time

v1_region = os.environ.get('v1_region')
mount_dir = "/mnt/efs"
secret_manager = boto3.client('secretsmanager')
sns = boto3.client('sns')
topic_arn = os.environ['topic_arn']

def lambda_handler(event, context):
    # Manual scan status
    scan_type = event.get('scan_type')
    
    # Get the API key from AWS Secrets Manager
    def get_apikey():
        secret_manager_response = secret_manager.get_secret_value(SecretId=secret_id)
        apikey_secret = secret_manager_response["SecretString"]
        return apikey_secret
    
    # init the gRPC client
    def init(v1_region, apikey):
        return amaas.grpc.init_by_region(region=v1_region, api_key=apikey)

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
    init = init(v1_region, apikey)
    
    # dictionary to store all scan results
    all_scan_results = {}

    # If manual scan is set to true, scan the files
    if scan_type == "manual":
        print("Manual scan is set to true, scanning selected files...")
        files = event.get('files')
        if files:
            for file in files:
                print("Processing target: ", file)
                scan = json.loads(scan_file(file, init))
                print("Scan Result: ", scan)
                print("Sending result to SNS...")
                processed_event = str(scan)
                sns.publish(TopicArn=topic_arn,Message=processed_event)
                print(f"Results of the file {file} published on SNS")
                all_scan_results[file] = scan
        else:
            print("Manual scan is enabled, but no targets were provided")
            
    else:
        # Full scan operation
        # for each file in the mount directory, if is a file, scan it
        print("Full scan mode: scanning all files...")
        for root, dirs, files in os.walk(mount_dir):
            for file in files:
                file = f"{root}/"+file
                print("Processing Target: ", file)
                scan = json.loads(scan_file(file, init))
                print("Scan Result: ", scan)
                processed_event = str(scan)
                sns.publish(TopicArn=topic_arn,Message=processed_event)
                print(f"Results of the file {file} published on SNS")
                all_scan_results[file] = scan
    
    # quit the gRPC client
    quit = quit(init)