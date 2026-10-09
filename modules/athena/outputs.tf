output "workgroup_name" {
  description = "Name of the Athena workgroup"
  value       = aws_athena_workgroup.cdcu.name
}

output "workgroup_arn" {
  description = "ARN of the Athena workgroup"
  value       = aws_athena_workgroup.cdcu.arn
}

output "quicksight_setup_queries" {
  description = "QuickSight saved queries in execution order. Run manually; Terraform does not execute SQL."
  value = [
    for filename in sort(keys(aws_athena_named_query.quicksight_setup)) : {
      step      = substr(filename, 0, 2)
      name      = aws_athena_named_query.quicksight_setup[filename].name
      id        = aws_athena_named_query.quicksight_setup[filename].id
      database  = aws_athena_named_query.quicksight_setup[filename].database
      workgroup = aws_athena_named_query.quicksight_setup[filename].workgroup
    }
  ]
}
