variable "environment" {
  description = "Deployment environment (pre-prod, prod)"
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch log groups"
  type        = number
  default     = 90
}

variable "enable_kms" {
  description = "Whether to encrypt CloudWatch log groups with KMS"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for log group encryption (required when enable_kms = true)"
  type        = string
  default     = ""
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for alarm notifications (leave empty to disable notifications)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
