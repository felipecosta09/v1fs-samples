# Storage account for Function App
resource "azurerm_storage_account" "function" {
  name                     = "${var.prefix}fn${local.suffix}"
  resource_group_name      = data.azurerm_resource_group.main.name
  location                 = data.azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = local.tags
}

# Queue for scan results (used by tag function)
resource "azurerm_storage_queue" "scan_results" {
  name                 = "scan-results"
  storage_account_name = azurerm_storage_account.function.name
}

# Data sources for monitored storage accounts
data "azurerm_storage_account" "monitored" {
  for_each            = toset(var.storage_account_names)
  name                = each.value
  resource_group_name = data.azurerm_resource_group.main.name
}
