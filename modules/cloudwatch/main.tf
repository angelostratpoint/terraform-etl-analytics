###############################################################################
# Module: CloudWatch
# Purpose: Provisions log groups, metric filters, and alarms for operational
#          monitoring of Glue, SageMaker, and Athena workloads.
###############################################################################

# ---------------------------------------------------------------------------
# Log Groups
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "glue" {
  name              = "/aws/glue/cdcu-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.enable_kms ? var.kms_key_arn : null

  tags = merge(var.tags, {
    Name = "/aws/glue/cdcu-${var.environment}"
  })
}

resource "aws_cloudwatch_log_group" "sagemaker" {
  name              = "/aws/sagemaker/cdcu-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.enable_kms ? var.kms_key_arn : null

  tags = merge(var.tags, {
    Name = "/aws/sagemaker/cdcu-${var.environment}"
  })
}

resource "aws_cloudwatch_log_group" "athena" {
  name              = "/aws/athena/cdcu-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.enable_kms ? var.kms_key_arn : null

  tags = merge(var.tags, {
    Name = "/aws/athena/cdcu-${var.environment}"
  })
}

# ---------------------------------------------------------------------------
# Metric Filters — Glue job failures
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_filter" "glue_job_failure" {
  name           = "cdcu-${var.environment}-glue-job-failure"
  pattern        = "[timestamp, requestId, level=\"ERROR\", ...]"
  log_group_name = aws_cloudwatch_log_group.glue.name

  metric_transformation {
    name          = "GlueJobFailureCount"
    namespace     = "CDCU/${var.environment}/Glue"
    value         = "1"
    default_value = "0"
  }
}

# ---------------------------------------------------------------------------
# CloudWatch Alarms — Glue
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "glue_job_failure" {
  alarm_name          = "cdcu-${var.environment}-glue-job-failure"
  alarm_description   = "Triggers when a CDCU Glue job enters FAILED state"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "GlueJobFailureCount"
  namespace           = "CDCU/${var.environment}/Glue"
  period              = 300 # 5 minutes
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  ok_actions    = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-glue-job-failure-alarm"
  })
}

# ---------------------------------------------------------------------------
# Metric Filters — SageMaker failures
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_filter" "sagemaker_job_failure" {
  name           = "cdcu-${var.environment}-sagemaker-job-failure"
  pattern        = "[timestamp, requestId, level=\"ERROR\", ...]"
  log_group_name = aws_cloudwatch_log_group.sagemaker.name

  metric_transformation {
    name          = "SageMakerJobFailureCount"
    namespace     = "CDCU/${var.environment}/SageMaker"
    value         = "1"
    default_value = "0"
  }
}

# ---------------------------------------------------------------------------
# CloudWatch Alarms — SageMaker
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "sagemaker_job_failure" {
  alarm_name          = "cdcu-${var.environment}-sagemaker-job-failure"
  alarm_description   = "Triggers when SageMaker processing job failures exceed threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "SageMakerJobFailureCount"
  namespace           = "CDCU/${var.environment}/SageMaker"
  period              = 300 # 5 minutes
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  ok_actions    = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-sagemaker-job-failure-alarm"
  })
}

# ---------------------------------------------------------------------------
# Metric Filters — Athena query failures
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_filter" "athena_query_failure" {
  name           = "cdcu-${var.environment}-athena-query-failure"
  pattern        = "[timestamp, requestId, level=\"ERROR\", ...]"
  log_group_name = aws_cloudwatch_log_group.athena.name

  metric_transformation {
    name          = "AthenaQueryFailureCount"
    namespace     = "CDCU/${var.environment}/Athena"
    value         = "1"
    default_value = "0"
  }
}

# ---------------------------------------------------------------------------
# CloudWatch Alarms — Athena
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "athena_query_failure" {
  alarm_name          = "cdcu-${var.environment}-athena-query-failure"
  alarm_description   = "Triggers when Athena query failures exceed 5 in 10 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "AthenaQueryFailureCount"
  namespace           = "CDCU/${var.environment}/Athena"
  period              = 600 # 10 minutes
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  ok_actions    = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-athena-query-failure-alarm"
  })
}

# ---------------------------------------------------------------------------
# CloudWatch Dashboard
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "cdcu" {
  dashboard_name = "cdcu-${var.environment}-operations"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "Glue Job Failures"
          period = 300
          stat   = "Sum"
          metrics = [
            ["CDCU/${var.environment}/Glue", "GlueJobFailureCount"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "SageMaker Job Failures"
          period = 300
          stat   = "Sum"
          metrics = [
            ["CDCU/${var.environment}/SageMaker", "SageMakerJobFailureCount"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "Athena Query Failures"
          period = 600
          stat   = "Sum"
          metrics = [
            ["CDCU/${var.environment}/Athena", "AthenaQueryFailureCount"]
          ]
        }
      },
    ]
  })
}
