variable "environment" {
  description = "Deployment environment (sit, uat, prod)"
  type        = string
}

variable "git_repository_url" {
  description = "HTTPS URL of the GitHub repository containing SageMaker scripts"
  type        = string
}

variable "git_branch" {
  description = "Git branch to track for the code repository"
  type        = string
  default     = "main"
}

variable "git_secret_arn" {
  description = "ARN of the Secrets Manager secret containing GitHub credentials for the code repository"
  type        = string
  default     = ""
}

variable "enable_unified_studio" {
  description = "Whether to provision a SageMaker Studio domain for BPI-MS data engineers"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "VPC ID for SageMaker Studio and notebook network placement"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for SageMaker Studio domain and notebook placement"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups attached to SageMaker Studio apps"
  type        = list(string)
  default     = []
}

variable "execution_role_arn" {
  description = "SageMaker execution role ARN used by Studio, JupyterLab spaces, processing, and training jobs"
  type        = string
}

variable "studio_user_profile_names" {
  description = "SageMaker Studio user profiles to create for data scientists"
  type        = list(string)
  default     = []
}

variable "studio_app_network_access_type" {
  description = "Network access mode for SageMaker Studio apps"
  type        = string
  default     = "VpcOnly"

  validation {
    condition     = contains(["PublicInternetOnly", "VpcOnly"], var.studio_app_network_access_type)
    error_message = "studio_app_network_access_type must be PublicInternetOnly or VpcOnly."
  }
}

variable "studio_space_instance_type" {
  description = "Instance type for the JupyterLab space in Unified Studio"
  type        = string
  default     = "ml.t3.medium"
}

variable "studio_space_volume_size_gb" {
  description = "EBS volume size in GB for the JupyterLab space"
  type        = number
  default     = 5
}

variable "enable_notebook_instance" {
  description = "Whether to provision a classic SageMaker Notebook Instance in addition to Studio"
  type        = bool
  default     = false
}

variable "notebook_instance_name" {
  description = "Optional explicit SageMaker Notebook Instance name. Leave empty to use cdcu-{environment}-notebook."
  type        = string
  default     = ""
}

variable "notebook_instance_type" {
  description = "Instance type for the classic SageMaker Notebook Instance"
  type        = string
  default     = "ml.t3.medium"
}

variable "notebook_volume_size_gb" {
  description = "EBS volume size in GB for the classic SageMaker Notebook Instance"
  type        = number
  default     = 5
}

variable "notebook_direct_internet_access" {
  description = "Direct internet access setting for the classic SageMaker Notebook Instance"
  type        = string
  default     = "Disabled"

  validation {
    condition     = contains(["Enabled", "Disabled"], var.notebook_direct_internet_access)
    error_message = "notebook_direct_internet_access must be Enabled or Disabled."
  }
}

variable "notebook_root_access" {
  description = "Root access setting for the classic SageMaker Notebook Instance"
  type        = string
  default     = "Disabled"

  validation {
    condition     = contains(["Enabled", "Disabled"], var.notebook_root_access)
    error_message = "notebook_root_access must be Enabled or Disabled."
  }
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
