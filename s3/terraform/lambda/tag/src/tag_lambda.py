import boto3
import json

s3 = boto3.client('s3')

def lambda_handler(event, context):
    
    # Parsing the SNS payload
    event = event['Records'][0]['Sns']['Message']
    event = event.replace("'", "\"")
    data = json.loads(event)
    scanning_result = data['scanning_result']['Findings'][0]['foundMalwares']
    
    # Get bucket and object
    object_key = data['scanning_result']['Findings'][0]['fileName']
    bucket_name = data['file_url'].split('//')[-1].split('.')[0]
    
    # publish the tag
    def publish_tag(tag):
        response = s3.put_object_tagging(
            Bucket=bucket_name,
            Key=object_key,
            Tagging={'TagSet': tag}
        )
        return response
        
    def get_existing_tags(bucket, key):
        try:
            existing_tags = s3.get_object_tagging(Bucket=bucket, Key=key)['TagSet']
        except:
            existing_tags = []
        return existing_tags
        
    # Define new tags
    malicious_tag = {'Key': 'scanResult', 'Value': 'malicious'}
    clean_tag = {'Key': 'scanResult', 'Value': 'clean'}
    
    # Get the existing tags
    current_tags = get_existing_tags(bucket_name, object_key)
    
    # Set the tag Key
    tag_key = 'scanResult'

    # remove the key-value pair with key 'scanResult' if exists
    def remove_key(data, key):
        return [d for d in data if d['Key'] != key]
    
    # Remove the 'scanResult' if exists
    current_tags = remove_key(current_tags, tag_key)
    
    # Count how many tags the object has
    count_tags = len(current_tags)
    
    if scanning_result == [] and count_tags < 10:
        print("No malwares found, apply a clean tag")
        new_clean_tag = current_tags
        new_clean_tag.append(clean_tag)
        publish_tag(new_clean_tag)
        
    elif scanning_result != [] and count_tags < 10:
        print("Found malwares! apply a malicious tag")
        new_malicious_tag = current_tags
        new_malicious_tag.append(malicious_tag)
        publish_tag(new_malicious_tag)
    elif count_tags >= 10:
        print(f"The object has {count_tags} tags, and the limit is 10. Cannot apply more tags")
