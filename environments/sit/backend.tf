terraform {
  backend "s3" {
    bucket         = "cdcu-terraform-state-sit"
    key            = "cdcu/sit/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "cdcu-terraform-locks-sit"
    encrypt        = true
  }
}
