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

output "external_role_arns" {
  description = "Client-managed IAM role ARNs consumed by this Terraform deployment"
  value = {
    glue_execution      = module.iam.glue_execution_role_arn
    sagemaker_execution = module.iam.sagemaker_execution_role_arn
    athena_query        = module.iam.athena_query_role_arn
    quicksight_access   = var.existing_quicksight_access_role_arn
  }
}

output "glue_execution_role_arn" {
  description = "ST-CDCU Glue execution role ARN"
  value       = module.iam.glue_execution_role_arn
}

output "sagemaker_execution_role_arn" {
  description = "ST-CDCU SageMaker execution role ARN"
  value       = module.iam.sagemaker_execution_role_arn
}

output "iam_groups" {
  description = "ST-CDCU IAM group names"
  value = {
    cloud_engineering = module.iam.cloud_engineering_group_name
    data_engineering  = module.iam.data_engineering_group_name
    qa                = module.iam.qa_group_name
  }
}

output "kms_key_arn" {
  description = "Client-managed KMS key ARN used when KMS encryption is enabled"
  value       = local.kms_key_arn
}

output "glue_security_group_id" {
  description = "Client-managed Glue security group ID to whitelist in the RDS inbound rules"
  value       = var.existing_security_group_id
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
    glue_extraction      = module.artifacts.glue_extraction_script_count
    glue_standardization = module.artifacts.glue_standardization_script_count
    sagemaker_matching   = module.artifacts.sagemaker_matching_script_count
    sagemaker_processing = module.artifacts.sagemaker_processing_script_count
    sql                  = module.artifacts.sql_file_count
  }
}
