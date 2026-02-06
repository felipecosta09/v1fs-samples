variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for Cloud Functions and resources"
  type        = string
  default     = "us-central1"
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
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "v1fs"
}

variable "gcs_bucket_names" {
  description = "List of GCS bucket names to monitor for new objects (must be in same region)"
  type        = list(string)
  validation {
    condition     = length(var.gcs_bucket_names) > 0
    error_message = "At least one bucket must be specified."
  }
}

variable "sdk_tags" {
  description = "Tags for Vision One SDK (comma-style in UI)"
  type        = list(string)
  default     = ["env:prod", "project:new_app", "cost-center:dev"]
}

variable "enable_tag" {
  description = "Enable GCS object metadata tagging with scan results"
  type        = bool
  default     = true
}

variable "quarantine_bucket" {
  description = "Bucket to move malicious files to (leave empty to disable quarantine)"
  type        = string
  default     = ""
}

variable "delete_malicious" {
  description = "Delete malicious files from source bucket after quarantine (requires quarantine_bucket)"
  type        = bool
  default     = false
}
