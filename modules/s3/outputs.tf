output "data_lake_bucket_name" {
  description = "Name of the CDCU data lake S3 bucket"
  value       = aws_s3_bucket.cdcu_data_lake.id
}

output "data_lake_bucket_arn" {
  description = "ARN of the CDCU data lake S3 bucket"
  value       = aws_s3_bucket.cdcu_data_lake.arn
}

output "athena_results_bucket_name" {
  description = "Name of the Athena query results S3 bucket"
  value       = aws_s3_bucket.cdcu_athena_results.id
}

output "athena_results_bucket_arn" {
  description = "ARN of the Athena query results S3 bucket"
  value       = aws_s3_bucket.cdcu_athena_results.arn
}
