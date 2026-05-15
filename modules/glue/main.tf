# Separate secrets for Microsite and Legacy — two distinct MySQL source databases
data "aws_secretsmanager_secret" "microsite_mysql_connection" {
  name = "cdcu/${var.environment}/microsite-mysql-connection"
}

data "aws_secretsmanager_secret" "legacy_mysql_connection" {
  name = "cdcu/${var.environment}/legacy-mysql-connection"
}

resource "aws_glue_catalog_database" "cdcu" {
  name        = "cdcu_${replace(var.environment, "-", "_")}_catalog"
  description = "CDCU ${var.environment} Glue Data Catalog database"
}

resource "aws_glue_connection" "microsite_mysql" {
  name            = "cdcu-${var.environment}-microsite-mysql"
  description     = "JDBC connection to Microsite MySQL source database"
  connection_type = "JDBC"

  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:mysql://localhost:3306/test"
    SECRET_ID           = "cdcu/${var.environment}/microsite-mysql-connection"
  }

  physical_connection_requirements {
    availability_zone      = var.availability_zone
    security_group_id_list = var.glue_security_group_ids
    subnet_id              = var.subnet_id
  }

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-microsite-mysql"
  })
}

resource "aws_glue_connection" "legacy_mysql" {
  name            = "cdcu-${var.environment}-legacy-mysql"
  description     = "JDBC connection to Legacy MySQL source database"
  connection_type = "JDBC"

  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:mysql://localhost:3306/test"
    SECRET_ID           = "cdcu/${var.environment}/legacy-mysql-connection"
  }

  physical_connection_requirements {
    availability_zone      = var.availability_zone
    security_group_id_list = var.glue_security_group_ids
    subnet_id              = var.subnet_id
  }

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-legacy-mysql"
  })
}

resource "aws_glue_job" "microsite_raw_extraction" {
  name         = "cdcu-${var.environment}-microsite-raw-extraction"
  description  = "Extracts raw customer data from Microsite MySQL into S3 raw layer"
  role_arn     = var.glue_execution_role_arn
  glue_version = "4.0"

  command {
    name = "glueetl"
    # Script path uses environment prefix — uploaded by the artifacts module
    script_location = "s3://${var.scripts_bucket}/${var.environment}/glue-scripts/extraction/microsite_raw_extraction.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-spark-ui"                  = "true"
    "--TempDir"                          = "s3://${var.data_lake_bucket}/temp/"
    "--SOURCE_CONNECTION"                = aws_glue_connection.microsite_mysql.name
    "--TARGET_S3_PATH"                   = "s3://${var.data_lake_bucket}/raw/microsite/"
    "--ENVIRONMENT"                      = var.environment
    "--SECRET_NAME"                      = "cdcu/${var.environment}/microsite-mysql-connection"
  }

  connections = [aws_glue_connection.microsite_mysql.name]

  execution_property {
    max_concurrent_runs = 1
  }

  number_of_workers = var.glue_worker_count
  worker_type       = var.glue_worker_type

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-microsite-raw-extraction"
  })
}

resource "aws_glue_job" "legacy_raw_extraction" {
  name         = "cdcu-${var.environment}-legacy-raw-extraction"
  description  = "Extracts raw customer data from Legacy MySQL into S3 raw layer"
  role_arn     = var.glue_execution_role_arn
  glue_version = "4.0"

  command {
    name            = "glueetl"
    script_location = "s3://${var.scripts_bucket}/${var.environment}/glue-scripts/extraction/legacy_raw_extraction.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--TempDir"                          = "s3://${var.data_lake_bucket}/temp/"
    "--SOURCE_CONNECTION"                = aws_glue_connection.legacy_mysql.name
    "--TARGET_S3_PATH"                   = "s3://${var.data_lake_bucket}/raw/legacy/"
    "--ENVIRONMENT"                      = var.environment
    "--SECRET_NAME"                      = "cdcu/${var.environment}/legacy-mysql-connection"
  }

  connections = [aws_glue_connection.legacy_mysql.name]

  execution_property {
    max_concurrent_runs = 1
  }

  number_of_workers = var.glue_worker_count
  worker_type       = var.glue_worker_type

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-legacy-raw-extraction"
  })
}

