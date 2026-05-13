###############################################################################
# Module: Secrets Manager
# Purpose: Provisions secrets for MySQL connection and service credentials.
#          No secret values are stored in Terraform — only the secret
#          containers are created. Values are populated out-of-band.
###############################################################################

resource "aws_secretsmanager_secret" "mysql_connection" {
  name        = "cdcu/${var.environment}/mysql-connection"
  description = "MySQL source database connection string for CDCU ${var.environment}"

  kms_key_id              = var.enable_kms ? var.kms_key_arn : null
  recovery_window_in_days = var.recovery_window_in_days

  dynamic "rotation_rules" {
    for_each = var.enable_rotation ? [1] : []
    content {
      automatically_after_days = var.rotation_days
    }
  }

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-mysql-connection"
  })
}

# Placeholder version — actual value must be set manually or via CI/CD
# This prevents Terraform from storing credentials in state
resource "aws_secretsmanager_secret_version" "mysql_connection_placeholder" {
  secret_id = aws_secretsmanager_secret.mysql_connection.id

  # Placeholder structure — replace with actual values via AWS CLI or console
  secret_string = jsonencode({
    host     = "REPLACE_WITH_MYSQL_HOST"
    port     = "3306"
    dbname   = "REPLACE_WITH_DB_NAME"
    username = "REPLACE_WITH_USERNAME"
    password = "REPLACE_WITH_PASSWORD"
  })

  lifecycle {
    # Prevent Terraform from overwriting manually updated secret values
    ignore_changes = [secret_string]
  }
}

# Additional service credentials secret (for Glue/SageMaker API keys if needed)
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
