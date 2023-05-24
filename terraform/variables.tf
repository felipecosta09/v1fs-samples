
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