resource "aws_glue_job" "microsite_standardization" {
  name         = "cdcu-${var.environment}-microsite-standardization"
  description  = "Standardizes Microsite raw data and writes Parquet to S3 standardized layer"
  role_arn     = var.glue_execution_role_arn
  glue_version = "4.0"

  command {
    name            = "glueetl"
    script_location = "s3://${var.scripts_bucket}/${var.environment}/glue-scripts/standardization/microsite_standardization.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--TempDir"                          = "s3://${var.data_lake_bucket}/temp/"
    "--SOURCE_S3_PATH"                   = "s3://${var.data_lake_bucket}/raw/microsite/"
    "--TARGET_S3_PATH"                   = "s3://${var.data_lake_bucket}/standardized/microsite/"
    "--ENVIRONMENT"                      = var.environment
  }

  execution_property {
    max_concurrent_runs = 1
  }

  number_of_workers = var.glue_worker_count
  worker_type       = var.glue_worker_type

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-microsite-standardization"
  })
}

resource "aws_glue_job" "legacy_standardization" {
  name         = "cdcu-${var.environment}-legacy-standardization"
  description  = "Standardizes Legacy raw data and writes Parquet to S3 standardized layer"
  role_arn     = var.glue_execution_role_arn
  glue_version = "4.0"

  command {
    name            = "glueetl"
    script_location = "s3://${var.scripts_bucket}/${var.environment}/glue-scripts/standardization/legacy_standardization.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--TempDir"                          = "s3://${var.data_lake_bucket}/temp/"
    "--SOURCE_S3_PATH"                   = "s3://${var.data_lake_bucket}/raw/legacy/"
    "--TARGET_S3_PATH"                   = "s3://${var.data_lake_bucket}/standardized/legacy/"
    "--ENVIRONMENT"                      = var.environment
  }

  execution_property {
    max_concurrent_runs = 1
  }

  number_of_workers = var.glue_worker_count
  worker_type       = var.glue_worker_type

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-legacy-standardization"
  })
}

resource "aws_glue_crawler" "microsite_raw" {
  name          = "cdcu-${var.environment}-microsite-raw-crawler"
  description   = "Crawls Microsite raw S3 prefix and updates Glue Data Catalog"
  role          = var.glue_execution_role_arn
  database_name = aws_glue_catalog_database.cdcu.name

  s3_target {
    path = "s3://${var.data_lake_bucket}/raw/microsite/"
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
    Name = "cdcu-${var.environment}-microsite-raw-crawler"
  })
}

resource "aws_glue_crawler" "legacy_raw" {
  name          = "cdcu-${var.environment}-legacy-raw-crawler"
  description   = "Crawls Legacy raw S3 prefix and updates Glue Data Catalog"
  role          = var.glue_execution_role_arn
  database_name = aws_glue_catalog_database.cdcu.name

  s3_target {
    path = "s3://${var.data_lake_bucket}/raw/legacy/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-legacy-raw-crawler"
  })
}

resource "aws_glue_crawler" "microsite_standardized" {
  name          = "cdcu-${var.environment}-microsite-standardized-crawler"
  description   = "Crawls Microsite standardized S3 prefix and updates Glue Data Catalog"
  role          = var.glue_execution_role_arn
  database_name = aws_glue_catalog_database.cdcu.name

  s3_target {
    path = "s3://${var.data_lake_bucket}/standardized/microsite/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-microsite-standardized-crawler"
  })
}

resource "aws_glue_crawler" "legacy_standardized" {
  name          = "cdcu-${var.environment}-legacy-standardized-crawler"
  description   = "Crawls Legacy standardized S3 prefix and updates Glue Data Catalog"
  role          = var.glue_execution_role_arn
  database_name = aws_glue_catalog_database.cdcu.name

  s3_target {
    path = "s3://${var.data_lake_bucket}/standardized/legacy/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-legacy-standardized-crawler"
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
