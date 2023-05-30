
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
  default     = "scanner"
}

variable "vpc" {
  description = "The VPC for the scanner"
  type        = object({
    subnet_ids = list(string)
    security_group_ids = list(string)
  })
  default     = null
}
