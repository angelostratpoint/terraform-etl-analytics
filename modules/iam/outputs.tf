output "terraform_deployment_role_arn" {
  description = "ARN of the Terraform deployment role"
  value       = aws_iam_role.cdcu_terraform_deployment.arn
}

output "glue_execution_role_arn" {
  description = "ARN of the Glue execution role"
  value       = aws_iam_role.cdcu_glue_execution.arn
}

output "glue_execution_role_name" {
  description = "Name of the Glue execution role"
  value       = aws_iam_role.cdcu_glue_execution.name
}

output "sagemaker_execution_role_arn" {
  description = "ARN of the SageMaker execution role"
  value       = aws_iam_role.cdcu_sagemaker_execution.arn
}

output "sagemaker_execution_role_name" {
  description = "Name of the SageMaker execution role"
  value       = aws_iam_role.cdcu_sagemaker_execution.name
}

output "athena_query_role_arn" {
  description = "ARN of the Athena query role"
  value       = aws_iam_role.cdcu_athena_query.arn
}

output "quicksight_access_role_arn" {
  description = "ARN of the QuickSight access role"
  value       = aws_iam_role.cdcu_quicksight_access.arn
}

output "developer_role_arn" {
  description = "ARN of the developer role"
  value       = aws_iam_role.cdcu_developer.arn
}

output "readonly_role_arn" {
  description = "ARN of the read-only role"
  value       = aws_iam_role.cdcu_readonly.arn
}

output "qa_role_arn" {
  description = "ARN of the QA tester role"
  value       = aws_iam_role.cdcu_qa.arn
}

output "business_review_role_arn" {
  description = "ARN of the business reviewer role"
  value       = aws_iam_role.cdcu_business_review.arn
}

output "all_role_arns" {
  description = "Map of all CDCU IAM role ARNs"
  value = {
    terraform_deployment = aws_iam_role.cdcu_terraform_deployment.arn
    glue_execution       = aws_iam_role.cdcu_glue_execution.arn
    sagemaker_execution  = aws_iam_role.cdcu_sagemaker_execution.arn
    athena_query         = aws_iam_role.cdcu_athena_query.arn
    quicksight_access    = aws_iam_role.cdcu_quicksight_access.arn
    developer            = aws_iam_role.cdcu_developer.arn
    readonly             = aws_iam_role.cdcu_readonly.arn
    qa                   = aws_iam_role.cdcu_qa.arn
    business_review      = aws_iam_role.cdcu_business_review.arn
  }
}
