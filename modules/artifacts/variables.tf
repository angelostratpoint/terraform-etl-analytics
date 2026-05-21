variable "environment" {
  description = "Deployment environment (sit, uat, prod)"
  type        = string
}

variable "scripts_bucket" {
  description = "Name of the S3 bucket where artifacts will be uploaded"
  type        = string
}

variable "artifacts_base_path" {
  description = "Base path to the artifacts directory in the repository"
  type        = string
  default     = "../../artifacts"
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
