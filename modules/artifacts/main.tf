locals {
  # Compute MD5 hash of each artifact file for versioning
  glue_scripts = {
    for file in fileset("${var.artifacts_base_path}/glue", "**/*.py") :
    file => filemd5("${var.artifacts_base_path}/glue/${file}")
  }

  sagemaker_scripts = {
    for file in fileset("${var.artifacts_base_path}/sagemaker", "**/*.py") :
    file => filemd5("${var.artifacts_base_path}/sagemaker/${file}")
  }

  sql_files = {
    for file in fileset("${var.artifacts_base_path}/sql", "**/*.sql") :
    file => filemd5("${var.artifacts_base_path}/sql/${file}")
  }

  matching_scripts = {
    for file in fileset("${var.artifacts_base_path}/matching", "**/*.py") :
    file => filemd5("${var.artifacts_base_path}/matching/${file}")
  }
}

resource "aws_s3_object" "glue_scripts" {
  for_each = local.glue_scripts

  bucket = var.scripts_bucket
  key    = "${var.environment}/glue-scripts/${each.key}"
  source = "${var.artifacts_base_path}/glue/${each.key}"
  etag   = each.value

  tags = merge(var.tags, {
    Name        = "${var.environment}/glue-scripts/${each.key}"
    FileHash    = each.value
    Environment = var.environment
  })
}

resource "aws_s3_object" "sagemaker_scripts" {
  for_each = local.sagemaker_scripts

  bucket = var.scripts_bucket
  key    = "${var.environment}/sagemaker-scripts/${each.key}"
  source = "${var.artifacts_base_path}/sagemaker/${each.key}"
  etag   = each.value

  tags = merge(var.tags, {
    Name        = "${var.environment}/sagemaker-scripts/${each.key}"
    FileHash    = each.value
    Environment = var.environment
  })
}

resource "aws_s3_object" "sql_files" {
  for_each = local.sql_files

  bucket = var.scripts_bucket
  key    = "${var.environment}/sql/${each.key}"
  source = "${var.artifacts_base_path}/sql/${each.key}"
  etag   = each.value

  tags = merge(var.tags, {
    Name        = "${var.environment}/sql/${each.key}"
    FileHash    = each.value
    Environment = var.environment
  })
}

resource "aws_s3_object" "matching_scripts" {
  for_each = local.matching_scripts

  bucket = var.scripts_bucket
  key    = "${var.environment}/matching-scripts/${each.key}"
  source = "${var.artifacts_base_path}/matching/${each.key}"
  etag   = each.value

  tags = merge(var.tags, {
    Name        = "${var.environment}/matching-scripts/${each.key}"
    FileHash    = each.value
    Environment = var.environment
  })
}
