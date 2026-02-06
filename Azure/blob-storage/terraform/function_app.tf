# Archive scanner function code
data "archive_file" "scanner" {
  type        = "zip"
  source_dir  = "${path.module}/../functions/scanner"
  output_path = "${path.module}/.terraform/tmp/scanner.zip"
}

# Archive tag function code
data "archive_file" "tag" {
  count       = var.enable_tag ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../functions/tag"
  output_path = "${path.module}/.terraform/tmp/tag.zip"
}

# App Service Plan (Consumption)
resource "azurerm_service_plan" "main" {
  name                = "${var.prefix}-plan-${local.suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.function_sku

  tags = local.tags
}

# Log Analytics Workspace for Application Insights
data "azurerm_log_analytics_workspace" "default" {
  name                = "DefaultWorkspace-edbb5b90-6d3b-46af-a3ca-e35c7f1172b9-EUS"
  resource_group_name = "DefaultResourceGroup-EUS"
}

# Application Insights for monitoring
resource "azurerm_application_insights" "main" {
  name                = "${var.prefix}-insights-${local.suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  application_type    = "other"
  workspace_id        = data.azurerm_log_analytics_workspace.default.id

  tags = local.tags
}

# Scanner Function App
resource "azurerm_linux_function_app" "scanner" {
  name                = "${var.prefix}-scanner-${local.suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  storage_account_name       = azurerm_storage_account.function.name
  storage_account_access_key = azurerm_storage_account.function.primary_access_key
  service_plan_id            = azurerm_service_plan.main.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.12"
    }

    application_insights_key               = azurerm_application_insights.main.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.main.connection_string
  }

  app_settings = {
    # Build settings for zip deployment
    ENABLE_ORYX_BUILD              = "true"
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    AzureWebJobsFeatureFlags       = "EnableWorkerIndexing"

    # Function settings
    FUNCTIONS_WORKER_RUNTIME = "python"

    # V1FS settings
    V1FS_REGION = var.v1fs_region
    SDK_TAGS    = join(",", var.sdk_tags)

    # Key Vault reference for API key
    V1FS_APIKEY = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=${azurerm_key_vault_secret.v1fs_apikey.name})"

    # Queue for scan results
    SCAN_RESULTS_QUEUE_CONNECTION = azurerm_storage_account.function.primary_connection_string
    SCAN_RESULTS_QUEUE_NAME       = azurerm_storage_queue.scan_results.name

    # Storage connection for blob access
    MONITORED_STORAGE_CONNECTION = data.azurerm_storage_account.monitored[var.storage_account_names[0]].primary_connection_string
  }

  # Deploy function code via zip
  zip_deploy_file = data.archive_file.scanner.output_path

  tags = local.tags

  depends_on = [data.archive_file.scanner]
}

# Tag Function App (optional)
resource "azurerm_linux_function_app" "tag" {
  count = var.enable_tag ? 1 : 0

  name                = "${var.prefix}-tag-${local.suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  storage_account_name       = azurerm_storage_account.function.name
  storage_account_access_key = azurerm_storage_account.function.primary_access_key
  service_plan_id            = azurerm_service_plan.main.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.12"
    }

    application_insights_key               = azurerm_application_insights.main.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.main.connection_string
  }

  app_settings = {
    # Build settings for zip deployment
    ENABLE_ORYX_BUILD              = "true"
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    AzureWebJobsFeatureFlags       = "EnableWorkerIndexing"

    # Function settings
    FUNCTIONS_WORKER_RUNTIME = "python"

    # Queue trigger connection
    SCAN_RESULTS_QUEUE_CONNECTION = azurerm_storage_account.function.primary_connection_string
    SCAN_RESULTS_QUEUE_NAME       = azurerm_storage_queue.scan_results.name

    # Storage connection for blob access
    MONITORED_STORAGE_CONNECTION = data.azurerm_storage_account.monitored[var.storage_account_names[0]].primary_connection_string

    # Quarantine settings
    QUARANTINE_CONTAINER = var.quarantine_container
    DELETE_MALICIOUS     = tostring(var.delete_malicious)
  }

  # Deploy function code via zip
  zip_deploy_file = data.archive_file.tag[0].output_path

  tags = local.tags

  depends_on = [data.archive_file.tag]
}

# Role assignments for scanner function to read blobs
resource "azurerm_role_assignment" "scanner_blob_reader" {
  for_each = toset(var.storage_account_names)

  scope                = data.azurerm_storage_account.monitored[each.value].id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_linux_function_app.scanner.identity[0].principal_id
}

# Role assignments for tag function to read/write blobs
resource "azurerm_role_assignment" "tag_blob_contributor" {
  for_each = var.enable_tag ? toset(var.storage_account_names) : toset([])

  scope                = data.azurerm_storage_account.monitored[each.value].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.tag[0].identity[0].principal_id
}
