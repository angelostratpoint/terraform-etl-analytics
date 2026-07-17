output "catalog_database_name" {
  description = "Name of the Glue Data Catalog database"
  value       = aws_glue_catalog_database.cdcu.name
}

output "merged_raw_job_name" {
  description = "Name of the merged source raw extraction Glue job"
  value       = aws_glue_job.merged_raw_extraction.name
}

output "merged_standardization_job_name" {
  description = "Name of the merged source standardization Glue job"
  value       = aws_glue_job.merged_standardization.name
}

output "glue_job_names" {
  description = "List of all Glue job names for CloudWatch alarm configuration"
  value = [
    aws_glue_job.merged_raw_extraction.name,
    aws_glue_job.merged_standardization.name,
  ]
}

output "crawler_names" {
  description = "List of all Glue crawler names"
  value = [
    aws_glue_crawler.merged_raw.name,
    aws_glue_crawler.merged_standardized.name,
    aws_glue_crawler.processed_matching.name,
    aws_glue_crawler.errors.name,
  ]
}

output "processed_matching_crawler_name" {
  description = "Name of the Glue crawler that refreshes SageMaker processed matching outputs"
  value       = aws_glue_crawler.processed_matching.name
}

output "merged_mysql_connection_name" {
  description = "Name of the merged MySQL Glue connection"
  value       = aws_glue_connection.merged_mysql.name
}

output "workflow_name" {
  description = "Name of the CDCU Glue workflow when workflow orchestration is enabled"
  value       = var.enable_workflow_orchestration ? aws_glue_workflow.cdcu[0].name : null
}

output "workflow_arn" {
  description = "ARN of the CDCU Glue workflow when workflow orchestration is enabled"
  value       = var.enable_workflow_orchestration ? aws_glue_workflow.cdcu[0].arn : null
}

output "workflow_trigger_names" {
  description = "Names of the CDCU Glue workflow triggers when workflow orchestration is enabled"
  value = var.enable_workflow_orchestration ? concat(
    aws_glue_trigger.start_raw_extraction[*].name,
    aws_glue_trigger.scheduled_raw_extraction[*].name,
    aws_glue_trigger.after_raw_extraction[*].name,
    aws_glue_trigger.after_standardization[*].name,
    aws_glue_trigger.processed_matching_after_pipeline_success_event[*].name,
  ) : []
}
