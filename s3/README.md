# V1FS S3 Stack example

This example shows how to use the [V1FS Python SDK](https://github.com/trendmicro/tm-v1-fs-python-sdk) to create a new stack that automatically scan files uploaded to an S3 bucket.

## Requirements

- Have a [Vision One](https://www.trendmicro.com/visionone) account. [Sign up for a free trial now](https://resources.trendmicro.com/vision-one-trial.html) if it's not already the case!
- An [API key](https://docs.trendmicro.com/en-us/documentation/article/trend-vision-one-__api-keys-2) with V1FS **Run file scan via SDK** permissions;
- Terraform CLI [installed](https://learn.hashicorp.com/tutorials/terraform/install-cli#install-terraform)
- AWS CLI [installed](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and [configured](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html).

## Before you start

****IMPORTANT****
This is an example of how to use the V1FS Python SDK to scan files uploaded to an S3 bucket.

This Stack creates the following **mandatory** resources:
- 1x EventBridge rule
- 1x Lambda function + 1x Lambda layer
- 1x IAM role and policies
- 1x SQS queue
- 1x SNS topic
- 1x Secrets Manager secret (To store the Vision One API key)

The stack also creates the following **optional** resources:
- KMS policies to support scanning encrypted files
- VPC policies/configurations to support scanning lambda behind a VPC


![architecture](images/v1fs-s3.png)

The architecture is triggered every time that a file is uploaded to a S3 bucket, that happen only in the aws region where the bucket is located and for the eventbridge is trigger the s3 bucket must have the event notification for eventbridge enabled.

The notification then is sent to a SQS queue and a lambda function is trigger to process the message. The lambda function will download the file from the S3 bucket and use the V1FS Python SDK to scan the file. The result of the scan is publish to a SNS topic.

The SNS topic can be used to send the notification to a email, slack, etc.

The way that the stack was build give you the flexibility to customize the stack to your needs. For example, you can change the way that the notification is sent to SNS, you can change the way that the notification is sent to the email, slack, etc.

The Stack work on any regions where the resources described above are available.


## How the scan works

The V1FS is a cloud service that is part of the Trend Vision One platform, allowing you to scan files and determine whether they are malicious or not. The interaction with the V1FS backend service is facilitated through an SDK that enables you to send files to the backend service. The backend service utilizes the Trend Micro Antimalware engine and the Trend Micro Smart Protection Network (SPN) for file scanning.

The V1FS SDK Python library is available on [GitHub](https://github.com/trendmicro/tm-v1-fs-python-sdk). Additional language support is also available.

To perform file scanning using the V1FS SDK, it is typically required to have the file present in the local file system. During the scan process, the backend will request each block of the file until a verdict is reached. However, in this specific example, the file is stored in an S3 bucket. Instead of downloading the entire file, the lambda function will stream it from the S3 bucket using the [S3.Object.get()](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/s3/object/get.html) method to the Lambda. Subsequently, the V1FS backend will request each stream from the V1FS SDK client for scanning. The backend service will evaluate each stream until a verdict is obtained, and finally, the scan result will be returned to the lambda function.

![scan](images/v1fs-internal.png)

## Usage

To build and deploy the stack, follow the steps below:

- Clone this repository
- Execute the following commands:

    ```
    cd terraform
    terraform init
    terraform plan
    terraform apply -auto-approve
    ```

*The stack takes in average 1 minute to be deployed and 50 seconds to be destroyed.*

## Testing

To test the stack, you can copy/upload a file to any s3 bucket in the same region where the stack was deployed. An example of a file that you can use to test the stack is the [eicar test file](https://www.eicar.org/?page_id=3950).

To test the stack, you can use the following command:

```
aws s3 cp eicar.com s3://<bucket-name>
```

The result of the scan will be published to the SNS topic. You can subscribe to the SNS topic to receive the notification, a sample of the notification is below:

```
{
	'timestamp': '2023-05-24T21:19:00Z',
	'sqs_message_id': 'fa2bd59e-5e6d-4ac8-bfac-d849283bd8273',
	'xamz_request_id': '177cdce6-1fc6-632c-2654-4ab8b45d4400',
	'file_url': 'https://test-bucket.s3.ap-south-1.amazonaws.com/file.zip',
	'file_attributes': {
		'etag': '6ce6f415d87164jdsd114f208b0ff'
	},
	'scanner_status': 0,
	'scanner_status_message': 'successful scan',
	'scanning_result': {
		'TotalBytesOfFile': 184,
		'Findings': [{
			'version': '1.0.0',
			'scanResult': 1,
			'scanId': '249c3861-4a18-7826-b3e0-e0c44dbbe697',
			'scanTimestamp': '2023-05-24T21:19:04.826Z',
			'fileName': 'file.zip',
			'foundMalwares': [{
				'fileName': 'file.zip',
				'malwareName': 'OSX_EICAR.PFH'
			}],
			'scanDuration': '0.95s'
		}],
		'Error': '',
		'Codes': []
	},
	'source_ip': '111.220.222.22'
}
```

You can customize the message that is sent to the SNS topic by changing the lambda function code.

## Performance

Here some performance data based on the tests that I did:

| File | Size | Time |
|----------|----------|----------|
| file.docx   | 251Kb   | 0.37s    |
| file.exe   | 910Kb    | 0.26s    |
| file.mp3    | 3.8Mb    | 0.22s    |
| file.mp4    | 59Mb    | 1.06s    |
| eicar.com    | 68b    | 0.04s    |
| file.pdf    | 25Mb    | 0.77s    |
| file.pkg    | 37Mb    | 5.81s    |
| file.pptx   | 13Mb    | 0.26s    |
| file.txt    | 3Kb    | 0.20s    |
| file.zip    | 66Mb    | 9.59s    |
| file.rpm    | 37Mb    | 0.92s    |
| file.tar   | 780Kb    | 0.44s    |

The test was executed by deploying the stack an then uploading the file to the S3 bucket. The time is the time that the lambda function took to scan the file.

## Additionals

### Tagging
The stack has support to tag the objects when the scan is completed. To enable the tagging, you need to set the variable `enable_tag` to `true`, the object will be tagged with the following tags:

- `scanResult` - The result of the scan, the possible values are `clean` or `malicious`.

### VPC
The stack also supports a additional configuration for the lambda function to be deployed with a VPC. To enable the VPC configuration, you need to provide the subnet and security group to the variable `vpc`, based on the subnet and security group that you provide, the lambda function will be deployed with a VPC.

### KMS
The stack also supports a additional configuration for the lambda function to scan files encrypted on a bucket using KMS. To enable the KMS configuration, you need to provide the KMS key to the variable `kms_key_bucket`, based on the KMS key that you provide, the lambda function will have access to the KMS key and using the key to decrypt the file for the scan.

## Cleanup

To destroy the stack, execute the following command:

```
terraform destroy -auto-approve
```
