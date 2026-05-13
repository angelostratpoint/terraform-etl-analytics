terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"

  assume_role {
    role_arn     = var.terraform_role_arn
    session_name = "cdcu-terraform-pre-prod"
  }

  default_tags {
    tags = {
      Project     = "CDCU"
      Environment = "pre-prod"
      ManagedBy   = "Terraform"
      Owner       = "Stratpoint"
      CostCenter  = "CDCU-PRE-PROD"
    }
  }
}
