# System topic for each monitored storage account
resource "azurerm_eventgrid_system_topic" "storage" {
  for_each = toset(var.storage_account_names)

  name                   = "${var.prefix}-${each.value}-${local.suffix}"
  resource_group_name    = data.azurerm_resource_group.main.name
  location               = data.azurerm_resource_group.main.location
  source_arm_resource_id = data.azurerm_storage_account.monitored[each.value].id
  topic_type             = "Microsoft.Storage.StorageAccounts"

  tags = local.tags
}

# Event Grid subscription to trigger scanner function on blob creation
resource "azurerm_eventgrid_system_topic_event_subscription" "scanner" {
  for_each = toset(var.storage_account_names)

  name                = "v1fs-scan"
  system_topic        = azurerm_eventgrid_system_topic.storage[each.value].name
  resource_group_name = data.azurerm_resource_group.main.name

  # Filter to blob created events
  included_event_types = ["Microsoft.Storage.BlobCreated"]

  # Optional: filter to specific containers
  dynamic "subject_filter" {
    for_each = var.container_filter != "" ? [1] : []
    content {
      subject_begins_with = var.container_filter
    }
  }

  # Azure Function endpoint
  azure_function_endpoint {
    function_id = "${azurerm_linux_function_app.scanner.id}/functions/scanner"
  }

  # Ensure function is deployed and ready before creating subscription
  depends_on = [azurerm_linux_function_app.scanner]
}
