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
    
    # Function to sanitize tag values for S3 compatibility
    def sanitize_tag_value(value):
        # S3 tag values can only contain: alphanumeric, spaces, and _ . : / = + - @
        # Allowed characters: a-z, A-Z, 0-9, space, _, ., :, /, =, +, -, @
        import re
        
        # Convert to string and replace common invalid characters
        sanitized = str(value)
        
        # Replace invalid characters with safe alternatives
        sanitized = sanitized.replace(',', ' ')  # Replace comma with space
        sanitized = sanitized.replace('(', ' ')  # Replace parentheses with space
        sanitized = sanitized.replace(')', ' ')  # Replace parentheses with space
        sanitized = sanitized.replace('[', ' ')  # Replace brackets with space
        sanitized = sanitized.replace(']', ' ')  # Replace brackets with space
        sanitized = sanitized.replace('{', ' ')  # Replace braces with space
        sanitized = sanitized.replace('}', ' ')  # Replace braces with space
        sanitized = sanitized.replace("'", '')   # Remove single quotes
        sanitized = sanitized.replace('"', '')   # Remove double quotes
        sanitized = sanitized.replace('\n', ' ') # Replace newlines with space
        sanitized = sanitized.replace('\r', ' ') # Replace carriage returns with space
        sanitized = sanitized.replace('\t', ' ') # Replace tabs with space
        
        # Keep only allowed characters: alphanumeric, space, and _ . : / = + - @
        sanitized = re.sub(r'[^a-zA-Z0-9 _.:/=+\-@]', '', sanitized)
        
        # Clean up multiple spaces
        sanitized = re.sub(r'\s+', ' ', sanitized)
        
        # Strip leading/trailing spaces
        sanitized = sanitized.strip()
        
        # Limit length to 256 characters (S3 tag value limit)
        return sanitized[:256]
    
    # Determine scan result message based on scan result code and found malwares
    if scan_result_code == 0 and found_malwares == []:
        # Clean file
        scan_result_message = "no issues found"
        scan_detail_message = "-"
    elif scan_result_code == 1 or found_malwares != []:
        # Malicious file
        scan_result_message = "malicious"
        scan_detail_message = "-"
    else:
        # Handle edge cases
        scan_result_message = "unknown"
        scan_detail_message = f"Scan code: {scan_result_code}, Malwares: {len(found_malwares)}"
        scan_detail_message = sanitize_tag_value(scan_detail_message)
    
    # Define new tags in your preferred format (all values sanitized)
    new_tags = [
        {'Key': 'fss-scan-detail-code', 'Value': sanitize_tag_value(str(scan_result_code))},
        {'Key': 'fss-scan-date', 'Value': sanitize_tag_value(scan_date_formatted)},
        {'Key': 'fss-scan-result', 'Value': sanitize_tag_value(scan_result_message)},
        {'Key': 'fss-scan-detail-message', 'Value': scan_detail_message},  # Already sanitized above
        {'Key': 'fss-scanned', 'Value': sanitize_tag_value('true')}
    ]
    
    # Get existing tags
    current_tags = get_existing_tags(bucket_name, file_name)
    
    # Remove any existing fss- tags to avoid duplicates
    def remove_fss_tags(tags):
        return [tag for tag in tags if not tag['Key'].startswith('fss-')]
    
    # Clean existing tags and add new ones
    cleaned_tags = remove_fss_tags(current_tags)
    final_tags = cleaned_tags + new_tags
    
    # Debug: Print tag values before applying
    print(f"About to apply tags to {file_name}:")
    for tag in new_tags:
        print(f"  {tag['Key']}: '{tag['Value']}' (length: {len(tag['Value'])})")
        # Debug: Show any non-ASCII characters
        non_ascii = [c for c in tag['Value'] if ord(c) > 127]
        if non_ascii:
            print(f"    Non-ASCII characters found: {non_ascii}")
        # Debug: Show any characters not in allowed set
        allowed_chars = set('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 _.:/=+-@')
        invalid_chars = [c for c in tag['Value'] if c not in allowed_chars]
        if invalid_chars:
            print(f"    Invalid characters found: {invalid_chars}")
    
    # Check if we're within the 10 tag limit
    if len(final_tags) <= 10:
        try:
            publish_tag(final_tags)
            print(f"Successfully applied tags to {file_name}")
        except Exception as e:
            print(f"Error applying tags to {file_name}: {str(e)}")
            print(f"Tag values that caused the error:")
            for tag in new_tags:
                print(f"  {tag['Key']}: '{tag['Value']}'")
            raise e
    else:
        print(f"Cannot apply tags - would exceed 10 tag limit. Current tags: {len(cleaned_tags)}, New tags: {len(new_tags)}")
    
    return {
        'statusCode': 200,
        'body': json.dumps(f'Tagging completed for {file_name}')
    }
