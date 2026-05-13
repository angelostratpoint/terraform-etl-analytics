###############################################################################
# Module: Secrets Manager
# Purpose: Provisions separate secrets for Microsite and Legacy MySQL connections.
#          Two separate source databases require two separate secrets.
#          No secret values are stored in Terraform — only the containers.
#          Values are populated out-of-band via AWS CLI or console.
###############################################################################

# Microsite MySQL connection secret
resource "aws_secretsmanager_secret" "microsite_mysql_connection" {
  name        = "cdcu/${var.environment}/microsite-mysql-connection"
  description = "Microsite MySQL source database connection string for CDCU ${var.environment}"

  kms_key_id              = var.enable_kms ? var.kms_key_arn : null
  recovery_window_in_days = var.recovery_window_in_days

  dynamic "rotation_rules" {
    for_each = var.enable_rotation ? [1] : []
    content {
      automatically_after_days = var.rotation_days
    }
  }

  tags = merge(var.tags, {
    Name           = "cdcu-${var.environment}-microsite-mysql-connection"
    DataSource     = "Microsite"
    DataClassification = "Confidential"
  })
}

resource "aws_secretsmanager_secret_version" "microsite_mysql_connection_placeholder" {
  secret_id = aws_secretsmanager_secret.microsite_mysql_connection.id

  secret_string = jsonencode({
    host     = "REPLACE_WITH_MICROSITE_MYSQL_HOST"
    port     = "3306"
    dbname   = "REPLACE_WITH_MICROSITE_DB_NAME"
    username = "REPLACE_WITH_MICROSITE_USERNAME"
    password = "REPLACE_WITH_MICROSITE_PASSWORD"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Legacy MySQL connection secret — separate from Microsite
resource "aws_secretsmanager_secret" "legacy_mysql_connection" {
  name        = "cdcu/${var.environment}/legacy-mysql-connection"
  description = "Legacy MySQL source database connection string for CDCU ${var.environment}"

  kms_key_id              = var.enable_kms ? var.kms_key_arn : null
  recovery_window_in_days = var.recovery_window_in_days

  dynamic "rotation_rules" {
    for_each = var.enable_rotation ? [1] : []
    content {
      automatically_after_days = var.rotation_days
    }
  }

  tags = merge(var.tags, {
    Name           = "cdcu-${var.environment}-legacy-mysql-connection"
    DataSource     = "Legacy"
    DataClassification = "Confidential"
  })
}

resource "aws_secretsmanager_secret_version" "legacy_mysql_connection_placeholder" {
  secret_id = aws_secretsmanager_secret.legacy_mysql_connection.id

  secret_string = jsonencode({
    host     = "REPLACE_WITH_LEGACY_MYSQL_HOST"
    port     = "3306"
    dbname   = "REPLACE_WITH_LEGACY_DB_NAME"
    username = "REPLACE_WITH_LEGACY_USERNAME"
    password = "REPLACE_WITH_LEGACY_PASSWORD"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Service credentials secret — for any additional API keys or tokens
resource "aws_secretsmanager_secret" "service_credentials" {
  name        = "cdcu/${var.environment}/service-credentials"
  description = "Additional service credentials for CDCU ${var.environment} workloads"

  kms_key_id              = var.enable_kms ? var.kms_key_arn : null
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-service-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "service_credentials_placeholder" {
  secret_id = aws_secretsmanager_secret.service_credentials.id

  secret_string = jsonencode({
    note = "Populate this secret with any additional service credentials required"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
