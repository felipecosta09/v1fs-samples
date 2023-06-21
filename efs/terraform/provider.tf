terraform {
  required_providers {
    random = {
      source = "hashicorp/random"
      version = "3.5.1"
    }
    aws = {
      source = "hashicorp/aws"
      version = "5.1"
    }
    archive = {
      source = "hashicorp/archive"
      version = "2.3.0"
    }
  }
  required_version = ">= 0.15.0"
}

provider "aws" {
  region = var.aws_region
}