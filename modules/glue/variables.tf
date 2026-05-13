variable "environment" {
  description = "Deployment environment (pre-prod, prod)"
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

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
