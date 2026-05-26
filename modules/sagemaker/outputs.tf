output "code_repository_name" {
  description = "Name of the SageMaker code repository"
  value       = aws_sagemaker_code_repository.cdcu_scripts.code_repository_name
}

output "code_repository_arn" {
  description = "ARN of the SageMaker code repository"
  value       = aws_sagemaker_code_repository.cdcu_scripts.arn
}

output "studio_domain_id" {
  description = "SageMaker Studio domain ID"
  value       = var.enable_unified_studio ? aws_sagemaker_domain.studio[0].id : null
}

output "studio_domain_arn" {
  description = "SageMaker Studio domain ARN"
  value       = var.enable_unified_studio ? aws_sagemaker_domain.studio[0].arn : null
}

output "studio_user_profiles" {
  description = "Created SageMaker Studio user profile names"
  value       = [for profile in aws_sagemaker_user_profile.data_scientists : profile.user_profile_name]
}

output "studio_space_names" {
  description = "Created SageMaker Studio JupyterLab space names"
  value       = [for space in aws_sagemaker_space.jupyterlab : space.space_name]
}

output "notebook_instance_name" {
  description = "Created classic SageMaker Notebook Instance name"
  value       = var.enable_notebook_instance ? aws_sagemaker_notebook_instance.classic[0].name : null
}

output "notebook_instance_arn" {
  description = "Created classic SageMaker Notebook Instance ARN"
  value       = var.enable_notebook_instance ? aws_sagemaker_notebook_instance.classic[0].arn : null
}
