variable "environment" {
  description = "Deployment environment (pre-prod, prod)"
  type        = string
}

variable "deletion_window_in_days" {
  description = "Number of days before KMS key is deleted after scheduled deletion"
  type        = number
  default     = 30
}

variable "allowed_role_arns" {
  description = "List of IAM role ARNs permitted to use this KMS key"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
