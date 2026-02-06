# Vision One File Security - GCS Scanner

Automated malware scanning for Google Cloud Storage using Trend Micro Vision One File Security.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              GCP Architecture                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐     ┌──────────────┐     ┌─────────────────┐               │
│  │ GCS Bucket  │────▶│   Eventarc   │────▶│ Scanner Function│               │
│  │  (upload)   │     │   Trigger    │     │   (Python 3.12) │               │
│  └─────────────┘     └──────────────┘     └────────┬────────┘               │
│                                                     │                        │
│                                                     ▼                        │
│  ┌─────────────┐     ┌──────────────┐     ┌─────────────────┐               │
│  │   Secret    │────▶│  Vision One  │────▶│  Pub/Sub Topic  │               │
│  │   Manager   │     │  File Security│    │  (scan results) │               │
│  └─────────────┘     └──────────────┘     └────────┬────────┘               │
│                                                     │                        │
│                                                     ▼                        │
│  ┌─────────────┐     ┌──────────────┐     ┌─────────────────┐               │
│  │ Quarantine  │◀────│ Tag Function │◀────│   Pub/Sub       │               │
│  │   Bucket    │     │  (metadata)  │     │   Subscription  │               │
│  └─────────────┘     └──────────────┘     └─────────────────┘               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Features

- **Automatic Scanning** - Files scanned immediately on upload
- **Multi-Bucket Support** - Monitor multiple GCS buckets
- **Object Metadata Tagging** - Scan results stored as object metadata
- **Quarantine** - Automatically isolate malicious files
- **Monitoring** - Cloud Monitoring alerts for malware detection
- **Serverless** - Cloud Functions Gen 2 (scales to zero)

## Prerequisites

- GCP Project with billing enabled
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) installed and authenticated
- [Terraform](https://www.terraform.io/downloads) >= 0.15
- Vision One API Key ([get one here](https://docs.trendmicro.com/en-us/documentation/article/trend-vision-one-api-keys))

## Quick Start

### 1. Authenticate with GCP

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

### 2. Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
project_id       = "your-project-id"
v1fs_apikey      = "your-vision-one-api-key"
gcs_bucket_names = ["bucket-1", "bucket-2"]
region           = "us-central1"
```

### 3. Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 4. Test

```bash
# Upload a test file
echo "test" > /tmp/test.txt
gcloud storage cp /tmp/test.txt gs://your-bucket/

# Check scan result (wait ~30 seconds)
gcloud storage objects describe gs://your-bucket/test.txt --format="yaml(metadata)"
```

## Configuration

### Required Variables

| Variable | Description |
|----------|-------------|
| `project_id` | GCP project ID |
| `v1fs_apikey` | Vision One API key |
| `gcs_bucket_names` | List of buckets to monitor |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `region` | `us-central1` | GCP region (must match bucket region) |
| `v1fs_region` | `us-east-1` | Vision One region |
| `prefix` | `v1fs` | Resource name prefix |
| `enable_tag` | `true` | Enable metadata tagging |
| `quarantine_bucket` | `""` | Bucket for malicious files |
| `delete_malicious` | `false` | Delete malicious files after quarantine |
| `sdk_tags` | `["env:prod"]` | Tags for Vision One console |

### Vision One Regions

| Region | Location |
|--------|----------|
| `us-east-1` | United States |
| `eu-central-1` | Europe (Germany) |
| `ap-northeast-1` | Asia Pacific (Japan) |
| `ap-southeast-1` | Asia Pacific (Singapore) |
| `ap-southeast-2` | Asia Pacific (Australia) |
| `ap-south-1` | Asia Pacific (India) |

## Object Metadata

Scanned objects receive the following metadata:

| Key | Description | Example |
|-----|-------------|---------|
| `fss-scanned` | Scan completed | `true` |
| `fss-scan-result` | Scan verdict | `clean`, `malicious`, `unknown` |
| `fss-scan-detail-code` | Result code | `0`=clean, `1`=malicious |
| `fss-scan-date` | Scan timestamp | `2026/02/04 12:34:56` |
| `fss-scan-detail-message` | Additional details | Malware names if detected |
| `fss-quarantined` | File was quarantined | `true` (if applicable) |

## Quarantine

When `quarantine_bucket` is configured:

1. Malicious files are copied to: `gs://{quarantine_bucket}/{timestamp}/{source_bucket}/{object_path}`
2. Quarantine metadata includes original location and malware details
3. If `delete_malicious = true`, the original file is deleted

### Example

```hcl
quarantine_bucket  = "my-quarantine-bucket"
delete_malicious   = true
```

## Monitoring

The deployment includes Cloud Monitoring resources:

- **Malware Detection Alert** - Notifies when malware is found
- **Scanner Error Alert** - Notifies on function failures
- **Scan Results Metric** - Tracks clean/malicious/error counts

### Enable Email Notifications

1. Edit `monitoring.tf`
2. Uncomment the `google_monitoring_notification_channel` resource
3. Set your email address
4. Run `terraform apply`

## Logs

```bash
# Scanner function logs
gcloud functions logs read --gen2 \
  --region=us-central1 \
  --filter="resource.labels.function_name~v1fs-scanner"

# Tag function logs
gcloud functions logs read --gen2 \
  --region=us-central1 \
  --filter="resource.labels.function_name~v1fs-tag"
```

## Adding Buckets

To add more buckets to monitor:

1. Edit `terraform.tfvars`:
   ```hcl
   gcs_bucket_names = ["bucket-1", "bucket-2", "new-bucket-3"]
   ```

2. Apply changes:
   ```bash
   terraform apply
   ```

Terraform automatically creates new Eventarc triggers and IAM bindings.

## Costs

| Resource | Pricing |
|----------|---------|
| Cloud Functions | [Pay per invocation](https://cloud.google.com/functions/pricing) |
| Eventarc | [Free tier available](https://cloud.google.com/eventarc/pricing) |
| Pub/Sub | [Pay per message](https://cloud.google.com/pubsub/pricing) |
| Secret Manager | [Pay per secret version](https://cloud.google.com/secret-manager/pricing) |
| Vision One | [Contact Trend Micro](https://www.trendmicro.com/en_us/business/products/detection-response/xdr.html) |

## Troubleshooting

### Scanner not triggering

1. Verify bucket is in the same region as functions:
   ```bash
   gcloud storage buckets describe gs://your-bucket --format="value(location)"
   ```

2. Check Eventarc trigger exists:
   ```bash
   gcloud eventarc triggers list --location=us-central1
   ```

### Permission errors

1. Verify service account has bucket access:
   ```bash
   gcloud storage buckets get-iam-policy gs://your-bucket
   ```

2. Check function service account:
   ```bash
   gcloud functions describe v1fs-scanner-XXXXX --gen2 --region=us-central1 \
     --format="value(serviceConfig.serviceAccountEmail)"
   ```

### API key issues

1. Verify secret exists:
   ```bash
   gcloud secrets list --filter="name~v1fs-apikey"
   ```

2. Check secret value (be careful with output):
   ```bash
   gcloud secrets versions access latest --secret=v1fs-apikey-XXXXX
   ```

## Cleanup

```bash
terraform destroy
```
