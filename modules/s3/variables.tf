variable "environment" {
  description = "Deployment environment (pre-prod, prod)"
  type        = string
}

variable "enable_kms" {
  description = "Whether to use KMS encryption for S3 buckets"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for S3 encryption (required when enable_kms = true)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
