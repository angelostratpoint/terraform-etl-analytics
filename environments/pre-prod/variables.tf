variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "pre-prod"
}

variable "terraform_role_arn" {
  description = "ARN of the IAM role for Terraform to assume during deployment"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID managed by BPI MS (required for Glue connection placement)"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for Glue connection network placement"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for services that support multi-subnet placement, such as SageMaker Studio"
  type        = list(string)
  default     = []
}

variable "availability_zone" {
  description = "Availability zone matching the subnet_id"
  type        = string
  default     = "ap-southeast-1a"
}

variable "sso_principal_arns" {
  description = "SSO principal ARNs allowed to assume human-facing IAM roles"
  type        = list(string)
  default     = []
}

variable "github_org" {
  description = "GitHub organization name for OIDC trust"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name for OIDC trust"
  type        = string
}

variable "enable_kms" {
  description = "Whether to enable KMS encryption"
  type        = bool
  default     = false
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarm notifications"
  type        = string
  default     = ""
}

variable "glue_worker_count" {
  description = "Number of Glue workers"
  type        = number
  default     = 2
}

variable "glue_worker_type" {
  description = "Glue worker type"
  type        = string
  default     = "G.1X"
}

variable "git_repository_url" {
  description = "HTTPS URL of the GitHub repository for SageMaker code repository"
  type        = string
}

variable "enable_sagemaker_unified_studio" {
  description = "Whether to provision SageMaker Studio for data engineers"
  type        = bool
  default     = true
}

variable "sagemaker_studio_user_profile_names" {
  description = "SageMaker Studio user profile names to create"
  type        = list(string)
  default     = ["data-scientist-01"]
}

variable "sagemaker_notebook_instance_count" {
  description = "Number of classic on-demand SageMaker notebook instances"
  type        = number
  default     = 0
}

variable "sagemaker_notebook_instance_type" {
  description = "Classic SageMaker notebook instance type"
  type        = string
  default     = "ml.c4.2xlarge"
}

variable "sagemaker_studio_app_network_access_type" {
  description = "Network access mode for SageMaker Studio apps"
  type        = string
  default     = "VpcOnly"
}

variable "enable_quicksight" {
  description = "Whether to provision QuickSight data source and dataset resources"
  type        = bool
  default     = true
}

variable "quicksight_admin_principal_arn" {
  description = "QuickSight user or group ARN that owns the CDCU data source and dataset"
  type        = string
  default     = ""
}

variable "quicksight_spice_capacity_gb" {
  description = "SPICE capacity requirement from the AWS Pricing Calculator"
  type        = number
  default     = 10
}
