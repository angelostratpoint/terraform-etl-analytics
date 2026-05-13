output "data_lake_bucket_name" {
  description = "CDCU data lake S3 bucket name"
  value       = module.s3.data_lake_bucket_name
}

output "athena_results_bucket_name" {
  description = "Athena results S3 bucket name"
  value       = module.s3.athena_results_bucket_name
}

output "athena_workgroup_name" {
  description = "Athena workgroup name"
  value       = module.athena.workgroup_name
}

output "glue_catalog_database" {
  description = "Glue Data Catalog database name"
  value       = module.glue.catalog_database_name
}

output "glue_crawler_names" {
  description = "Glue crawler names"
  value       = module.glue.crawler_names
}

output "iam_role_arns" {
  description = "All CDCU IAM role ARNs"
  value       = module.iam.all_role_arns
}

output "cloudwatch_dashboard" {
  description = "CloudWatch operations dashboard name"
  value       = module.cloudwatch.dashboard_name
}

output "sagemaker_studio_domain_id" {
  description = "SageMaker Studio domain ID"
  value       = module.sagemaker.studio_domain_id
}

output "sagemaker_notebook_instance_names" {
  description = "SageMaker notebook instance names"
  value       = module.sagemaker.notebook_instance_names
}

output "quicksight_data_source_arn" {
  description = "QuickSight Athena data source ARN"
  value       = module.quicksight.data_source_arn
}

output "quicksight_data_set_arn" {
  description = "QuickSight matching results dataset ARN"
  value       = module.quicksight.data_set_arn
}

output "quicksight_group_arns" {
  description = "QuickSight CDCU group ARNs"
  value = {
    admins  = module.quicksight.admin_group_arn
    authors = module.quicksight.author_group_arn
    readers = module.quicksight.reader_group_arn
  }
}

output "artifacts_uploaded" {
  description = "Count of artifacts uploaded per category"
  value = {
    glue      = module.artifacts.glue_script_count
    sagemaker = module.artifacts.sagemaker_script_count
    sql       = module.artifacts.sql_file_count
    matching  = module.artifacts.matching_script_count
  }
}
