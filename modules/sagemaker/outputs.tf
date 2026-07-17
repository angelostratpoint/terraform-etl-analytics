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

output "studio_notebook_autosync_lifecycle_config_arn" {
  description = "ARN of the JupyterLab lifecycle config that syncs CDCU notebooks from S3 into the Studio workspace"
  value       = var.enable_unified_studio && var.enable_studio_notebook_autosync ? aws_sagemaker_studio_lifecycle_config.notebook_autosync[0].arn : null
}

output "studio_notebook_autosync_s3_uri" {
  description = "S3 URI synced into SageMaker JupyterLab by the CDCU notebook autosync lifecycle config"
  value       = local.studio_notebook_s3_uri
}

output "studio_notebook_autosync_local_path" {
  description = "Local JupyterLab path populated by the CDCU notebook autosync lifecycle config"
  value       = local.studio_notebook_local_path
}

output "notebook_instance_name" {
  description = "Created classic SageMaker Notebook Instance name"
  value       = var.enable_notebook_instance ? aws_sagemaker_notebook_instance.classic[0].name : null
}

output "notebook_instance_arn" {
  description = "Created classic SageMaker Notebook Instance ARN"
  value       = var.enable_notebook_instance ? aws_sagemaker_notebook_instance.classic[0].arn : null
}

output "matching_pipeline_name" {
  description = "Created CDCU SageMaker matching pipeline name"
  value       = var.enable_matching_pipeline ? aws_sagemaker_pipeline.matching[0].pipeline_name : null
}

output "matching_pipeline_arn" {
  description = "Created CDCU SageMaker matching pipeline ARN"
  value       = var.enable_matching_pipeline ? aws_sagemaker_pipeline.matching[0].arn : null
}

output "matching_pipeline_schedule_rule_name" {
  description = "EventBridge schedule rule name for the CDCU matching pipeline"
  value       = var.enable_matching_pipeline && var.matching_pipeline_schedule_enabled ? aws_cloudwatch_event_rule.matching_pipeline_schedule[0].name : null
}

output "matching_pipeline_glue_success_rule_name" {
  description = "EventBridge Glue-success rule name for the CDCU matching pipeline"
  value       = var.enable_matching_pipeline && var.matching_pipeline_glue_success_event_enabled ? aws_cloudwatch_event_rule.matching_pipeline_after_glue_success[0].name : null
}

output "matching_pipeline_processed_crawler_success_rule_name" {
  description = "EventBridge rule name that starts the processed matching crawler after the SageMaker matching pipeline succeeds"
  value       = var.enable_matching_pipeline && var.matching_pipeline_processed_crawler_event_enabled ? aws_cloudwatch_event_rule.processed_matching_crawler_after_pipeline_success[0].name : null
}
