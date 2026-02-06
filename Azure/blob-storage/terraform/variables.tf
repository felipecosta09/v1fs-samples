variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "v1fs_apikey" {
  description = "Vision One API key for the scanner"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.v1fs_apikey) > 0
    error_message = "v1fs_apikey must be set and cannot be empty."
  }
}

variable "v1fs_region" {
  description = "Vision One File Security region"
  type        = string
  default     = "us-east-1"
  validation {
    condition     = contains(["us-east-1", "eu-central-1", "ap-northeast-1", "ap-southeast-1", "ap-southeast-2", "ap-south-1"], var.v1fs_region)
    error_message = "v1fs_region must be a valid Vision One region."
  }
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "v1fs"
}

variable "storage_account_names" {
  description = "List of existing storage account names to monitor"
  type        = list(string)
  validation {
    condition     = length(var.storage_account_names) > 0
    error_message = "At least one storage account must be specified."
  }
}

variable "container_filter" {
  description = "Optional: Filter to specific containers (e.g., '/blobServices/default/containers/mycontainer/'). Leave empty for all containers."
  type        = string
  default     = ""
}

variable "sdk_tags" {
  description = "Tags for Vision One SDK"
  type        = list(string)
  default     = ["env:prod", "project:azure", "cost-center:dev"]
}

variable "enable_tag" {
  description = "Enable blob metadata tagging with scan results"
  type        = bool
  default     = true
}

variable "quarantine_container" {
  description = "Container name for quarantined malicious files (leave empty to disable)"
  type        = string
  default     = ""
}

variable "delete_malicious" {
  description = "Delete malicious files from source after quarantine"
  type        = bool
  default     = false
}

variable "function_sku" {
  description = "SKU for the Function App service plan"
  type        = string
  default     = "Y1" # Consumption plan
}
