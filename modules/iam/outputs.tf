output "glue_execution_role_arn" {
  description = "ARN of the ST-CDCU Glue execution role"
  value       = aws_iam_role.glue_execution.arn
}

output "glue_execution_role_name" {
  description = "Name of the ST-CDCU Glue execution role"
  value       = aws_iam_role.glue_execution.name
}

output "sagemaker_execution_role_arn" {
  description = "ARN of the ST-CDCU SageMaker execution role"
  value       = aws_iam_role.sagemaker_execution.arn
}

output "sagemaker_execution_role_name" {
  description = "Name of the ST-CDCU SageMaker execution role"
  value       = aws_iam_role.sagemaker_execution.name
}

output "athena_query_role_arn" {
  description = "ARN of the ST-CDCU Athena query role"
  value       = aws_iam_role.athena_query.arn
}

output "athena_query_role_name" {
  description = "Name of the ST-CDCU Athena query role"
  value       = aws_iam_role.athena_query.name
}

output "eventbridge_glue_role_arn" {
  description = "ARN of the ST-CDCU EventBridge Glue invocation role"
  value       = aws_iam_role.eventbridge_glue.arn
}

output "eventbridge_glue_role_name" {
  description = "Name of the ST-CDCU EventBridge Glue invocation role"
  value       = aws_iam_role.eventbridge_glue.name
}

output "cloud_engineering_group_name" {
  description = "Name of the ST-CDCU Cloud Engineering IAM group"
  value       = aws_iam_group.cloud_engineering.name
}

output "data_engineering_group_name" {
  description = "Name of the ST-CDCU Data Engineering IAM group"
  value       = aws_iam_group.data_engineering.name
}

output "qa_group_name" {
  description = "Name of the ST-CDCU QA IAM group"
  value       = aws_iam_group.qa.name
}
