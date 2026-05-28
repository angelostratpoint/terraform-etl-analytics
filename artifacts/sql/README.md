# Athena SQL Queries and Views

Place all Athena SQL files here. Scripts are automatically uploaded to S3 during `terraform apply`.

## Purpose

SQL files define:
- **Views** — reusable query logic for reporting
- **Validation queries** — data quality checks
- **Aggregation queries** — summary statistics for QuickSight dashboards

## Expected SQL Files

1. **create_matching_summary_view.sql** — View summarizing match results by status
2. **validate_record_counts.sql** — Validation query comparing source vs. processed counts
3. **quality_metrics.sql** — Data quality metrics (null rates, duplicate counts, etc.)

## Example: Create View

```sql
-- create_matching_summary_view.sql
CREATE OR REPLACE VIEW cdcu_matching_summary AS
SELECT
  match_status,
  COUNT(*) AS record_count,
  AVG(match_score) AS avg_score,
  MIN(match_score) AS min_score,
  MAX(match_score) AS max_score
FROM cdcu_pre_prod_catalog.processed_matching
GROUP BY match_status
ORDER BY record_count DESC;
```

## Example: Validation Query

```sql
-- validate_record_counts.sql
SELECT
  'Merged Raw' AS source,
  COUNT(*) AS record_count
FROM cdcu_pre_prod_catalog.merged_raw

UNION ALL

SELECT
  'Merged Standardized' AS source,
  COUNT(*) AS record_count
FROM cdcu_pre_prod_catalog.merged_standardized;
```

## Running SQL Files

SQL files are uploaded to S3 but must be executed manually via:
- **Athena console** — copy/paste and run
- **AWS CLI** — `aws athena start-query-execution --query-string "$(cat query.sql)"`
- **QuickSight** — reference views in dataset definitions

## S3 Upload Path

SQL files are uploaded to: `s3://cdcu-{env}-data-lake/{env}/sql/`

## Note on Named Queries

The `modules/athena/main.tf` already provisions 2 named queries:
- `validate_merged_count`
- `matching_summary`

Additional SQL files here are for custom queries not defined in Terraform.
