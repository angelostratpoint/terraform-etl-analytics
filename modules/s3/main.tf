locals {
  bucket_name = "cdcu-${var.environment}-data-lake"
}

resource "aws_s3_bucket" "cdcu_data_lake" {
  bucket = local.bucket_name

  tags = merge(var.tags, {
    Name               = local.bucket_name
    DataClassification = "PII"
  })
}

resource "aws_s3_bucket_public_access_block" "cdcu_data_lake" {
  bucket = aws_s3_bucket.cdcu_data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "cdcu_data_lake" {
  bucket = aws_s3_bucket.cdcu_data_lake.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cdcu_data_lake" {
  bucket = aws_s3_bucket.cdcu_data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.enable_kms ? "aws:kms" : "AES256"
      kms_master_key_id = var.enable_kms ? var.kms_key_arn : null
    }
    bucket_key_enabled = var.enable_kms
  }
}

resource "aws_s3_bucket_policy" "cdcu_data_lake" {
  bucket = aws_s3_bucket.cdcu_data_lake.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonHTTPS"
        Effect    = "Deny"
        Principal = "*"
        Action    = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource  = "${aws_s3_bucket.cdcu_data_lake.arn}/*"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.cdcu_data_lake]
}

resource "aws_s3_bucket_lifecycle_configuration" "cdcu_data_lake" {
  bucket = aws_s3_bucket.cdcu_data_lake.id

  rule {
    id     = "logs-intelligent-tiering"
    status = "Enabled"
    filter { prefix = "logs/" }
    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }
  }

  rule {
    id     = "errors-intelligent-tiering"
    status = "Enabled"
    filter { prefix = "errors/" }
    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }
  }

  rule {
    id     = "processed-archive"
    status = "Enabled"
    filter { prefix = "processed/" }
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 180
      storage_class = "GLACIER"
    }
  }

  # PIA: Stratpoint access is limited to 5 months.
  # Raw and standardized data contain PII — transition to GLACIER after 6 months,
  # expire after 12 months unless BPI MS extends retention contractually.
  rule {
    id     = "raw-pii-retention"
    status = "Enabled"
    filter { prefix = "raw/" }
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 180
      storage_class = "GLACIER"
    }
    expiration {
      days = 365
    }
  }

  rule {
    id     = "standardized-pii-retention"
    status = "Enabled"
    filter { prefix = "standardized/" }
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 180
      storage_class = "GLACIER"
    }
    expiration {
      days = 365
    }
  }

  # Temp prefix used by Glue jobs as --TempDir — expire after 7 days
  rule {
    id     = "temp-cleanup"
    status = "Enabled"
    filter { prefix = "temp/" }
    expiration {
      days = 7
    }
  }
}

locals {
  # S3 has no real folders; zero-byte objects create visible prefixes in the console.
  folder_prefixes = [
    "raw/microsite/",
    "raw/legacy/",
    "standardized/microsite/",
    "standardized/legacy/",
    "processed/matching/merge/",
    "processed/matching/unique/",
    "processed/matching/manual_review/",
    "logs/",
    "errors/",
    # temp/ is required by all Glue jobs as --TempDir
    "temp/",
  ]
}

resource "aws_s3_object" "folder_placeholders" {
  for_each = toset(local.folder_prefixes)

  bucket  = aws_s3_bucket.cdcu_data_lake.id
  key     = each.value
  content = ""

  tags = var.tags
}

resource "aws_s3_bucket" "cdcu_athena_results" {
  bucket = "cdcu-${var.environment}-athena-results"

  tags = merge(var.tags, {
    Name               = "cdcu-${var.environment}-athena-results"
    DataClassification = "Internal"
  })
}

resource "aws_s3_bucket_public_access_block" "cdcu_athena_results" {
  bucket = aws_s3_bucket.cdcu_athena_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "cdcu_athena_results" {
  bucket = aws_s3_bucket.cdcu_athena_results.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cdcu_athena_results" {
  bucket = aws_s3_bucket.cdcu_athena_results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.enable_kms ? "aws:kms" : "AES256"
      kms_master_key_id = var.enable_kms ? var.kms_key_arn : null
    }
    bucket_key_enabled = var.enable_kms
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cdcu_athena_results" {
  bucket = aws_s3_bucket.cdcu_athena_results.id

  rule {
    id     = "athena-results-expiry"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_policy" "cdcu_athena_results" {
  bucket = aws_s3_bucket.cdcu_athena_results.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonHTTPS"
        Effect    = "Deny"
        Principal = "*"
        Action    = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource  = "${aws_s3_bucket.cdcu_athena_results.arn}/*"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.cdcu_athena_results]
}
