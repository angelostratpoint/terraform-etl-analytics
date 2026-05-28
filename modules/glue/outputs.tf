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

output "merged_mysql_connection_name" {
  description = "Name of the merged MySQL Glue connection"
  value       = aws_glue_connection.merged_mysql.name
}
