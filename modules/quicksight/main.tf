data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  module_admin_group_arn    = "arn:aws:quicksight:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:group/${var.namespace}/cdcu-${var.environment}-admins"
  effective_admin_principal = var.admin_principal_arn != "" ? var.admin_principal_arn : local.module_admin_group_arn

  data_source_owner_permissions = var.enabled ? [
    {
      principal = local.effective_admin_principal
      actions = [
        "quicksight:DescribeDataSource",
        "quicksight:DescribeDataSourcePermissions",
        "quicksight:PassDataSource",
        "quicksight:UpdateDataSource",
        "quicksight:DeleteDataSource",
        "quicksight:UpdateDataSourcePermissions",
      ]
    }
  ] : []

  dataset_owner_permissions = var.enabled ? [
    {
      principal = local.effective_admin_principal
      actions = [
        "quicksight:DescribeDataSet",
        "quicksight:DescribeDataSetPermissions",
        "quicksight:PassDataSet",
        "quicksight:DescribeIngestion",
        "quicksight:ListIngestions",
        "quicksight:UpdateDataSet",
        "quicksight:DeleteDataSet",
        "quicksight:CreateIngestion",
        "quicksight:CancelIngestion",
        "quicksight:UpdateDataSetPermissions",
      ]
    }
  ] : []
}

resource "aws_quicksight_group" "admins" {
  count = var.enabled && var.admin_principal_arn == "" ? 1 : 0

  group_name  = "cdcu-${var.environment}-admins"
  description = "CDCU QuickSight administrators and asset owners"
  namespace   = var.namespace
}

resource "aws_quicksight_group" "authors" {
  count = var.enabled ? 1 : 0

  group_name  = "cdcu-${var.environment}-authors"
  description = "CDCU QuickSight authors; calculator assumes one author"
  namespace   = var.namespace
}

resource "aws_quicksight_group" "readers" {
  count = var.enabled ? 1 : 0

  group_name  = "cdcu-${var.environment}-readers"
  description = "CDCU QuickSight readers; calculator assumes ten readers"
  namespace   = var.namespace
}

resource "aws_quicksight_data_source" "athena" {
  count = var.enabled ? 1 : 0

  data_source_id = "cdcu-${var.environment}-athena"
  name           = "CDCU ${var.environment} Athena"
  type           = "ATHENA"

  parameters {
    athena {
      work_group = var.athena_workgroup_name
    }
  }

  ssl_properties {
    disable_ssl = false
  }

  tags = merge(var.tags, {
    Name            = "cdcu-${var.environment}-athena-datasource"
    SpiceCapacityGB = tostring(var.spice_capacity_gb)
  })

  depends_on = [aws_quicksight_group.admins]
}

resource "aws_quicksight_data_set" "matching_results" {
  count = var.enabled ? 1 : 0

  data_set_id = "cdcu-${var.environment}-matching-results"
  name        = "CDCU ${var.environment} Matching Results"
  import_mode = var.dataset_import_mode

  physical_table_map {
    physical_table_map_id = "matching-results"

    relational_table {
      data_source_arn = aws_quicksight_data_source.athena[0].arn
      catalog         = "AwsDataCatalog"
      schema          = var.glue_catalog_database
      name            = var.matching_table_name

      input_columns {
        name = "match_status"
        type = "STRING"
      }

      input_columns {
        name = "match_score"
        type = "DECIMAL"
      }

      input_columns {
        name = "source_record_id"
        type = "STRING"
      }

      input_columns {
        name = "matched_record_id"
        type = "STRING"
      }
    }
  }

  tags = merge(var.tags, {
    Name            = "cdcu-${var.environment}-matching-results"
    SpiceCapacityGB = tostring(var.spice_capacity_gb)
  })

  depends_on = [aws_quicksight_group.admins]
}
