# Vision One File Security - Azure Blob Storage Scanner

Automated malware scanning for Azure Blob Storage using Trend Micro Vision One File Security.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                             Azure Architecture                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐     ┌──────────────┐     ┌─────────────────┐               │
│  │ Blob Storage│────▶│  Event Grid  │────▶│ Scanner Function│               │
│  │  (upload)   │     │  Subscription│     │   (Python 3.12) │               │
│  └─────────────┘     └──────────────┘     └────────┬────────┘               │
│                                                     │                        │
│                                                     ▼                        │
│  ┌─────────────┐     ┌──────────────┐     ┌─────────────────┐               │
│  │  Key Vault  │────▶│  Vision One  │────▶│  Storage Queue  │               │
│  │  (API key)  │     │ File Security│     │  (scan results) │               │
│  └─────────────┘     └──────────────┘     └────────┬────────┘               │
│                                                     │                        │
│                                                     ▼                        │
│  ┌─────────────┐     ┌──────────────┐     ┌─────────────────┐               │
│  │ Quarantine  │◀────│ Tag Function │◀────│  Queue Trigger  │               │
│  │  Container  │     │  (metadata)  │     │                 │               │
│  └─────────────┘     └──────────────┘     └─────────────────┘               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Features

- **Automatic Scanning** - Blobs scanned immediately on upload
- **Multi-Storage Account Support** - Monitor multiple storage accounts
- **Blob Metadata Tagging** - Scan results stored as blob metadata
- **Quarantine** - Automatically isolate malicious files
- **Application Insights** - Built-in monitoring and logging
- **Serverless** - Azure Functions (Consumption plan)

## Prerequisites

