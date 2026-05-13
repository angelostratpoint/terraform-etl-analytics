variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "enabled" {
  description = "Whether to provision QuickSight data source and dataset resources"
  type        = bool
  default     = true
}

variable "admin_principal_arn" {
  description = "Existing QuickSight user or group ARN that receives ownership permissions. When empty, the module-created admin group is used."
  type        = string
  default     = ""
}

variable "namespace" {
  description = "QuickSight namespace for CDCU groups"
  type        = string
  default     = "default"
}

variable "athena_workgroup_name" {
  description = "Athena workgroup used by QuickSight"
  type        = string
}

variable "glue_catalog_database" {
  description = "Glue Data Catalog database exposed through Athena"
  type        = string
}

variable "matching_table_name" {
  description = "Athena table containing final matching output"
  type        = string
  default     = "processed_matching"
}

variable "dataset_import_mode" {
  description = "QuickSight import mode"
  type        = string
  default     = "SPICE"

  validation {
    condition     = contains(["SPICE", "DIRECT_QUERY"], var.dataset_import_mode)
    error_message = "dataset_import_mode must be SPICE or DIRECT_QUERY."
  }
}

variable "spice_capacity_gb" {
  description = "Documented SPICE capacity requirement from the AWS Pricing Calculator"
  type        = number
  default     = 10
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
