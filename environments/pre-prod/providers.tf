terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Sandbox: assume_role removed — using stratpoint-gelo IAM user credentials directly.
# In BPI MS environment, restore assume_role with the approved deployment role ARN:
#   assume_role {
#     role_arn     = var.terraform_role_arn
#     session_name = "cdcu-terraform-pre-prod"
#   }
provider "aws" {
  region = "ap-southeast-1"

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
