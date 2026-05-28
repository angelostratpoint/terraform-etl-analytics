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

variable "microsite_jdbc_url" {
  description = "Optional fallback JDBC URL for the Microsite MySQL source database when merged_jdbc_url is not set."
  type        = string
  default     = ""
}

variable "legacy_jdbc_url" {
  description = "Optional fallback JDBC URL for the Legacy MySQL source database when merged_jdbc_url is not set."
  type        = string
  default     = ""
}

variable "merged_jdbc_url" {
  description = "Optional merged MySQL JDBC URL used by both Microsite and Legacy flows when BPI-MS provides one shared source database."
  type        = string
  default     = ""

  validation {
    condition     = var.merged_jdbc_url == "" || (startswith(var.merged_jdbc_url, "jdbc:mysql://") && !can(regex("localhost", lower(var.merged_jdbc_url))))
    error_message = "merged_jdbc_url must be blank or a non-local MySQL JDBC URL from BPI-MS."
  }
}

variable "merged_mysql_secret_name" {
  description = "Optional Secrets Manager secret name for the merged MySQL source database. When set, both source Glue connections use this secret."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
