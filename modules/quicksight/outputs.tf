output "data_source_arn" {
  description = "QuickSight Athena data source ARN"
  value       = var.enabled ? aws_quicksight_data_source.athena[0].arn : null
}

output "data_set_arn" {
  description = "QuickSight matching results dataset ARN"
  value       = var.enabled ? aws_quicksight_data_set.matching_results[0].arn : null
}

output "admin_group_arn" {
  description = "Module-created QuickSight admin group ARN, when created"
  value       = var.enabled && length(aws_quicksight_group.admins) > 0 ? aws_quicksight_group.admins[0].arn : null
}

output "author_group_arn" {
  description = "QuickSight author group ARN"
  value       = var.enabled ? aws_quicksight_group.authors[0].arn : null
}

output "reader_group_arn" {
  description = "QuickSight reader group ARN"
  value       = var.enabled ? aws_quicksight_group.readers[0].arn : null
}

output "spice_capacity_gb" {
  description = "Documented SPICE capacity requirement"
  value       = var.spice_capacity_gb
}
