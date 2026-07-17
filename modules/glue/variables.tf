variable "environment" {
  description = "Deployment environment (sit, uat, prod)"
  type        = string
}

variable "glue_execution_role_arn" {
  description = "ARN of the IAM role for Glue job and crawler execution"
  type        = string
}

variable "data_lake_bucket" {
  description = "Name of the CDCU data lake S3 bucket"
  type        = string
}

variable "scripts_bucket" {
  description = "Name of the S3 bucket containing Glue ETL scripts"
  type        = string
}

variable "glue_security_group_ids" {
  description = "List of security group IDs for Glue connections"
  type        = list(string)
  default     = []
}

variable "subnet_id" {
  description = "Subnet ID for Glue connection network placement"
  type        = string
  default     = ""
}

variable "availability_zone" {
  description = "Availability zone for Glue connection"
  type        = string
  default     = "ap-southeast-1a"
}

variable "glue_worker_count" {
  description = "Number of Glue workers for ETL jobs"
  type        = number
  default     = 2
}

variable "glue_worker_type" {
  description = "Glue worker type (G.1X, G.2X)"
  type        = string
  default     = "G.1X"
}

variable "merged_jdbc_url" {
  description = "Merged BPI-MS MySQL JDBC URL used by the CDCU Glue source connection."
  type        = string

  validation {
    condition = (
      startswith(var.merged_jdbc_url, "jdbc:mysql://")
      && !can(regex("localhost", lower(var.merged_jdbc_url)))
      && !can(regex("example\\.com", lower(var.merged_jdbc_url)))
      && !can(regex("<.*>", var.merged_jdbc_url))
    )
    error_message = "merged_jdbc_url must be the approved non-placeholder BPI-MS MySQL JDBC URL."
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

variable "enable_workflow_orchestration" {
  description = "Whether to provision the CDCU Glue workflow and triggers for raw extraction, standardization, and crawler refresh"
  type        = bool
  default     = false
}

variable "enable_workflow_schedule" {
  description = "Whether to provision a scheduled Glue trigger that starts the CDCU Glue workflow"
  type        = bool
  default     = false
}

variable "workflow_schedule_expression" {
  description = "Glue cron/rate expression for the scheduled workflow trigger. AWS evaluates cron schedules in UTC."
  type        = string
  default     = "cron(0 18 * * ? *)"
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
