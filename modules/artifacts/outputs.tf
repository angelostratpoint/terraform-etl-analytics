output "glue_extraction_script_count" {
  description = "Number of Glue extraction scripts uploaded"
  value       = length(aws_s3_object.glue_extraction_scripts)
}

output "glue_standardization_script_count" {
  description = "Number of Glue standardization scripts uploaded"
  value       = length(aws_s3_object.glue_standardization_scripts)
}

output "sagemaker_matching_script_count" {
  description = "Number of SageMaker matching scripts uploaded"
  value       = length(aws_s3_object.sagemaker_matching_scripts)
}

output "sagemaker_processing_script_count" {
  description = "Number of SageMaker processing scripts uploaded"
  value       = length(aws_s3_object.sagemaker_processing_scripts)
}

output "sql_file_count" {
  description = "Number of SQL files uploaded"
  value       = length(aws_s3_object.sql_files)
}

output "glue_extraction_script_s3_prefix" {
  description = "S3 prefix where Glue extraction scripts are stored"
  value       = "${var.environment}/glue-scripts/extraction/"
}

output "glue_standardization_script_s3_prefix" {
  description = "S3 prefix where Glue standardization scripts are stored"
  value       = "${var.environment}/glue-scripts/standardization/"
}

output "sagemaker_matching_script_s3_prefix" {
  description = "S3 prefix where SageMaker matching scripts are stored"
  value       = "${var.environment}/sagemaker-scripts/matching/"
}

output "sagemaker_processing_script_s3_prefix" {
  description = "S3 prefix where SageMaker processing scripts are stored"
  value       = "${var.environment}/sagemaker-scripts/processing/"
}
