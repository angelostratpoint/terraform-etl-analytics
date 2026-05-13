output "microsite_mysql_connection_secret_arn" {
  description = "ARN of the Microsite MySQL connection secret"
  value       = aws_secretsmanager_secret.microsite_mysql_connection.arn
}

output "microsite_mysql_connection_secret_name" {
  description = "Name of the Microsite MySQL connection secret"
  value       = aws_secretsmanager_secret.microsite_mysql_connection.name
}

output "legacy_mysql_connection_secret_arn" {
  description = "ARN of the Legacy MySQL connection secret"
  value       = aws_secretsmanager_secret.legacy_mysql_connection.arn
}

output "legacy_mysql_connection_secret_name" {
  description = "Name of the Legacy MySQL connection secret"
  value       = aws_secretsmanager_secret.legacy_mysql_connection.name
}

output "service_credentials_secret_arn" {
  description = "ARN of the service credentials secret"
  value       = aws_secretsmanager_secret.service_credentials.arn
}
