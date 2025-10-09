#!/bin/bash

# V1FS Lambda Code Upload Script
# This script packages Lambda functions and uploads them to S3

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to get user input
get_input() {
    local prompt="$1"
    local default="$2"
    local input
    
    if [ -n "$default" ]; then
        echo -n "$prompt [$default]: "
        read -r input
        echo "${input:-$default}"
    else
        echo -n "$prompt: "
        read -r input
        echo "$input"
    fi
}

# Check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    print_status "AWS CLI found"
}

# Check if required files exist
check_files() {
    local missing_files=()
    
    if [ ! -f "lambda/scanner/src/scanner_lambda.py" ]; then
        missing_files+=("lambda/scanner/src/scanner_lambda.py")
    fi
    
    if [ ! -f "lambda/tag/src/tag_lambda.py" ]; then
        missing_files+=("lambda/tag/src/tag_lambda.py")
    fi
    
    if [ ! -f "lambda/scanner/layer/v1fs-python312-arm64.zip" ]; then
        missing_files+=("lambda/scanner/layer/v1fs-python312-arm64.zip")
    fi
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        print_error "Missing required files:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        exit 1
    fi
    
    print_status "All required files found"
}

# Package Lambda functions
package_lambda_functions() {
    print_status "Packaging Lambda functions..."
    
    # Create temporary directories
    mkdir -p temp/scanner temp/tag
    
    # Package scanner Lambda
    print_status "Packaging scanner Lambda function..."
    cp lambda/scanner/src/scanner_lambda.py temp/scanner/
    cd temp/scanner
    zip -r scanner.zip . > /dev/null
    cd ../..
    
    # Package tag Lambda
    print_status "Packaging tag Lambda function..."
    cp lambda/tag/src/tag_lambda.py temp/tag/
    cd temp/tag
    zip -r tag_lambda.zip . > /dev/null
    cd ../..
    
    print_status "Lambda functions packaged successfully"
}

# Upload to S3
upload_to_s3() {
    local bucket_name="$1"
    
    print_status "Uploading Lambda code to S3 bucket: $bucket_name"
    
    # Check if bucket exists
    if ! aws s3 ls "s3://$bucket_name" &> /dev/null; then
        print_error "S3 bucket '$bucket_name' does not exist or you don't have access to it"
        exit 1
    fi
    
    # Upload scanner Lambda
    print_status "Uploading scanner Lambda function..."
    aws s3 cp temp/scanner/scanner.zip "s3://$bucket_name/functions/scanner/lambda.zip"
    
    # Upload tag Lambda
    print_status "Uploading tag Lambda function..."
    aws s3 cp temp/tag/tag_lambda.zip "s3://$bucket_name/functions/tag/tag_lambda.zip"
    
    # Upload Lambda layer
    print_status "Uploading Lambda layer..."
    aws s3 cp lambda/scanner/layer/v1fs-python312-arm64.zip "s3://$bucket_name/layers/v1fs-python312-arm64.zip"
    
    print_status "All files uploaded successfully to S3"
}

# Cleanup temporary files
cleanup() {
    print_status "Cleaning up temporary files..."
    rm -rf temp/
    print_status "Cleanup completed"
}

# Main function
main() {
    print_status "Starting Lambda code packaging and upload..."
    echo ""
    
    # Check prerequisites
    check_aws_cli
    check_files
    
    # Get user input
    echo ""
    echo -n "S3 bucket name for Lambda code: "
    read -r bucket_name
    
    echo ""
    print_status "Upload Configuration:"
    echo "  S3 Bucket: $bucket_name"
    echo ""
    
    # Execute upload steps
    package_lambda_functions
    upload_to_s3 "$bucket_name"
    cleanup
    
    echo ""
    print_status "Upload completed successfully!"
    print_warning "Files uploaded to S3:"
    print_warning "  - s3://$bucket_name/functions/scanner/lambda.zip"
    print_warning "  - s3://$bucket_name/functions/tag/tag_lambda.zip"
    print_warning "  - s3://$bucket_name/layers/v1fs-python312-arm64.zip"
    echo ""
    print_warning "You can now deploy the CloudFormation stack using:"
    print_warning "aws cloudformation deploy --template-file v1fs-s3-template.yaml --stack-name your-stack-name --parameter-overrides V1FSApiKey=YOUR_KEY LambdaCodeBucket=$bucket_name --capabilities CAPABILITY_NAMED_IAM"
}

# Handle script arguments
case "${1:-upload}" in
    upload)
        main
        ;;
    *)
        echo "Usage: $0 {upload}"
        echo "  upload - Package Lambda code and upload to S3 (default)"
        exit 1
        ;;
esac
