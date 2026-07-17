locals {
  # Compute MD5 hash of each artifact file for versioning

  glue_extraction_scripts = {
    for file in fileset("${var.artifacts_base_path}/glue/extraction", "**/*.py") :
    file => filemd5("${var.artifacts_base_path}/glue/extraction/${file}")
  }

  glue_standardization_scripts = {
    for file in fileset("${var.artifacts_base_path}/glue/standardization", "**/*.py") :
    file => filemd5("${var.artifacts_base_path}/glue/standardization/${file}")
  }

  sagemaker_matching_scripts = {
    for file in fileset("${var.artifacts_base_path}/sagemaker/matching", "**/*.py") :
    file => filemd5("${var.artifacts_base_path}/sagemaker/matching/${file}")
  }

  sagemaker_processing_scripts = {
    for file in fileset("${var.artifacts_base_path}/sagemaker/processing", "**/*.py") :
    file => filemd5("${var.artifacts_base_path}/sagemaker/processing/${file}")
  }

  sagemaker_notebooks = {
    for file in fileset("${var.artifacts_base_path}/sagemaker/notebooks", "**/*.ipynb") :
    file => filemd5("${var.artifacts_base_path}/sagemaker/notebooks/${file}")
  }

  sql_files = {
    for file in fileset("${var.artifacts_base_path}/sql/athena", "**/*.sql") :
    file => filemd5("${var.artifacts_base_path}/sql/athena/${file}")
  }
}

resource "aws_s3_object" "glue_extraction_scripts" {
  for_each = local.glue_extraction_scripts

  bucket = var.scripts_bucket
  key    = "${var.environment}/glue-scripts/extraction/${each.key}"
  source = "${var.artifacts_base_path}/glue/extraction/${each.key}"
  etag   = each.value

  tags = merge(var.tags, {
    Name        = "${var.environment}/glue-scripts/extraction/${each.key}"
    FileHash    = each.value
    Environment = var.environment
  })
}

resource "aws_s3_object" "glue_standardization_scripts" {
  for_each = local.glue_standardization_scripts

  bucket = var.scripts_bucket
  key    = "${var.environment}/glue-scripts/standardization/${each.key}"
  source = "${var.artifacts_base_path}/glue/standardization/${each.key}"
  etag   = each.value

  tags = merge(var.tags, {
    Name        = "${var.environment}/glue-scripts/standardization/${each.key}"
    FileHash    = each.value
    Environment = var.environment
  })
}

resource "aws_s3_object" "sagemaker_matching_scripts" {
  for_each = local.sagemaker_matching_scripts

  bucket = var.scripts_bucket
  key    = "${var.environment}/sagemaker-scripts/matching/${each.key}"
  source = "${var.artifacts_base_path}/sagemaker/matching/${each.key}"
  etag   = each.value

  tags = merge(var.tags, {
    Name        = "${var.environment}/sagemaker-scripts/matching/${each.key}"
    FileHash    = each.value
    Environment = var.environment
  })
}

resource "aws_s3_object" "sagemaker_processing_scripts" {
  for_each = local.sagemaker_processing_scripts

  bucket = var.scripts_bucket
  key    = "${var.environment}/sagemaker-scripts/processing/${each.key}"
  source = "${var.artifacts_base_path}/sagemaker/processing/${each.key}"
  etag   = each.value

  tags = merge(var.tags, {
    Name        = "${var.environment}/sagemaker-scripts/processing/${each.key}"
    FileHash    = each.value
    Environment = var.environment
  })
}

resource "aws_s3_object" "sagemaker_notebooks" {
  for_each = local.sagemaker_notebooks

  bucket = var.scripts_bucket
  key    = "${var.environment}/sagemaker-notebooks/${each.key}"
  source = "${var.artifacts_base_path}/sagemaker/notebooks/${each.key}"
  etag   = each.value

  tags = merge(var.tags, {
    Name        = "${var.environment}/sagemaker-notebooks/${each.key}"
    FileHash    = each.value
    Environment = var.environment
  })
}

resource "aws_s3_object" "sql_files" {
  for_each = local.sql_files

  bucket = var.scripts_bucket
  key    = "${var.environment}/sql/${each.key}"
  source = "${var.artifacts_base_path}/sql/athena/${each.key}"
  etag   = each.value

  tags = merge(var.tags, {
    Name        = "${var.environment}/sql/${each.key}"
    FileHash    = each.value
    Environment = var.environment
  })
}
