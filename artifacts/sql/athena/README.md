# Athena SQL Assets

Place Athena SQL query files in this directory.

## Expected file type
`*.sql` — SQL files for Athena named queries and views

## Naming convention
Use descriptive names that reflect the query purpose:
- `matching_results_view.sql`
- `merge_summary.sql`
- `unique_records.sql`
- `manual_review_queue.sql`

## S3 upload path
Terraform uploads SQL files to:
```
s3://{scripts_bucket}/{environment}/sql/{filename}
```

## Important
If this directory contains only README files (no `*.sql` files), `terraform plan` will show **zero** `aws_s3_object` resources for this subdirectory.
