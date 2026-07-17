variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "sit"

  validation {
    condition     = contains(["sit", "uat", "prod"], var.environment)
    error_message = "environment must be one of: sit, uat, prod"
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

# Reserved for future use — SSO trust policy pending BPI MS approval. Not currently passed to any module.
variable "sso_principal_arns" {
  description = "SSO principal ARNs allowed to assume human-facing IAM roles"
  type        = list(string)
  default     = []
}

# Reserved for future use — OIDC trust policy pending BPI MS approval. Not currently passed to any module.
variable "github_org" {
  description = "GitHub organization name for OIDC trust"
  type        = string
  default     = ""
}

# Reserved for future use — OIDC trust policy pending BPI MS approval. Not currently passed to any module.
variable "github_repo" {
  description = "GitHub repository name for OIDC trust"
  type        = string
  default     = ""
}

variable "enable_kms" {
  description = "Whether to enable KMS encryption"
  type        = bool
  default     = false
}

variable "data_lake_bucket_name" {
  description = "Explicit CDCU data lake bucket name approved by BPI-MS. Leave empty to use the module default."
  type        = string
  default     = ""
}

variable "athena_results_bucket_name" {
  description = "Explicit Athena results bucket name approved by BPI-MS. Leave empty to use the module default."
  type        = string
  default     = ""
}

# Reserved for future use — CloudWatch alarms pending BPI MS approval. Not currently passed to any module.
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

variable "merged_jdbc_url" {
  description = "Merged BPI-MS MySQL JDBC URL used by the CDCU Glue source connection."
  type        = string

  validation {
    condition     = startswith(var.merged_jdbc_url, "jdbc:mysql://") && !can(regex("localhost", lower(var.merged_jdbc_url)))
    error_message = "merged_jdbc_url must be a non-local MySQL JDBC URL from BPI MS."
  }
}

variable "merged_mysql_secret_name" {
  description = "Secrets Manager secret name for the merged BPI-MS MySQL source database."
  type        = string

  validation {
    condition     = var.merged_mysql_secret_name != ""
    error_message = "merged_mysql_secret_name is required."
  }
}

variable "mysql_jdbc_driver_class_name" {
  description = "Optional MySQL JDBC driver class name for custom driver scenarios. Leave blank to use the Glue-provided MySQL driver and support Glue connection tests."
  type        = string
  default     = ""
}

variable "mysql_jdbc_driver_jar_uri" {
  description = "Optional S3 URI for a custom MySQL JDBC driver JAR. Leave blank to use the Glue-provided driver."
  type        = string
  default     = ""

  validation {
    condition     = var.mysql_jdbc_driver_jar_uri == "" || startswith(var.mysql_jdbc_driver_jar_uri, "s3://")
    error_message = "mysql_jdbc_driver_jar_uri must be blank or an s3:// URI."
  }
}

variable "enable_glue_workflow_orchestration" {
  description = "Whether to provision the CDCU Glue workflow and triggers for raw extraction, standardization, and crawler refresh"
  type        = bool
  default     = false
}

variable "enable_glue_workflow_schedule" {
  description = "Whether to provision a scheduled Glue trigger that starts the CDCU Glue workflow"
  type        = bool
  default     = false
}

variable "glue_workflow_schedule_expression" {
  description = "Glue cron/rate expression for the scheduled workflow trigger. AWS evaluates cron schedules in UTC."
  type        = string
  default     = "cron(0 18 * * ? *)"
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
  default     = ["data-engineer-01"]
}

variable "sagemaker_studio_space_instance_type" {
  description = "Instance type for the JupyterLab space in Unified Studio"
  type        = string
  default     = "ml.m5.2xlarge"
}

variable "sagemaker_studio_space_volume_size_gb" {
  description = "EBS volume size in GB for the JupyterLab space"
  type        = number
  default     = 5
}

variable "enable_studio_notebook_autosync" {
  description = "Whether to sync repo-managed notebooks from S3 into SageMaker JupyterLab on app start"
  type        = bool
  default     = false
}

variable "studio_notebook_s3_uri" {
  description = "Optional S3 URI containing notebooks to sync into SageMaker JupyterLab"
  type        = string
  default     = ""
}

variable "studio_notebook_local_path" {
  description = "Local JupyterLab path where notebooks are synced by the lifecycle config"
  type        = string
  default     = "$HOME/cdcu-managed/notebooks/"
}

variable "sagemaker_studio_app_network_access_type" {
  description = "Network access mode for SageMaker Studio apps"
  type        = string
  default     = "VpcOnly"
}

variable "enable_sagemaker_notebook_instance" {
  description = "Whether to provision a classic SageMaker Notebook Instance for CDCU"
  type        = bool
  default     = false
}

variable "sagemaker_notebook_instance_name" {
  description = "Optional explicit classic SageMaker Notebook Instance name"
  type        = string
  default     = ""
}

variable "sagemaker_notebook_instance_type" {
  description = "Instance type for the classic SageMaker Notebook Instance"
  type        = string
  default     = "ml.m5.2xlarge"
}

variable "sagemaker_notebook_volume_size_gb" {
  description = "EBS volume size in GB for the classic SageMaker Notebook Instance"
  type        = number
  default     = 5
}

variable "sagemaker_notebook_direct_internet_access" {
  description = "Direct internet access setting for the classic SageMaker Notebook Instance"
  type        = string
  default     = "Disabled"
}

variable "sagemaker_notebook_root_access" {
  description = "Root access setting for the classic SageMaker Notebook Instance"
  type        = string
  default     = "Disabled"
}

variable "enable_sagemaker_matching_pipeline" {
  description = "Whether to provision the CDCU SageMaker matching pipeline"
  type        = bool
  default     = false
}

variable "enable_sagemaker_matching_pipeline_schedule" {
  description = "Whether to create an EventBridge schedule for the CDCU SageMaker matching pipeline"
  type        = bool
  default     = false
}

variable "enable_sagemaker_matching_pipeline_glue_success_event" {
  description = "Whether to create an EventBridge rule that starts the CDCU SageMaker matching pipeline when the standardization Glue job succeeds"
  type        = bool
  default     = false
}

variable "sagemaker_matching_pipeline_schedule_expression" {
  description = "EventBridge schedule expression for the CDCU SageMaker matching pipeline"
  type        = string
  default     = "rate(1 day)"
}

variable "sagemaker_matching_pipeline_processing_image_uri" {
  description = "Container image URI used by the CDCU SageMaker matching pipeline processing step"
  type        = string
  default     = ""
}

variable "enable_sagemaker_processing_image_repository" {
  description = "Whether to create an ECR repository for the CDCU SageMaker Processing image"
  type        = bool
  default     = false
}

variable "enable_sagemaker_processing_image_build" {
  description = "Whether Terraform should build and push the CDCU SageMaker Processing Docker image using local Docker and AWS CLI"
  type        = bool
  default     = false
}

variable "sagemaker_processing_image_repository_name" {
  description = "Optional ECR repository name for the CDCU SageMaker Processing image. Leave empty to use cdcu-{environment}-sagemaker-processing."
  type        = string
  default     = ""
}

variable "sagemaker_processing_image_tag" {
  description = "Docker image tag for the CDCU SageMaker Processing image"
  type        = string
  default     = "py312"
}

variable "sagemaker_processing_image_force_delete" {
  description = "Whether terraform destroy should delete the ECR repository even when it contains images"
  type        = bool
  default     = true
}

variable "sagemaker_matching_pipeline_processing_script_name" {
  description = "Processing script filename uploaded under the SageMaker processing artifact prefix"
  type        = string
  default     = "matching_prod.py"
}

variable "sagemaker_matching_pipeline_runner_script_name" {
  description = "Runner script filename that prepares dependencies before executing the matching script"
  type        = string
  default     = "run_matching_prod.py"
}

variable "sagemaker_matching_pipeline_wheelhouse_s3_uri" {
  description = "Optional S3 URI for Python wheelhouse dependencies used by the matching processing job"
  type        = string
  default     = ""
}

variable "sagemaker_matching_pipeline_instance_type" {
  description = "Instance type for the CDCU SageMaker matching processing step"
  type        = string
  default     = "ml.m5.2xlarge"
}

variable "sagemaker_matching_pipeline_instance_count" {
  description = "Instance count for the CDCU SageMaker matching processing step"
  type        = number
  default     = 1
}

variable "sagemaker_matching_pipeline_volume_size_gb" {
  description = "EBS volume size in GB for the CDCU SageMaker matching processing step"
  type        = number
  default     = 30
}

variable "sagemaker_matching_pipeline_max_runtime_seconds" {
  description = "Maximum runtime in seconds for the CDCU SageMaker matching processing step"
  type        = number
  default     = 14400
}

variable "sagemaker_matching_pipeline_standardized_s3_uri" {
  description = "Optional standardized input S3 URI for the matching pipeline"
  type        = string
  default     = ""
}

variable "sagemaker_matching_pipeline_output_s3_uri" {
  description = "Optional matching output S3 URI for the matching pipeline"
  type        = string
  default     = ""
}

# Disabled by default. Validate the target account's QuickSight access model before enabling.
# Enable only after the target account has an approved QuickSight subscription and owner principal.
variable "enable_quicksight" {
  description = "Whether to provision QuickSight data source and dataset resources"
  type        = bool
  default     = false
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
  description = "Name of the DynamoDB table used for Terraform state locking; must match the backend DynamoDB table unless BPI MS approves a separate IAM table."
  type        = string
  default     = "cdcu-terraform-locks-sit"
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
