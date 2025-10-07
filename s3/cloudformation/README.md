# V1FS S3 CloudFormation Stack

CloudFormation template for V1FS S3 scanning solution with automated Lambda code packaging and upload.

## Quick Start

### 1. Upload Lambda Code to S3
```bash
./upload.sh
```
This will:
- Package your Lambda functions
- Upload them to your S3 bucket
- Show you the CloudFormation deployment command

### 2. Deploy CloudFormation Stack
```bash
aws cloudformation deploy \
  --template-file v1fs-s3-template.yaml \
  --stack-name v1fs-s3-stack \
  --parameter-overrides \
    V1FSApiKey=YOUR_API_KEY \
    LambdaCodeBucket=your-bucket-name \
  --capabilities CAPABILITY_NAMED_IAM
```

## Manual Deployment

If you prefer to handle Lambda code packaging manually:

### 1. Package Lambda Code
```bash
# Package scanner Lambda
cd lambda/scanner/src
zip scanner.zip scanner_lambda.py
aws s3 cp scanner.zip s3://your-bucket/functions/scanner/lambda.zip

# Package tag Lambda  
cd ../../tag/src
zip tag.zip tag_lambda.py
aws s3 cp tag.zip s3://your-bucket/functions/tag/tag.zip

# Upload Lambda layer
aws s3 cp ../scanner/layer/v1fs-python312-arm64.zip s3://your-bucket/layers/v1fs-python312-arm64.zip
```

### 2. Deploy Stack
```bash
aws cloudformation deploy \
  --template-file v1fs-s3-template.yaml \
  --stack-name v1fs-s3-stack \
  --parameter-overrides \
    V1FSApiKey=YOUR_API_KEY \
    LambdaCodeBucket=your-bucket-name \
  --capabilities CAPABILITY_NAMED_IAM
```

## Required Parameters

- `V1FSApiKey` - Your Vision One API key
- `LambdaCodeBucket` - Your S3 bucket name containing Lambda code

## Optional Parameters

- `V1FSRegion` - Vision One region (default: us-east-1)
- `Prefix` - Resource prefix (default: v1fs)
- `EnableTag` - Enable object tagging (default: false)
- `ScannerLambdaKey` - Scanner function S3 key (default: functions/scanner/lambda.zip)
- `TagLambdaKey` - Tag function S3 key (default: functions/tag/tag.zip)
- `ScannerLayerKey` - Layer S3 key (default: layers/v1fs-python312-arm64.zip)

## S3 Structure Expected

```
your-bucket/
├── functions/scanner/lambda.zip
├── functions/tag/tag.zip
└── layers/v1fs-python312-arm64.zip
```

## Features

- ✅ Automated Lambda code packaging and upload
- ✅ Organized parameter groups in AWS Console
- ✅ Complete feature parity with Terraform version
- ✅ Support for VPC, KMS, and object tagging
- ✅ ARM64 architecture for cost optimization

## Testing

1. Enable EventBridge notifications on your S3 bucket
2. Upload a test file (e.g., EICAR test file)
3. Check SNS topic or CloudWatch logs for results

## Cleanup

```bash
aws cloudformation delete-stack --stack-name v1fs-s3-stack
```