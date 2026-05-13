output "glue_log_group_name" {
  description = "Name of the Glue CloudWatch log group"
  value       = aws_cloudwatch_log_group.glue.name
}

output "sagemaker_log_group_name" {
  description = "Name of the SageMaker CloudWatch log group"
  value       = aws_cloudwatch_log_group.sagemaker.name
}

output "athena_log_group_name" {
  description = "Name of the Athena CloudWatch log group"
  value       = aws_cloudwatch_log_group.athena.name
}

output "glue_failure_alarm_arn" {
  description = "ARN of the Glue job failure CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.glue_job_failure.arn
}

output "sagemaker_failure_alarm_arn" {
  description = "ARN of the SageMaker job failure CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.sagemaker_job_failure.arn
}

output "athena_failure_alarm_arn" {
  description = "ARN of the Athena query failure CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.athena_query_failure.arn
}

output "dashboard_name" {
  description = "Name of the CDCU CloudWatch operations dashboard"
  value       = aws_cloudwatch_dashboard.cdcu.dashboard_name
}
