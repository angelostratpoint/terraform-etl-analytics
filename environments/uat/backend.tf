terraform {
  backend "s3" {
    bucket         = "cdcu-terraform-state-uat"
    key            = "cdcu/uat/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "cdcu-terraform-locks-uat"
    encrypt        = true
  }
}
