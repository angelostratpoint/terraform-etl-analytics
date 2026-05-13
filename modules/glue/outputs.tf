output "catalog_database_name" {
  description = "Name of the Glue Data Catalog database"
  value       = aws_glue_catalog_database.cdcu.name
}

output "microsite_raw_job_name" {
  description = "Name of the Microsite raw extraction Glue job"
  value       = aws_glue_job.microsite_raw_extraction.name
}

output "legacy_raw_job_name" {
  description = "Name of the Legacy raw extraction Glue job"
  value       = aws_glue_job.legacy_raw_extraction.name
}

output "microsite_standardization_job_name" {
  description = "Name of the Microsite standardization Glue job"
  value       = aws_glue_job.microsite_standardization.name
}

output "legacy_standardization_job_name" {
  description = "Name of the Legacy standardization Glue job"
  value       = aws_glue_job.legacy_standardization.name
}

output "glue_job_names" {
  description = "List of all Glue job names for CloudWatch alarm configuration"
  value = [
    aws_glue_job.microsite_raw_extraction.name,
    aws_glue_job.legacy_raw_extraction.name,
    aws_glue_job.microsite_standardization.name,
    aws_glue_job.legacy_standardization.name,
  ]
}

output "crawler_names" {
  description = "List of all Glue crawler names"
  value = [
    aws_glue_crawler.microsite_raw.name,
    aws_glue_crawler.legacy_raw.name,
    aws_glue_crawler.microsite_standardized.name,
    aws_glue_crawler.legacy_standardized.name,
    aws_glue_crawler.processed_matching.name,
    aws_glue_crawler.errors.name,
  ]
}

output "microsite_mysql_connection_name" {
  description = "Name of the Microsite MySQL Glue connection"
  value       = aws_glue_connection.microsite_mysql.name
}

output "legacy_mysql_connection_name" {
  description = "Name of the Legacy MySQL Glue connection"
  value       = aws_glue_connection.legacy_mysql.name
}
