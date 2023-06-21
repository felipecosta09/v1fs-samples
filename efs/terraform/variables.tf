
variable "apikey" {
  description = "The Cloud One API key for the scanner"
  type        = string
  default     = ""
}

variable "cloudone_region" {
  description = "The region of the Cloud One console"
  type        = string
  default     = "us-1"
}

variable "aws_region" {
  description = "The region of the AWS account"
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "The prefix for the resources"
  type        = string
  default     = "scanner-efs"
}

variable "efs_id" {
  description = "The ID of the EFS file system"
  type        = string
  default     = ""
}

variable "efs_access_point" {
  description = "The ID of the EFS access point"
  type        = string
  default     = ""
}

variable "subnet" {
  description = "The ID of the subnet"
  type        = string
  default     = ""
}

variable "security_group" {
  description = "The ID of the security group"
  type        = string
  default     = ""
}
