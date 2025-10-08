import boto3
import json
from datetime import datetime

s3 = boto3.client('s3')

def lambda_handler(event, context):
    
    # Parsing the SNS payload
    sns_message = event['Records'][0]['Sns']['Message']
    sns_message_clean = sns_message.replace("'", "\"")
    data = json.loads(sns_message_clean)
    
    # Get the scanning result
    scanning_result = data['scanning_result']
    found_malwares = scanning_result['foundMalwares']
    file_name = scanning_result['fileName']
    scan_result_code = scanning_result['scanResult']
    scan_timestamp = scanning_result['scanTimestamp']
    
    # Get bucket and object from file_url
    file_url = data['file_url']
    bucket_name = file_url.split('//')[-1].split('.')[0]
    
    print(f"Processing file: {file_name} in bucket: {bucket_name}")
    print(f"Found malwares: {found_malwares}")
    print(f"Scan result code: {scan_result_code}")
    
    # Function to publish tags
    def publish_tag(tag):
        response = s3.put_object_tagging(
            Bucket=bucket_name,
            Key=file_name,
            Tagging={'TagSet': tag}
        )
        return response
        
    def get_existing_tags(bucket, key):
        try:
            existing_tags = s3.get_object_tagging(Bucket=bucket, Key=key)['TagSet']
        except:
            existing_tags = []
        return existing_tags
    
    # Convert scan timestamp to readable format
    scan_datetime = datetime.fromisoformat(scan_timestamp.replace('Z', '+00:00'))
    scan_date_formatted = scan_datetime.strftime('%Y/%m/%d %H:%M:%S')
    
    # Determine scan result message based on scan result code and found malwares
    if scan_result_code == 0 and found_malwares == []:
        scan_result_message = "no issues found"
        scan_detail_message = "-"
    elif scan_result_code == 1 or found_malwares != []:
        scan_result_message = "malicious"
        scan_detail_message = f"Found {len(found_malwares)} malware(s): " + ", ".join([malware.get('malwareName', 'unknown') for malware in found_malwares])
    else:
        # Handle edge cases
        scan_result_message = "unknown"
        scan_detail_message = f"Scan code: {scan_result_code}, Malwares: {len(found_malwares)}"
    
    # Define new tags in your preferred format
    new_tags = [
        {'Key': 'fss-scan-detail-code', 'Value': str(scan_result_code)},
        {'Key': 'fss-scan-date', 'Value': scan_date_formatted},
        {'Key': 'fss-scan-result', 'Value': scan_result_message},
        {'Key': 'fss-scan-detail-message', 'Value': scan_detail_message},
        {'Key': 'fss-scanned', 'Value': 'true'}
    ]
    
    # Get existing tags
    current_tags = get_existing_tags(bucket_name, file_name)
    
    # Remove any existing fss- tags to avoid duplicates
    def remove_fss_tags(tags):
        return [tag for tag in tags if not tag['Key'].startswith('fss-')]
    
    # Clean existing tags and add new ones
    cleaned_tags = remove_fss_tags(current_tags)
    final_tags = cleaned_tags + new_tags
    
    # Check if we're within the 10 tag limit
    if len(final_tags) <= 10:
        publish_tag(final_tags)
        print(f"Applied tags to {file_name}:")
        for tag in new_tags:
            print(f"  {tag['Key']}: {tag['Value']}")
    else:
        print(f"Cannot apply tags - would exceed 10 tag limit. Current tags: {len(cleaned_tags)}, New tags: {len(new_tags)}")
    
    return {
        'statusCode': 200,
        'body': json.dumps(f'Tagging completed for {file_name}')
    }
