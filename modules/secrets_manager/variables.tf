variable "environment" {
  description = "Deployment environment (pre-prod, prod)"
  type        = string
}

variable "enable_kms" {
  description = "Whether to encrypt secrets with a KMS key"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for secret encryption (required when enable_kms = true)"
  type        = string
  default     = ""
}

variable "recovery_window_in_days" {
  description = "Number of days before a deleted secret is permanently removed"
  type        = number
  default     = 30
}

variable "enable_rotation" {
  description = "Whether to enable automatic secret rotation"
  type        = bool
  default     = false
}

variable "rotation_days" {
  description = "Number of days between automatic secret rotations"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
