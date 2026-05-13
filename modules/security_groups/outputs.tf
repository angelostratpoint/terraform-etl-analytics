output "glue_security_group_id" {
  description = "ID of the Glue security group"
  value       = aws_security_group.glue.id
}
