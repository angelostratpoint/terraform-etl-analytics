terraform {
  backend "s3" {
    bucket         = "cdcu-terraform-state-prod"
    key            = "cdcu/prod/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "cdcu-terraform-locks-prod"
    encrypt        = true
  }
}
