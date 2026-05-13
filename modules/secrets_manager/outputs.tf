output "mysql_connection_secret_arn" {
  description = "ARN of the MySQL connection secret"
  value       = aws_secretsmanager_secret.mysql_connection.arn
}

output "mysql_connection_secret_name" {
  description = "Name of the MySQL connection secret"
  value       = aws_secretsmanager_secret.mysql_connection.name
}

output "service_credentials_secret_arn" {
  description = "ARN of the service credentials secret"
  value       = aws_secretsmanager_secret.service_credentials.arn
}
