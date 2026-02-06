# V1FS SDK for S3 - Terraform Deployment

This example demonstrates how to use the [V1FS Python SDK](https://github.com/trendmicro/tm-v1-fs-python-sdk) to automatically scan files uploaded to an S3 bucket using Terraform.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [S3 Bucket Setup](#s3-bucket-setup)
- [How Scanning Works](#how-scanning-works)
- [Testing](#testing)
- [Payload Structure](#payload-structure)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## Overview

This Terraform configuration creates an automated file scanning solution that:

- **Automatically scans** files uploaded to S3 buckets using Trend Micro Vision One File Security SDK
- **Publishes scan results** to an SNS topic for integration with email, Slack, or other notification systems
- **Optionally tags** scanned objects with scan results
- **Supports** KMS-encrypted buckets, IAM Permission Boundaries, and VPC deployments

## Architecture

![architecture](../images/v1fs-s3.png)

### Flow

1. **File Upload**: A file is uploaded to an S3 bucket with EventBridge notifications enabled
2. **EventBridge**: Captures the S3 object creation event
3. **SQS Queue**: Receives the event message for reliable processing
4. **Lambda Scanner**: Processes the message, streams the file from S3, and scans it using V1FS SDK
5. **SNS Topic**: Publishes scan results for downstream processing
6. **Tag Lambda** (optional): Tags the S3 object with scan results

### Resources Created

**Mandatory Resources:**
- 1x EventBridge rule (captures S3 object creation events)
- 1x Lambda function (scanner) + 1x Lambda layer (V1FS SDK)
- 1x IAM role and policies
- 1x SQS queue (with DLQ for failed messages)
- 1x SNS topic
- 1x Secrets Manager secret (stores Vision One API key)

**Optional Resources:**
- Tag Lambda function (for S3 object tagging)
- KMS policies (for scanning encrypted files)
- VPC configurations (for Lambda in VPC)
- IAM Permission Boundaries

## Requirements

- [Vision One](https://www.trendmicro.com/visionone) account ([Sign up for a free trial](https://resources.trendmicro.com/vision-one-trial.html))
- [API key](https://docs.trendmicro.com/en-us/documentation/article/trend-vision-one-__api-keys-2) with V1FS **Run file scan via SDK** permissions
- Terraform CLI [installed](https://learn.hashicorp.com/tutorials/terraform/install-cli) (version >= 0.15.0)
- AWS CLI [installed](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and [configured](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)
- AWS account with permissions to create:
  - Lambda functions and layers
  - IAM roles and policies
  - SQS queues
  - SNS topics
  - EventBridge rules
  - Secrets Manager secrets

## Quick Start

### Step 1: Configure Variables

Copy the example variables file and edit it with your values:

```bash
cd AWS/s3/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set your required variables:

```hcl
v1fs_apikey = "your-vision-one-api-key-here"
v1fs_region = "us-east-1"
aws_region  = "us-east-1"
prefix      = "v1fs"
```

**⚠️ Important:** The `terraform.tfvars` file is ignored by git to protect your API key. Never commit this file.

### Step 2: Configure S3 Bucket EventBridge Notifications

Before deploying, you need to configure your S3 bucket to send events to EventBridge. You can do this via:

**AWS Console:**
1. Go to your S3 bucket → Properties → Event notifications
2. Enable "EventBridge" notifications
3. Save changes

**AWS CLI:**
```bash
aws s3api put-bucket-notification-configuration \
  --bucket your-bucket-name \
  --notification-configuration '{"EventBridgeConfiguration":{}}'
```

**Note:** The EventBridge rule in this configuration will capture **all** S3 object creation events in the region. To filter by specific buckets, you'll need to modify the EventBridge rule's event pattern after deployment.

### Step 3: Initialize and Deploy

```bash
# Initialize Terraform
terraform init

# Review the execution plan
terraform plan

# Apply the configuration
terraform apply
```

The stack takes approximately 1 minute to deploy.

### Step 4: Subscribe to SNS Topic (Optional)

Subscribe to the SNS topic to receive scan notifications:

```bash
# Get the SNS topic ARN from Terraform outputs
SNS_ARN=$(terraform output -raw sns_arn)

# Subscribe via email
aws sns subscribe \
  --topic-arn $SNS_ARN \
  --protocol email \
  --notification-endpoint your-email@example.com
```

## Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `v1fs_apikey` | Your Vision One API key (sensitive) | `your-api-key-here` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `v1fs_region` | Vision One region | `us-east-1` |
| `aws_region` | AWS region for deployment | `us-east-1` |
| `prefix` | Resource prefix (max 20 chars) | `v1fs` |
| `enable_tag` | Enable S3 object tagging (`"true"` or `"false"`) | `"false"` |
| `sdk_tags` | List of SDK tags for Vision One UI | `["env:prod", "project:new_app", "cost-center:dev"]` |
| `vpc` | VPC configuration object (see below) | `null` |
| `kms_key_bucket` | KMS key ARN for encrypted buckets | `null` |
| `permissions_boundary_arn` | IAM permissions boundary ARN | `null` |

### Variable Examples

#### Basic Configuration

```hcl
v1fs_apikey = "your-api-key"
v1fs_region = "us-east-1"
aws_region  = "us-east-1"
prefix      = "v1fs"
enable_tag  = "true"
```

#### With VPC Configuration

```hcl
v1fs_apikey = "your-api-key"
vpc = {
  subnet_ids         = ["subnet-12345678", "subnet-87654321"]
  security_group_ids = ["sg-12345678"]
}
```

#### With KMS Encryption

```hcl
v1fs_apikey    = "your-api-key"
kms_key_bucket = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
```

#### With Permissions Boundary

```hcl
v1fs_apikey            = "your-api-key"
permissions_boundary_arn = "arn:aws:iam::123456789012:policy/PermissionsBoundary"
```

### Vision One Regions

Supported Vision One regions:
- `us-east-1` (default)
- `eu-central-1`
- `ap-northeast-1`
- `ap-southeast-1`
- `ap-southeast-2`
- `ap-south-1`
- `me-central-1`

## S3 Bucket Setup

### Enable EventBridge Notifications

Your S3 bucket must have EventBridge notifications enabled for the stack to work. This is a **one-time configuration** per bucket.

**Using AWS Console:**
1. Navigate to your S3 bucket
2. Go to **Properties** tab
3. Scroll to **Event notifications**
4. Enable **EventBridge**
5. Click **Save changes**

**Using AWS CLI:**
```bash
aws s3api put-bucket-notification-configuration \
  --bucket your-bucket-name \
  --notification-configuration '{"EventBridgeConfiguration":{}}'
```

### Filtering Events (Optional)

The EventBridge rule captures all S3 object creation events in the region. To filter by specific buckets or prefixes, you can modify the rule after deployment or update the Terraform configuration:

```hcl
resource "aws_cloudwatch_event_rule" "event_bridge_rule" {
  # ... existing configuration ...
  event_pattern = jsonencode({
    source      = ["aws.s3"]
    "detail-type" = ["Object Created"]
    detail = {
      bucket = {
        name = ["your-specific-bucket-name"]
      }
      object = {
        key = {
          prefix = "uploads/"
        }
      }
    }
  })
}
```

## How Scanning Works

![scan](../images/v1fs-internal.png)

The V1FS (Vision One File Security) is a cloud service that scans files for malware using:
- Trend Micro Antimalware engine
- Trend Micro Smart Protection Network (SPN)

The V1FS SDK Python library is available on [GitHub](https://github.com/trendmicro/tm-v1-fs-python-sdk).

### File Streaming

To perform file scanning using the V1FS SDK, it is typically required to have the file present in the local file system. During the scan process, the backend will request each block of the file until a verdict is reached. However, in this specific example, the file is stored in an S3 bucket. Instead of downloading the entire file, the lambda function will stream it from the S3 bucket using the [S3.Object.get()](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/s3/object/get.html) method to the Lambda. Subsequently, the V1FS backend will request each stream from the V1FS SDK client for scanning. The backend service will evaluate each stream until a verdict is obtained, and finally, the scan result will be returned to the lambda function.

## Testing

### Test with EICAR File

The [EICAR test file](https://www.eicar.org/?page_id=3950) is a safe, standard test file that all antivirus engines detect as malicious.

```bash
# Download EICAR test file
curl -O https://secure.eicar.org/eicar.com

# Upload to your S3 bucket
aws s3 cp eicar.com s3://your-bucket-name/

# Check SNS topic for scan results (if subscribed via email)
# Or check CloudWatch Logs for the Lambda function
```

### Verify Terraform Outputs

```bash
terraform output
```

### Monitor Lambda Execution

```bash
# Get the Lambda function name from outputs
LAMBDA_NAME=$(terraform output -raw lambda_arn | awk -F: '{print $7}')

# View recent Lambda invocations
aws logs tail /aws/lambda/$LAMBDA_NAME --follow
```

## Payload Structure

Scan results are published to the SNS topic in the following format:

```json
{
  "timestamp": "2023-05-24T21:19:00Z",
  "sqs_message_id": "fa2bd59e-5e6d-4ac8-bfac-d849283bd8273",
  "xamz_request_id": "177cdce6-1fc6-632c-2654-4ab8b45d4400",
  "file_url": "https://test-bucket.s3.ap-south-1.amazonaws.com/file.zip",
  "file_attributes": {
    "etag": "6ce6f415d87164jdsd114f208b0ff"
  },
  "scanner_status": 0,
  "scanner_status_message": "successful scan",
  "scanning_result": {
    "TotalBytesOfFile": 184,
    "Findings": [{
      "version": "1.0.0",
      "scanResult": 1,
      "scanId": "249c3861-4a18-7826-b3e0-e0c44dbbe697",
      "scanTimestamp": "2023-05-24T21:19:04.826Z",
      "fileName": "file.zip",
      "foundMalwares": [{
        "fileName": "file.zip",
        "malwareName": "OSX_EICAR.PFH"
      }],
      "scanDuration": "0.95s"
    }],
    "Error": "",
    "Codes": []
  },
  "source_ip": "111.220.222.22"
}
```

### Scan Result Values

- `scanner_status`: `0` = success, non-zero = error
- `scanResult`: `0` = clean, `1` = malicious, `2` = suspicious
- `foundMalwares`: Array of detected malware (empty if clean)

You can customize the message format by modifying the Lambda function code.

## Troubleshooting

### Terraform Apply Errors

**Issue:** `v1fs_apikey` validation error.

**Solution:** Ensure the `v1fs_apikey` variable is set and not empty in your `terraform.tfvars` file.

**Issue:** Secrets Manager error about empty secret string.

**Solution:** Verify your `v1fs_apikey` is correctly set in `terraform.tfvars` and not an empty string.

### Lambda Function Not Invoked

**Issue:** Files uploaded to S3 but Lambda not triggered.

**Solutions:**
1. Verify EventBridge notifications are enabled on the S3 bucket
2. Check EventBridge rule is enabled: `aws events describe-rule --name <rule-name>`
3. Verify SQS queue has messages: `aws sqs get-queue-attributes --queue-url <queue-url> --attribute-names ApproximateNumberOfMessages`
4. Check Lambda event source mapping: `aws lambda list-event-source-mappings --function-name <function-name>`

### Lambda Function Errors

**Issue:** Lambda function fails with errors.

**Solutions:**
1. Check CloudWatch Logs: `/aws/lambda/<function-name>`
2. Verify API key is correct in Secrets Manager
3. Check IAM permissions for S3, SQS, SNS, and Secrets Manager
4. Verify Lambda layer is correctly referenced

### KMS Decryption Errors

**Issue:** Lambda cannot decrypt KMS-encrypted files.

**Solutions:**
1. Verify `kms_key_bucket` variable contains the correct KMS key ARN
2. Check Lambda execution role has `kms:Decrypt` and `kms:DescribeKey` permissions
3. Verify KMS key policy allows Lambda role to use the key

### VPC Connectivity Issues

**Issue:** Lambda in VPC cannot reach V1FS API.

**Solutions:**
1. Verify VPC has internet gateway or NAT gateway
2. Check security group allows outbound HTTPS (443) traffic
3. Verify subnet has route to internet gateway/NAT
4. Consider using VPC endpoints for AWS services

### SNS Notifications Not Received

**Issue:** No notifications received from SNS topic.

**Solutions:**
1. Verify SNS subscription is confirmed (check email for confirmation link)
2. Check SNS topic has published messages: `aws sns get-topic-attributes --topic-arn <topic-arn>`
3. Verify Lambda has permission to publish to SNS
4. Check message format in CloudWatch Logs

### Files Not Tagged

**Issue:** S3 objects not tagged after scanning.

**Solutions:**
1. Verify `enable_tag` variable is set to `"true"`
2. Check Tag Lambda function exists and is subscribed to SNS topic
3. Verify Tag Lambda has `s3:PutObjectTagging` permission
4. Check Tag Lambda CloudWatch Logs for errors

## Cleanup

To remove all resources created by Terraform:

```bash
terraform destroy
```

**Note:** The Secrets Manager secret will be deleted, but you may want to back up your API key first.

### Manual Cleanup

If `terraform destroy` fails, you may need to manually delete:
1. Lambda functions (delete event source mappings first)
2. SQS queues (must be empty)
3. SNS topic subscriptions
4. Secrets Manager secret
5. IAM roles and policies
6. EventBridge rule

Then remove the Terraform state:

```bash
rm terraform.tfstate terraform.tfstate.backup
```

## Additional Resources

- [V1FS Python SDK Documentation](https://github.com/trendmicro/tm-v1-fs-python-sdk)
- [Vision One Documentation](https://docs.trendmicro.com/en-us/cloud-one/cloud-one-file-storage-security)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
