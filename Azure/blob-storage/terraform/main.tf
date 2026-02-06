# Random suffix for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Data source for current Azure subscription
data "azurerm_client_config" "current" {}

# Resource group (use existing)
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

locals {
  suffix = random_string.suffix.result
  tags = {
    Application = "v1fs-scanner"
    ManagedBy   = "terraform"
  }
}
