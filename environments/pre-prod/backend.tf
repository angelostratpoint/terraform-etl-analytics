terraform {
  backend "s3" {
    bucket         = "cdcu-terraform-state-pre-prod-024415233264"
    key            = "cdcu/pre-prod/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "cdcu-terraform-locks-pre-prod"
    encrypt        = true
  }
}
