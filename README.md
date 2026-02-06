# V1FS Stack Examples

This repository shows how to use the [V1FS Python SDK](https://github.com/trendmicro/tm-v1-fs-python-sdk) to create stacks that automatically scan files across different cloud storage services.

## Quick Links

| Cloud | Storage Type | Link |
|-------|-------------|------|
| AWS | S3 | [AWS/s3](./AWS/s3) |
| AWS | EFS | [AWS/efs](./AWS/efs) |
| GCP | Cloud Storage | [GCP/storage](./GCP/storage) |
| Azure | Blob Storage | [Azure/blob-storage](./Azure/blob-storage) |

## Requirements

- [Vision One](https://www.trendmicro.com/visionone) account ([Sign up for a free trial](https://resources.trendmicro.com/vision-one-trial.html))
- [API key](https://docs.trendmicro.com/en-us/documentation/article/trend-vision-one-__api-keys-2) with **Run file scan via SDK** permissions
- [Terraform CLI](https://learn.hashicorp.com/tutorials/terraform/install-cli#install-terraform)
- Cloud CLI for your platform:
  - AWS: [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  - GCP: [gcloud CLI](https://cloud.google.com/sdk/docs/install)
  - Azure: [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

## Usage

Each cloud directory contains Terraform configurations that deploy serverless functions to scan files on upload. See the individual README files in each directory for specific deployment instructions.
