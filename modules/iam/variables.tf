variable "environment" {
  description = "Deployment environment (pre-prod, prod)"
  type        = string
}

variable "enable_kms" {
  description = "Whether to attach KMS usage policies to IAM roles"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "ARN of the CDCU KMS key (required when enable_kms = true)"
  type        = string
  default     = ""
}

variable "sso_principal_arns" {
  description = "List of IAM Identity Center (SSO) principal ARNs allowed to assume human-facing roles"
  type        = list(string)
  default     = []
}

variable "github_org" {
  description = "GitHub organization name for OIDC trust policy"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name for OIDC trust policy"
  type        = string
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
