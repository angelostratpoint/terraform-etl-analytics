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

variable "eventbridge_role_arn" {
  description = "IAM role ARN assumed by EventBridge to start the CDCU SageMaker Pipeline"
  type        = string
  default     = ""
}

variable "data_lake_bucket_name" {
  description = "CDCU data lake bucket name used by the matching pipeline inputs and outputs"
  type        = string
  default     = ""
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

variable "enable_studio_notebook_autosync" {
  description = "Whether to attach a JupyterLab lifecycle config that syncs repo-managed notebooks from S3 into the Studio workspace on app start"
  type        = bool
  default     = false
}

variable "studio_notebook_s3_uri" {
  description = "Optional S3 URI containing notebooks to sync into SageMaker JupyterLab. Leave empty to use s3://{data_lake_bucket_name}/{environment}/sagemaker-notebooks/"
  type        = string
  default     = ""
}

variable "studio_notebook_local_path" {
  description = "Local JupyterLab path where notebooks are synced by the lifecycle config"
  type        = string
  default     = "$HOME/cdcu-managed/notebooks/"
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

variable "enable_matching_pipeline" {
  description = "Whether to create the CDCU SageMaker matching pipeline for UAT/PROD automation"
  type        = bool
  default     = false
}

variable "matching_pipeline_schedule_enabled" {
  description = "Whether to create an EventBridge schedule that starts the matching pipeline"
  type        = bool
  default     = false
}

variable "matching_pipeline_glue_success_event_enabled" {
  description = "Whether to create an EventBridge rule that starts the matching pipeline when the upstream Glue job succeeds"
  type        = bool
  default     = false
}

variable "matching_pipeline_trigger_glue_job_name" {
  description = "Glue job name whose SUCCEEDED event starts the matching pipeline when glue-success triggering is enabled"
  type        = string
  default     = ""
}

variable "matching_pipeline_processed_crawler_name" {
  description = "Glue crawler name started by the SageMaker processing script after matching outputs are written"
  type        = string
  default     = ""
}

variable "matching_pipeline_schedule_expression" {
  description = "EventBridge schedule expression for the CDCU SageMaker matching pipeline"
  type        = string
  default     = "rate(1 day)"
}

variable "matching_pipeline_processing_image_uri" {
  description = "Container image URI used by the SageMaker processing step"
  type        = string
  default     = ""
}

variable "matching_pipeline_processing_script_name" {
  description = "Processing script filename uploaded under the SageMaker processing artifact prefix"
  type        = string
  default     = "matching_prod.py"
}

variable "matching_pipeline_runner_script_name" {
  description = "Runner script filename that prepares dependencies before executing the matching script"
  type        = string
  default     = "run_matching_prod.py"
}

variable "matching_pipeline_wheelhouse_s3_uri" {
  description = "S3 URI containing Python wheelhouse dependencies for the matching processing job"
  type        = string
  default     = ""
}

variable "matching_pipeline_instance_type" {
  description = "Instance type for the SageMaker matching processing step"
  type        = string
  default     = "ml.m5.2xlarge"
}

variable "matching_pipeline_instance_count" {
  description = "Instance count for the SageMaker matching processing step"
  type        = number
  default     = 1
}

variable "matching_pipeline_volume_size_gb" {
  description = "EBS volume size in GB for the SageMaker matching processing step"
  type        = number
  default     = 30
}

variable "matching_pipeline_max_runtime_seconds" {
  description = "Maximum runtime in seconds for the SageMaker matching processing step"
  type        = number
  default     = 14400
}

variable "matching_pipeline_standardized_s3_uri" {
  description = "Optional standardized input S3 URI. Leave empty to use s3://{data_lake_bucket_name}/standardized/merged/"
  type        = string
  default     = ""
}

variable "matching_pipeline_output_s3_uri" {
  description = "Optional matching output S3 URI. Leave empty to use s3://{data_lake_bucket_name}/processed/matching/"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
