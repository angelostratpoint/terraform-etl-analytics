output "kms_key_arn" {
  description = "ARN of the CDCU customer-managed KMS key"
  value       = aws_kms_key.cdcu_cmk.arn
}

output "kms_key_id" {
  description = "ID of the CDCU customer-managed KMS key"
  value       = aws_kms_key.cdcu_cmk.key_id
}

output "kms_key_alias" {
  description = "Alias of the CDCU customer-managed KMS key"
  value       = aws_kms_alias.cdcu_cmk_alias.name
}
