variable "enabled" {
  description = "Whether to create the SageMaker Processing ECR repository"
  type        = bool
  default     = false
}

variable "build_and_push" {
  description = "Whether Terraform should build and push the Docker image using local Docker and AWS CLI"
  type        = bool
  default     = false
}

variable "repository_name" {
  description = "Name of the ECR repository for the CDCU SageMaker Processing image"
  type        = string
}

variable "image_tag" {
  description = "Tag for the SageMaker Processing image"
  type        = string
  default     = "py312"
}

variable "docker_context_path" {
  description = "Local Docker build context path for the SageMaker Processing image"
  type        = string
}

variable "force_delete" {
  description = "Whether ECR repository deletion should delete contained images during terraform destroy"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
