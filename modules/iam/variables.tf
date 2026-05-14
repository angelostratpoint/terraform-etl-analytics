variable "environment" {
  description = "Deployment environment (pre-prod, prod)"
  type        = string
}

variable "data_lake_bucket_arn" {
  description = "ARN of the CDCU data lake S3 bucket"
  type        = string
}

variable "athena_results_bucket_arn" {
  description = "ARN of the Athena results S3 bucket"
  type        = string
}

variable "athena_workgroup_name" {
  description = "Name of the Athena workgroup"
  type        = string
}

variable "terraform_lock_table_name" {
  description = "Name of the DynamoDB table used for Terraform state locking"
  type        = string
  default     = "cdcu-terraform-state-lock"
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
