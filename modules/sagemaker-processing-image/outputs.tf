output "repository_name" {
  description = "Name of the SageMaker Processing ECR repository"
  value       = var.enabled ? aws_ecr_repository.processing[0].name : null
}

output "repository_url" {
  description = "URL of the SageMaker Processing ECR repository"
  value       = local.repository_url
}

output "image_uri" {
  description = "Full SageMaker Processing image URI including tag"
  value       = local.image_uri
}

output "build_enabled" {
  description = "Whether Terraform local-exec Docker build/push is enabled"
  value       = var.enabled && var.build_and_push
}
