variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "pre-prod"

  validation {
    condition     = contains(["pre-prod", "prod"], var.environment)
    error_message = "environment must be one of: pre-prod, prod"
  }
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

variable "microsite_jdbc_url" {
  description = "JDBC URL for the BPI MS Microsite MySQL source database"
  type        = string

  validation {
    condition     = startswith(var.microsite_jdbc_url, "jdbc:mysql://") && !can(regex("localhost", lower(var.microsite_jdbc_url)))
    error_message = "microsite_jdbc_url must be a non-local MySQL JDBC URL from BPI MS."
  }
}

variable "legacy_jdbc_url" {
  description = "JDBC URL for the BPI MS Legacy MySQL source database"
  type        = string

  validation {
    condition     = startswith(var.legacy_jdbc_url, "jdbc:mysql://") && !can(regex("localhost", lower(var.legacy_jdbc_url)))
    error_message = "legacy_jdbc_url must be a non-local MySQL JDBC URL from BPI MS."
  }
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

variable "sagemaker_studio_space_instance_type" {
  description = "Instance type for the JupyterLab space in Unified Studio"
  type        = string
  default     = "ml.t3.medium"
}

variable "sagemaker_studio_space_volume_size_gb" {
  description = "EBS volume size in GB for the JupyterLab space"
  type        = number
  default     = 5
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

###############################################################################
# Client-Managed Baseline Inputs
# IAM/RBAC, KMS, network, and source database access are prepared manually by
# BPI MS/Stratpoint before this Terraform workspace runs. Terraform consumes
# those existing IDs and ARNs while provisioning the CDCU application services.
###############################################################################

variable "terraform_lock_table_name" {
  description = "Name of the DynamoDB table used for Terraform state locking"
  type        = string
  default     = "cdcu-terraform-state-lock"
}

variable "manage_iam" {
  description = <<-EOT
    Deprecated compatibility flag retained for tfvars compatibility.
    ST-CDCU IAM roles and groups are created by the modules/iam module.
  EOT
  type        = bool
  default     = false
}

variable "existing_glue_execution_role_arn" {
  description = "Deprecated compatibility input. Glue now uses module.iam.glue_execution_role_arn."
  type        = string
  default     = ""

  validation {
    condition     = var.existing_glue_execution_role_arn == "" || can(regex("^arn:aws:iam::[0-9]{12}:role/.+$", var.existing_glue_execution_role_arn))
    error_message = "existing_glue_execution_role_arn must be a valid IAM role ARN."
  }
}

variable "existing_sagemaker_execution_role_arn" {
  description = "Deprecated compatibility input. SageMaker now uses module.iam.sagemaker_execution_role_arn."
  type        = string
  default     = ""

  validation {
    condition     = var.existing_sagemaker_execution_role_arn == "" || can(regex("^arn:aws:iam::[0-9]{12}:role/.+$", var.existing_sagemaker_execution_role_arn))
    error_message = "existing_sagemaker_execution_role_arn must be a valid IAM role ARN."
  }
}

variable "existing_quicksight_access_role_arn" {
  description = "ARN of the client-managed QuickSight access role, if required by the QuickSight setup"
  type        = string
  default     = ""

  validation {
    condition     = var.existing_quicksight_access_role_arn == "" || can(regex("^arn:aws:iam::[0-9]{12}:role/.+$", var.existing_quicksight_access_role_arn))
    error_message = "existing_quicksight_access_role_arn must be a valid IAM role ARN."
  }
}

variable "existing_kms_key_arn" {
  description = "ARN of the client-managed KMS key to use when enable_kms = true"
  type        = string
  default     = ""

  validation {
    condition     = var.existing_kms_key_arn == "" || can(regex("^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/[a-f0-9-]+$", var.existing_kms_key_arn))
    error_message = "existing_kms_key_arn must be a valid KMS key ARN (arn:aws:kms:region:account:key/key-id)"
  }
}

variable "existing_security_group_id" {
  description = "ID of the client-managed security group to use for Glue and SageMaker VPC placement"
  type        = string
  default     = ""

  validation {
    condition     = var.existing_security_group_id == "" || can(regex("^sg-[a-f0-9]+$", var.existing_security_group_id))
    error_message = "existing_security_group_id must be a valid security group ID (sg-...)"
  }
}
