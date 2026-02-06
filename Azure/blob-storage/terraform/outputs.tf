output "scanner_function_name" {
  description = "Name of the scanner Function App"
  value       = azurerm_linux_function_app.scanner.name
}

output "scanner_function_url" {
  description = "URL of the scanner Function App"
  value       = "https://${azurerm_linux_function_app.scanner.default_hostname}"
}

output "tag_function_name" {
  description = "Name of the tag Function App"
  value       = var.enable_tag ? azurerm_linux_function_app.tag[0].name : null
}

output "key_vault_name" {
  description = "Name of the Key Vault storing the API key"
  value       = azurerm_key_vault.main.name
}

output "scan_results_queue" {
  description = "Name of the scan results queue"
  value       = azurerm_storage_queue.scan_results.name
}

output "monitored_storage_accounts" {
  description = "Storage accounts being monitored"
  value       = var.storage_account_names
}

output "application_insights_name" {
  description = "Name of Application Insights instance"
  value       = azurerm_application_insights.main.name
}

output "resource_group" {
  description = "Resource group containing all resources"
  value       = data.azurerm_resource_group.main.name
}
