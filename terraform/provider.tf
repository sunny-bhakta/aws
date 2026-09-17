terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    random = {
      source = "hashicorp/random"
    }
  }

  required_version = ">= 1.6.0"
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}