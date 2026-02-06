# EFS Scanner - AMaaS Stack Example

This example demonstrates how to use the [AMaaS Python SDK](https://github.com/trendmicro/cloudone-antimalware-python-sdk/) to automatically scan files stored in an Amazon EFS (Elastic File System) using AWS Lambda.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Usage](#usage)
- [Testing](#testing)
- [Scheduled Scanning](#scheduled-scanning)
- [How Scanning Works](#how-scanning-works)
- [Payload Structure](#payload-structure)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## Overview

This Terraform stack creates an automated file scanning solution that:

- **Scans files** stored in Amazon EFS using Trend Micro Cloud One Antimalware as a Service (AMaaS)
- **Supports manual scans** of specific files or **full scans** of all files in the EFS mount
- **Publishes scan results** to an SNS topic for integration with email, Slack, or other notification systems
- **Supports scheduled scanning** via EventBridge rules
- **Mounts EFS directly** to Lambda for efficient file access

## Architecture

![architecture](amaas-efs.png)

### Flow

1. **Lambda Invocation**: Lambda function is invoked manually, via EventBridge schedule, or via API
2. **EFS Access**: Lambda accesses files from the EFS mounted at `/mnt/efs`
3. **AMaaS Scanning**: Files are scanned using the AMaaS gRPC SDK
4. **SNS Notification**: Scan results are published to an SNS topic
5. **Downstream Processing**: SNS subscribers receive notifications (email, Slack, etc.)

### Resources Created

**Mandatory Resources:**
- 1x Lambda function (scanner) + 1x Lambda layer (AMaaS SDK)
- 1x IAM role and policies (EFS access, Secrets Manager, SNS, VPC)
- 1x SNS topic
- 1x Secrets Manager secret (stores Cloud One API key)

**Optional Resources:**
- EventBridge rule and target (for scheduled scanning)

## Requirements

- [Cloud One](https://www.trendmicro.com/cloudone) account ([Sign up for a free trial](https://cloudone.trendmicro.com/register))
- [API key](https://cloudone.trendmicro.com/docs/account-and-user-management/c1-api-key/#create-a-new-api-key) with minimum **"Read Only Access"** permission
- Terraform CLI [installed](https://learn.hashicorp.com/tutorials/terraform/install-cli#install-terraform)
- AWS CLI [installed](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and [configured](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)
- AWS account with permissions to create Lambda functions, IAM roles, EFS access points, VPC resources, SNS topics, and Secrets Manager secrets

## Prerequisites

**⚠️ IMPORTANT:** Before deploying this stack, you must have:

1. **An existing EFS file system** with:
   - An access point configured
   - Proper security group rules allowing Lambda access
   - Network connectivity from your VPC subnets

2. **VPC Configuration:**
   - Lambda must be deployed in the **same VPC** as the EFS file system
   - Lambda must have **internet access** (via NAT Gateway or Internet Gateway) to reach AMaaS API endpoints
   - Security groups must allow:
     - Outbound HTTPS (443) for AMaaS API calls
     - NFS (2049) access to EFS

3. **EFS Access Point:**
   - Create an EFS access point with appropriate POSIX user/group permissions
   - Note the EFS file system ID and access point ID for Terraform variables

## Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `apikey` | Cloud One API key | `your-api-key-here` |
| `efs_id` | EFS file system ID | `fs-0123456789abcdef0` |
| `efs_access_point` | EFS access point ID | `fsap-0123456789abcdef0` |
| `subnet` | Subnet ID for Lambda (in same VPC as EFS) | `subnet-0123456789abcdef0` |
| `security_group` | Security group ID for Lambda | `sg-0123456789abcdef0` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `v1_region` | Cloud One region | `ap-southeast-1` |
| `aws_region` | AWS region for deployment | `us-east-1` |
| `prefix` | Resource prefix | `scanner-efs` |
| `schadule_scan` | Enable scheduled scanning | `false` |
| `scan_frequency` | Scan frequency (cron or rate expression) | `rate(1 hour)` |

### Variable Configuration

Create a `terraform.tfvars` file:

```hcl
apikey           = "your-cloud-one-api-key"
efs_id           = "fs-0123456789abcdef0"
efs_access_point = "fsap-0123456789abcdef0"
subnet           = "subnet-0123456789abcdef0"
security_group   = "sg-0123456789abcdef0"
v1_region        = "ap-southeast-1"
aws_region       = "us-east-1"
prefix           = "scanner-efs"
schadule_scan    = true
scan_frequency   = "rate(1 hour)"  # or "cron(0 0 * * ? *)" for daily at midnight
```

## Deployment

### Step 1: Prepare Lambda Layer

Ensure the AMaaS SDK layer is available at:
```
lambda/scanner/layer/v1fs-python311-arm64.zip
```

If the layer doesn't exist, you'll need to create it by installing the AMaaS SDK and packaging it. See the layer README for instructions.

### Step 2: Initialize Terraform

```bash
cd terraform
terraform init
```

### Step 3: Review Plan

```bash
terraform plan
```

Review the resources that will be created.

### Step 4: Deploy Stack

```bash
terraform apply
```

Or for automatic approval:

```bash
terraform apply -auto-approve
```

**Deployment Time:** The stack typically takes ~3 minutes to deploy and ~50 seconds to destroy.

### Step 5: Verify Deployment

```bash
# Get Lambda function name
aws lambda list-functions --query 'Functions[?contains(FunctionName, `scanner-efs`)].FunctionName' --output text

# Get SNS topic ARN
terraform output -json | jq -r '.sns_topic_arn.value'
```

## Usage

### Manual Invocation

Invoke the Lambda function manually to scan files:

**Full Scan (all files in EFS):**
```bash
aws lambda invoke \
  --function-name <lambda-function-name> \
  --payload '{}' \
  response.json
```

**Manual Scan (specific files):**
```bash
aws lambda invoke \
  --function-name <lambda-function-name> \
  --payload '{
    "scan_type": "manual",
    "files": [
      "/mnt/efs/path/to/file1.txt",
      "/mnt/efs/path/to/file2.pdf"
    ]
  }' \
  response.json
```

**View response:**
```bash
cat response.json | jq
```

### File Paths

When specifying files for manual scans, use the **full path** starting with `/mnt/efs`:

- ✅ Correct: `/mnt/efs/documents/file.pdf`
- ❌ Incorrect: `/documents/file.pdf` or `documents/file.pdf`

## Scheduled Scanning

Enable scheduled scanning by setting `schadule_scan = true` in your `terraform.tfvars`.

### Schedule Expressions

Use either **rate** or **cron** expressions:

**Rate Expressions:**
- `rate(1 hour)` - Every hour
- `rate(30 minutes)` - Every 30 minutes
- `rate(1 day)` - Every day

**Cron Expressions:**
- `cron(0 0 * * ? *)` - Daily at midnight UTC
- `cron(0 0 ? * MON *)` - Every Monday at midnight UTC
- `cron(0 0 1 * ? *)` - First day of every month at midnight UTC

See [AWS EventBridge Schedule Expressions](https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html) for more options.

### Enable/Disable Scheduled Scanning

To enable scheduled scanning after deployment:

1. Update `terraform.tfvars`:
   ```hcl
   schadule_scan = true
   scan_frequency = "rate(1 hour)"
   ```

2. Apply changes:
   ```bash
   terraform apply
   ```

To disable:
```hcl
schadule_scan = false
```

## Testing

### Test with EICAR File

The [EICAR test file](https://www.eicar.org/?page_id=3950) is a safe, standard test file that all antivirus engines detect as malicious.

1. **Copy EICAR to EFS:**
   ```bash
   # Download EICAR
   curl -O https://secure.eicar.org/eicar.com
   
   # Copy to EFS (via EC2 instance or EFS mount)
   # If you have an EC2 instance with EFS mounted:
   cp eicar.com /mnt/efs/test/eicar.com
   ```

2. **Invoke Lambda for manual scan:**
   ```bash
   aws lambda invoke \
     --function-name <lambda-function-name> \
     --payload '{
       "scan_type": "manual",
       "files": ["/mnt/efs/test/eicar.com"]
     }' \
     response.json
   ```

3. **Check SNS topic** for scan results (if subscribed via email)

### Monitor Lambda Execution

```bash
# View recent Lambda invocations
aws logs tail /aws/lambda/<lambda-function-name> --follow

# Or view in CloudWatch Console
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/scanner-efs
```

### Subscribe to SNS Topic

Subscribe to receive scan notifications:

```bash
# Get SNS topic ARN
SNS_ARN=$(terraform output -json | jq -r '.sns_topic_arn.value')

# Subscribe via email
aws sns subscribe \
  --topic-arn $SNS_ARN \
  --protocol email \
  --notification-endpoint your-email@example.com

# Check your email and confirm the subscription
```

## How Scanning Works

The AMaaS (Antimalware as a Service) is a cloud service that is part of the Trend Cloud One platform, allowing you to scan files and determine whether they are malicious or not. The interaction with the AMaaS backend service is facilitated through an SDK that enables you to send files to the backend service. The backend service utilizes the Trend Micro Antimalware engine and the Trend Micro Smart Protection Network (SPN) for file scanning.

### Scanning Modes

**Full Scan Mode:**
- Scans **all files** in the EFS mount directory (`/mnt/efs`)
- Recursively walks through all subdirectories
- Publishes individual results for each file to SNS
- Use when no `scan_type` is specified or `scan_type` is not `"manual"`

**Manual Scan Mode:**
- Scans only **specified files** from the `files` array in the event payload
- More efficient for targeted scanning
- Requires `scan_type: "manual"` in the event payload

### Process Flow

1. **Lambda Initialization**: Lambda mounts EFS at `/mnt/efs` using the access point
2. **AMaaS Client**: Initializes gRPC client with API key from Secrets Manager
3. **File Discovery**: 
   - Full scan: Walks directory tree
   - Manual scan: Uses provided file paths
4. **Scanning**: Each file is scanned using `amaas.grpc.scan_file()`
5. **Result Publishing**: Individual scan results are published to SNS
6. **Cleanup**: gRPC client is properly closed

The AMaaS SDK Python library is available on [GitHub](https://github.com/trendmicro/cloudone-antimalware-python-sdk).

## Payload Structure

Scan results are published to the SNS topic in the following format:

```json
{
  "/mnt/efs/test.png": {
    "version": "1.0.0",
    "scanResult": 0,
    "scanId": "075a4894-be4b-410d-8871-1de77e641ba1",
    "scanTimestamp": "2023-06-21T22:37:24.38Z",
    "fileName": "test.png",
    "foundMalwares": [],
    "scanDuration": "0.25s",
    "size": 36745
  },
  "/mnt/efs/test/test2/eicar.com": {
    "version": "1.0.0",
    "scanResult": 1,
    "scanId": "70f68a3c-eb59-450e-a8d8-976e63d045af",
    "scanTimestamp": "2023-06-21T22:37:25.96Z",
    "fileName": "eicar.com",
    "foundMalwares": [
      {
        "fileName": "eicar.com",
        "malwareName": "Eicar_test_file"
      }
    ],
    "scanDuration": "0.01s",
    "size": 68
  }
}
```

### Scan Result Values

- `scanResult`: `0` = clean, `1` = malicious, `2` = suspicious
- `foundMalwares`: Array of detected malware (empty if clean)
- `scanDuration`: Time taken to scan the file
- `size`: File size in bytes

**Note:** Each file's scan result is published as a **separate SNS message**. For full scans with many files, you'll receive multiple SNS notifications.

You can customize the message format by modifying the Lambda function code.

## Troubleshooting

### Lambda Cannot Access EFS

**Issue:** Lambda fails to mount or access EFS files.

**Solutions:**
1. Verify Lambda and EFS are in the same VPC
2. Check security group allows NFS (port 2049) between Lambda and EFS
3. Verify EFS access point exists and has correct permissions
4. Check Lambda execution role has `elasticfilesystem:ClientMount` and `elasticfilesystem:ClientWrite` permissions
5. Review CloudWatch Logs for mount errors

### Lambda Cannot Reach AMaaS API

**Issue:** Lambda fails to connect to AMaaS backend.

**Solutions:**
1. Verify Lambda has internet access (NAT Gateway or Internet Gateway)
2. Check security group allows outbound HTTPS (443)
3. Verify VPC route tables route internet traffic correctly
4. Check CloudWatch Logs for connection errors
5. Verify API key is correct in Secrets Manager

### Scheduled Scans Not Running

**Issue:** EventBridge schedule not triggering Lambda.

**Solutions:**
1. Verify `schadule_scan` is set to `true`
2. Check EventBridge rule exists: `aws events describe-rule --name <rule-name>`
3. Verify Lambda permission allows EventBridge invocation
4. Check EventBridge target is configured correctly
5. Review EventBridge metrics in CloudWatch

### API Key Errors

**Issue:** Lambda cannot retrieve API key from Secrets Manager.

**Solutions:**
1. Verify API key exists in Secrets Manager
2. Check Lambda execution role has `secretsmanager:GetSecretValue` permission
3. Verify secret name matches the environment variable
4. Check secret is in the same region as Lambda

### Full Scan Takes Too Long

**Issue:** Full scan of large EFS takes excessive time.

**Solutions:**
1. Use manual scan mode to scan specific files/directories
2. Increase Lambda timeout (default is 40 seconds, max is 15 minutes)
3. Consider scanning in batches by directory
4. Use scheduled scans during off-peak hours
5. Optimize EFS performance mode and throughput mode

### SNS Notifications Not Received

**Issue:** No notifications received from SNS topic.

**Solutions:**
1. Verify SNS subscription is confirmed (check email for confirmation link)
2. Check Lambda has permission to publish to SNS
3. Verify SNS topic ARN is correct in Lambda environment variables
4. Check CloudWatch Logs for SNS publish errors
5. Review SNS topic metrics in CloudWatch

## Cleanup

To destroy all resources created by the stack:

```bash
terraform destroy
```

Or for automatic approval:

```bash
terraform destroy -auto-approve
```

**Note:** 
- The Secrets Manager secret will be deleted (back up your API key if needed)
- EFS file system and access point are **not** deleted (they are referenced, not created by this stack)
- Ensure no files are being actively scanned before destroying

### Manual Cleanup

If Terraform destroy fails, you may need to manually delete:
1. Lambda function (delete event source mappings first if scheduled scanning is enabled)
2. Lambda layer versions
3. IAM role and policies
4. SNS topic and subscriptions
5. Secrets Manager secret
6. EventBridge rule and target (if scheduled scanning was enabled)

## Additional Resources

- [AMaaS Python SDK Documentation](https://github.com/trendmicro/cloudone-antimalware-python-sdk)
- [Cloud One Documentation](https://docs.trendmicro.com/en-us/cloud-one/cloud-one-antimalware)
- [AWS EFS Documentation](https://docs.aws.amazon.com/efs/)
- [AWS Lambda with EFS](https://docs.aws.amazon.com/lambda/latest/dg/services-efs.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## Support

For issues related to:
- **Terraform stack**: Open an issue in this repository
- **AMaaS SDK**: Check the [SDK repository](https://github.com/trendmicro/cloudone-antimalware-python-sdk)
- **Cloud One**: Contact Trend Micro support