- Azure subscription
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and authenticated
- [Terraform](https://www.terraform.io/downloads) >= 1.0
- Vision One API Key ([get one here](https://docs.trendmicro.com/en-us/documentation/article/trend-vision-one-api-keys))
- Existing resource group and storage account(s) to monitor

## Quick Start

### 1. Authenticate with Azure

```bash
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### 2. Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
resource_group_name   = "my-resource-group"
v1fs_apikey           = "your-vision-one-api-key"
storage_account_names = ["mystorageaccount1"]
location              = "eastus"
```

### 3. Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 4. Deploy Function Code

After Terraform creates the infrastructure, deploy the function code:

```bash
# Deploy scanner function
cd ../functions/scanner
func azure functionapp publish v1fs-scanner-XXXXXXXX

# Deploy tag function (if enabled)
cd ../tag
func azure functionapp publish v1fs-tag-XXXXXXXX
```

### 5. Test

```bash
# Upload a test file
az storage blob upload \
  --account-name mystorageaccount1 \
  --container-name mycontainer \
  --file /tmp/test.txt \
  --name test.txt

# Check metadata (wait ~30 seconds)
az storage blob metadata show \
  --account-name mystorageaccount1 \
  --container-name mycontainer \
  --name test.txt
```

## Configuration

### Required Variables

| Variable | Description |
|----------|-------------|
| `resource_group_name` | Existing Azure resource group |
| `v1fs_apikey` | Vision One API key |
| `storage_account_names` | List of storage accounts to monitor |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `location` | `eastus` | Azure region |
| `v1fs_region` | `us-east-1` | Vision One region |
| `prefix` | `v1fs` | Resource name prefix |
| `container_names` | `["*"]` | Containers to monitor (`["*"]` = all) |
| `enable_tag` | `true` | Enable metadata tagging |
| `quarantine_container` | `""` | Container for malicious files |
| `delete_malicious` | `false` | Delete malicious files after quarantine |
| `function_sku` | `Y1` | Function App SKU |

### Vision One Regions

| Region | Location |
|--------|----------|
| `us-east-1` | United States |
| `eu-central-1` | Europe (Germany) |
| `ap-northeast-1` | Asia Pacific (Japan) |
| `ap-southeast-1` | Asia Pacific (Singapore) |
| `ap-southeast-2` | Asia Pacific (Australia) |
| `ap-south-1` | Asia Pacific (India) |

## Blob Metadata

Scanned blobs receive the following metadata:

| Key | Description | Example |
|-----|-------------|---------|
| `fss_scanned` | Scan completed | `true` |
| `fss_scan_result` | Scan verdict | `clean`, `malicious`, `unknown` |
| `fss_scan_detail_code` | Result code | `0`=clean, `1`=malicious |
| `fss_scan_date` | Scan timestamp | `2026/02/04 12:34:56` |
| `fss_scan_detail_message` | Additional details | Malware names if detected |
| `fss_quarantined` | File was quarantined | `true` (if applicable) |

> **Note:** Azure blob metadata keys use underscores instead of hyphens.

## Quarantine

When `quarantine_container` is configured:

1. Malicious blobs are copied to: `{quarantine_container}/{timestamp}/{source_container}/{blob_path}`
2. Quarantine metadata includes original location and malware details
3. If `delete_malicious = true`, the original blob is deleted

### Setup Quarantine

1. Create a quarantine container:
   ```bash
   az storage container create \
     --account-name mystorageaccount1 \
     --name quarantine
   ```

2. Update `terraform.tfvars`:
   ```hcl
   quarantine_container = "quarantine"
   delete_malicious     = true
   ```

3. Apply changes:
   ```bash
   terraform apply
   ```

## Monitoring

### Application Insights

All function logs are sent to Application Insights. View logs in the Azure Portal or query with:

```bash
# Get Application Insights name
terraform output application_insights_name

# View logs in portal
az monitor app-insights query \
  --app v1fs-insights-XXXXXXXX \
  --analytics-query "traces | where message contains 'scan' | take 50"
```

### Function Logs

```bash
# Stream scanner function logs
func azure functionapp logstream v1fs-scanner-XXXXXXXX

# Stream tag function logs
func azure functionapp logstream v1fs-tag-XXXXXXXX
```

## Adding Storage Accounts

To monitor additional storage accounts:

1. Edit `terraform.tfvars`:
   ```hcl
   storage_account_names = ["account1", "account2", "newaccount3"]
   ```

2. Apply changes:
   ```bash
   terraform apply
   ```

Terraform creates new Event Grid subscriptions and role assignments automatically.

## Resources Created

| Resource | Description |
|----------|-------------|
| Key Vault | Stores Vision One API key |
| Storage Account | Function App storage + queues |
| Storage Queue | Scan results queue |
| App Service Plan | Consumption plan for functions |
| Function App (scanner) | Scans blobs on upload |
| Function App (tag) | Applies metadata to blobs |
| Application Insights | Monitoring and logging |
| Event Grid System Topic | Per monitored storage account |
| Event Grid Subscription | Triggers on blob creation |
| Role Assignments | Blob read/write permissions |

## Costs

| Resource | Pricing |
|----------|---------|
| Azure Functions | [Pay per execution](https://azure.microsoft.com/pricing/details/functions/) |
| Event Grid | [Pay per operation](https://azure.microsoft.com/pricing/details/event-grid/) |
| Storage Queue | [Pay per transaction](https://azure.microsoft.com/pricing/details/storage/queues/) |
| Key Vault | [Pay per operation](https://azure.microsoft.com/pricing/details/key-vault/) |
| Application Insights | [Pay per GB ingested](https://azure.microsoft.com/pricing/details/monitor/) |
| Vision One | [Contact Trend Micro](https://www.trendmicro.com/en_us/business/products/detection-response/xdr.html) |

## Troubleshooting

### Function not triggering

1. Verify Event Grid subscription exists:
   ```bash
   az eventgrid system-topic event-subscription list \
     --resource-group my-resource-group \
     --system-topic-name v1fs-mystorageaccount-XXXXXXXX
   ```

2. Check Event Grid topic:
   ```bash
   az eventgrid system-topic show \
     --resource-group my-resource-group \
     --name v1fs-mystorageaccount-XXXXXXXX
   ```

### Permission errors

1. Verify function has blob access:
   ```bash
   az role assignment list \
     --assignee $(az functionapp identity show -g my-resource-group -n v1fs-scanner-XXXXXXXX --query principalId -o tsv) \
     --scope /subscriptions/.../storageAccounts/mystorageaccount
   ```

2. Verify Key Vault access:
   ```bash
   az keyvault show --name v1fskvXXXXXXXX --query "properties.accessPolicies"
   ```

### API key issues

1. Verify secret exists:
   ```bash
   az keyvault secret show --vault-name v1fskvXXXXXXXX --name v1fs-apikey
   ```

2. Check function app settings:
   ```bash
   az functionapp config appsettings list \
     --resource-group my-resource-group \
     --name v1fs-scanner-XXXXXXXX \
     --query "[?name=='V1FS_APIKEY']"
   ```

## Cleanup

```bash
terraform destroy
```
