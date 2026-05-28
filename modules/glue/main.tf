data "aws_secretsmanager_secret" "merged_mysql_connection" {
  name = var.merged_mysql_secret_name
}

locals {
  mysql_jdbc_connection_properties = merge(
    {
      JDBC_CONNECTION_URL = var.merged_jdbc_url
      SECRET_ID           = var.merged_mysql_secret_name
    },
    var.mysql_jdbc_driver_class_name != "" ? {
      JDBC_DRIVER_CLASS_NAME = var.mysql_jdbc_driver_class_name
    } : {},
    var.mysql_jdbc_driver_jar_uri != "" ? {
      JDBC_DRIVER_JAR_URI = var.mysql_jdbc_driver_jar_uri
    } : {}
  )
}

resource "aws_glue_catalog_database" "cdcu" {
  name        = "cdcu_${replace(var.environment, "-", "_")}_catalog"
  description = "CDCU ${var.environment} Glue Data Catalog database"
}

resource "aws_glue_connection" "merged_mysql" {
  name            = "cdcu-${var.environment}-merged-mysql"
  description     = "JDBC connection to the merged CDCU MySQL source database"
  connection_type = "JDBC"

  connection_properties = local.mysql_jdbc_connection_properties

  physical_connection_requirements {
    availability_zone      = var.availability_zone
    security_group_id_list = var.glue_security_group_ids
    subnet_id              = var.subnet_id
  }

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-merged-mysql"
  })
}

resource "aws_glue_job" "merged_raw_extraction" {
  name         = "cdcu-${var.environment}-merged-raw-extraction"
  description  = "Extracts raw customer data from the merged CDCU MySQL source into S3 raw layer"
  role_arn     = var.glue_execution_role_arn
  glue_version = "4.0"

  command {
    name            = "glueetl"
    script_location = "s3://${var.scripts_bucket}/${var.environment}/glue-scripts/extraction/merged_raw_extraction.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-spark-ui"                  = "true"
    "--TempDir"                          = "s3://${var.data_lake_bucket}/temp/"
    "--SOURCE_CONNECTION"                = aws_glue_connection.merged_mysql.name
    "--TARGET_S3_PATH"                   = "s3://${var.data_lake_bucket}/raw/merged/"
    "--ENVIRONMENT"                      = var.environment
    "--SECRET_NAME"                      = var.merged_mysql_secret_name
  }

  connections = [aws_glue_connection.merged_mysql.name]

  execution_property {
    max_concurrent_runs = 1
  }

  number_of_workers = var.glue_worker_count
  worker_type       = var.glue_worker_type

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-merged-raw-extraction"
  })
}

resource "aws_glue_job" "merged_standardization" {
  name         = "cdcu-${var.environment}-merged-standardization"
  description  = "Standardizes merged source raw data and writes Parquet to S3 standardized layer"
  role_arn     = var.glue_execution_role_arn
  glue_version = "4.0"

  command {
    name            = "glueetl"
    script_location = "s3://${var.scripts_bucket}/${var.environment}/glue-scripts/standardization/merged_standardization.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--TempDir"                          = "s3://${var.data_lake_bucket}/temp/"
    "--SOURCE_S3_PATH"                   = "s3://${var.data_lake_bucket}/raw/merged/"
    "--TARGET_S3_PATH"                   = "s3://${var.data_lake_bucket}/standardized/merged/"
    "--ENVIRONMENT"                      = var.environment
  }

  execution_property {
    max_concurrent_runs = 1
  }

  number_of_workers = var.glue_worker_count
  worker_type       = var.glue_worker_type

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-merged-standardization"
  })
}

resource "aws_glue_crawler" "merged_raw" {
  name          = "cdcu-${var.environment}-merged-raw-crawler"
  description   = "Crawls merged raw S3 prefix and updates Glue Data Catalog"
  role          = var.glue_execution_role_arn
  database_name = aws_glue_catalog_database.cdcu.name

  s3_target {
    path = "s3://${var.data_lake_bucket}/raw/merged/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
    }
  })

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-merged-raw-crawler"
  })
}

resource "aws_glue_crawler" "merged_standardized" {
  name          = "cdcu-${var.environment}-merged-standardized-crawler"
  description   = "Crawls merged standardized S3 prefix and updates Glue Data Catalog"
  role          = var.glue_execution_role_arn
  database_name = aws_glue_catalog_database.cdcu.name

  s3_target {
    path = "s3://${var.data_lake_bucket}/standardized/merged/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-merged-standardized-crawler"
  })
}

resource "aws_glue_crawler" "processed_matching" {
  name          = "cdcu-${var.environment}-processed-matching-crawler"
  description   = "Crawls processed matching output S3 prefixes and updates Glue Data Catalog"
  role          = var.glue_execution_role_arn
  database_name = aws_glue_catalog_database.cdcu.name

  s3_target {
    path = "s3://${var.data_lake_bucket}/processed/matching/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-processed-matching-crawler"
  })
}

resource "aws_glue_crawler" "errors" {
  name          = "cdcu-${var.environment}-errors-crawler"
  description   = "Crawls CDCU error records for reconciliation and operational review"
  role          = var.glue_execution_role_arn
  database_name = aws_glue_catalog_database.cdcu.name

  s3_target {
    path = "s3://${var.data_lake_bucket}/errors/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-errors-crawler"
  })
}
