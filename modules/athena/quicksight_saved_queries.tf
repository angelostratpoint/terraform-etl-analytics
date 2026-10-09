locals {
  quicksight_setup_query_files = var.enable_quicksight_setup_queries ? fileset("${path.module}/sql/quicksight", "*.sql.tftpl") : toset([])
}

# Saved queries only. An approved operator runs these in numeric order in Athena.
resource "aws_athena_named_query" "quicksight_setup" {
  for_each = local.quicksight_setup_query_files

  name        = "cdcu-${var.environment}-qs-${trimsuffix(each.value, ".sql.tftpl")}"
  description = "Manual QuickSight setup step ${substr(each.value, 0, 2)}. Run in numeric order; wait for success before the next step."
  workgroup   = aws_athena_workgroup.cdcu.name
  database    = var.glue_catalog_database
  query = templatefile("${path.module}/sql/quicksight/${each.value}", {
    data_lake_bucket = var.quicksight_data_lake_bucket
  })

  lifecycle {
    precondition {
      condition     = var.quicksight_data_lake_bucket != ""
      error_message = "quicksight_data_lake_bucket is required when QuickSight setup saved queries are enabled."
    }
  }
}
