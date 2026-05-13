variable "environment" {
  description = "Deployment environment (pre-prod, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID managed by BPI MS where the Glue security group will be created"
  type        = string
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
