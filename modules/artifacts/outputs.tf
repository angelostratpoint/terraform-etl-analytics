output "glue_script_count" {
  description = "Number of Glue scripts uploaded"
  value       = length(aws_s3_object.glue_scripts)
}

output "sagemaker_script_count" {
  description = "Number of SageMaker scripts uploaded"
  value       = length(aws_s3_object.sagemaker_scripts)
}

output "sql_file_count" {
  description = "Number of SQL files uploaded"
  value       = length(aws_s3_object.sql_files)
}

output "matching_script_count" {
  description = "Number of matching scripts uploaded"
  value       = length(aws_s3_object.matching_scripts)
}

output "glue_script_s3_prefix" {
  description = "S3 prefix where Glue scripts are stored"
  value       = "${var.environment}/glue-scripts/"
}

output "sagemaker_script_s3_prefix" {
  description = "S3 prefix where SageMaker scripts are stored"
  value       = "${var.environment}/sagemaker-scripts/"
}

output "matching_script_s3_prefix" {
  description = "S3 prefix where matching scripts are stored"
  value       = "${var.environment}/matching-scripts/"
}
