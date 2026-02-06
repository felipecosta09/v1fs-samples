terraform {
  required_providers {
    random = {
      source = "hashicorp/random"
      version = "3.6.0"
    }
    aws = {
      source = "hashicorp/aws"
      version = "5.69.0"
    }
    archive = {
      source = "hashicorp/archive"
      version = "2.6.0"
    }
  }
  required_version = ">= 0.15.0"
}

provider "aws" {
  region = var.aws_region
}