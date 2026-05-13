variable "environment" {
  description = "Deployment environment (pre-prod, prod)"
  type        = string
}

variable "athena_results_bucket" {
  description = "Name of the S3 bucket for Athena query results"
  type        = string
}

variable "glue_catalog_database" {
  description = "Name of the Glue Data Catalog database for named queries"
  type        = string
}

variable "enable_kms" {
  description = "Whether to encrypt Athena query results with KMS"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for Athena result encryption (required when enable_kms = true)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
