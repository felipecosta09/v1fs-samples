# Key Vault for storing the Vision One API key
resource "azurerm_key_vault" "main" {
  name                       = "${var.prefix}kv${local.suffix}"
  location                   = data.azurerm_resource_group.main.location
  resource_group_name        = data.azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  tags = local.tags
}

# Access policy for the current user (deployer)
resource "azurerm_key_vault_access_policy" "deployer" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Purge",
    "Recover",
  ]
}

# Store the Vision One API key
resource "azurerm_key_vault_secret" "v1fs_apikey" {
  name         = "${var.prefix}-apikey"
  value        = var.v1fs_apikey
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.deployer]
}

# Access policy for the scanner function
resource "azurerm_key_vault_access_policy" "scanner_function" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_function_app.scanner.identity[0].principal_id

  secret_permissions = [
    "Get",
  ]
}

# Access policy for the tag function (if enabled)
resource "azurerm_key_vault_access_policy" "tag_function" {
  count        = var.enable_tag ? 1 : 0
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_function_app.tag[0].identity[0].principal_id

  secret_permissions = [
    "Get",
  ]
}
