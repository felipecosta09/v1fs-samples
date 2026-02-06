
variable "apikey" {
  description = "The Cloud One API key for the scanner"
  type        = string
  default     = ""
}

variable "v1_region" {
  description = "The region of the Cloud One console"
  type        = string
  default     = "ap-southeast-1"
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

variable "schadule_scan" {
  description = "The schedule for the scan"
  type        = bool
  default     = "false"
}

variable "scan_frequency" {
  description = "The frequency of the scan -> https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html"
  type        = string
  # default     = "cron(0/5 * ? * FRI *)" # Every 5 minutes on Friday
  default     = "rate(1 hour)" # Every hour
}
