
variable "v1fs_apikey" {
  description = "The Vision One API key for the scanner"
  type        = string
  default     = ""
}

variable "v1fs_region" {
  description = "The region of the Vision One console"
  type        = string
  default     = "us-east-1"
}

variable "aws_region" {
  description = "The region of the AWS account"
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "The prefix for the resources"
  type        = string
  default     = "v1fs"
}

variable "vpc" {
  description = "The VPC for the scanner"
  type        = object({
    subnet_ids = list(string)
    security_group_ids = list(string)
  })
  default     = null
}

variable "kms_key_bucket" {
  description = "The KMS Master key ARN for the scanner to access objects in a bucket using KMS encryption"
  type        = string
  default     = null
}

variable "sdk_tags" {
  description = "The tags for the resources"
  type        = list(string)
  default     = ["env:prod","project:new_app","cost-center:dev"]
}

# Missing implementation
variable "enable_tag" {
  description = "In case you want to tag the objects scanned by the scanner"
  type        = string
  default     = "false"
}
