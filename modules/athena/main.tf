resource "aws_athena_workgroup" "cdcu" {
  name        = "cdcu-${var.environment}-workgroup"
  description = "CDCU ${var.environment} Athena workgroup for customer data queries"
  state       = "ENABLED"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${var.athena_results_bucket}/query-results/"

      encryption_configuration {
        encryption_option = var.enable_kms ? "SSE_KMS" : "SSE_S3"
        kms_key           = var.enable_kms ? var.kms_key_arn : null
      }
    }

    bytes_scanned_cutoff_per_query = 10737418240 # 10 GB in bytes
  }

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-workgroup"
  })
}

resource "aws_athena_named_query" "validate_microsite_count" {
  name        = "cdcu-${var.environment}-validate-microsite-count"
  description = "Validates record count in Microsite standardized table"
  workgroup   = aws_athena_workgroup.cdcu.name
  database    = var.glue_catalog_database

  query = <<-SQL
    SELECT
      COUNT(*) AS total_records,
      COUNT(CASE WHEN last_name IS NULL THEN 1 END) AS null_last_name,
      COUNT(CASE WHEN first_name IS NULL THEN 1 END) AS null_first_name,
      COUNT(CASE WHEN birth_date IS NULL THEN 1 END) AS null_birth_date,
      COUNT(CASE WHEN tin IS NULL THEN 1 END) AS null_tin
    FROM cdcu_${replace(var.environment, "-", "_")}_catalog.microsite_standardized
  SQL
}

resource "aws_athena_named_query" "validate_legacy_count" {
  name        = "cdcu-${var.environment}-validate-legacy-count"
  description = "Validates record count in Legacy standardized table"
  workgroup   = aws_athena_workgroup.cdcu.name
  database    = var.glue_catalog_database

  query = <<-SQL
    SELECT
      COUNT(*) AS total_records,
      COUNT(CASE WHEN last_name IS NULL THEN 1 END) AS null_last_name,
      COUNT(CASE WHEN first_name IS NULL THEN 1 END) AS null_first_name,
      COUNT(CASE WHEN birth_date IS NULL THEN 1 END) AS null_birth_date,
      COUNT(CASE WHEN tin IS NULL THEN 1 END) AS null_tin
    FROM cdcu_${replace(var.environment, "-", "_")}_catalog.legacy_standardized
  SQL
}

resource "aws_athena_named_query" "matching_summary" {
  name        = "cdcu-${var.environment}-matching-summary"
  description = "Summary of matching results by classification category"
  workgroup   = aws_athena_workgroup.cdcu.name
  database    = var.glue_catalog_database

  query = <<-SQL
    SELECT
      match_status,
      COUNT(*) AS record_count,
      AVG(match_score) AS avg_match_score,
      MIN(match_score) AS min_match_score,
      MAX(match_score) AS max_match_score
    FROM cdcu_${replace(var.environment, "-", "_")}_catalog.processed_matching
    GROUP BY match_status
    ORDER BY record_count DESC
  SQL
}
