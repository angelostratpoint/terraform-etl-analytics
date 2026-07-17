# Glue Standardization Scripts

This directory contains AWS Glue ETL scripts for the standardization phase of
the CDCU pipeline.

## Expected Files

| File | Description |
| --- | --- |
| `merged_standardization.py` | Production-aligned customer standardization job derived from `prod_customers_standardization_job.docx`; reads merged raw source data from S3, applies customer data cleaning and DQ rules, and writes Parquet to `s3://.../standardized/merged/`. |

See `source-to-target-standardization-checklist.md` for the DA/DE-owned source-to-target cleanup checklist and the Terraform-provisioned data lake prefixes.

## File Type

`*.py` - PySpark scripts compatible with AWS Glue 5.1 (Python 3).

## Naming Convention

Use lowercase with underscores: `{source}_standardization.py`

Example:

```text
merged_standardization.py
```

## S3 Upload Path

Terraform uploads files from this directory to:

```text
s3://{scripts_bucket}/{environment}/glue-scripts/standardization/{filename}
```

The Glue job `script_location` references this exact path. The filename in this
directory must match the filename expected by the Glue job definition in
`modules/glue/main.tf`.

## Runtime Arguments

The Terraform Glue job definition passes both the existing Terraform argument
names and the captured Glue console argument names:

```text
--SOURCE_S3_PATH
--TARGET_S3_PATH
--INPUT_PATH
--OUTPUT_PATH
--ENVIRONMENT
--MIN_EXPECTED_ROWS
--SINGLE_OUTPUT_FILE
--conf
```

`merged_standardization.py` accepts either `SOURCE_S3_PATH`/`TARGET_S3_PATH` or
`INPUT_PATH`/`OUTPUT_PATH`. This keeps compatibility with the existing Terraform
module and the captured `prod_customers_standardization_job` configuration.

The standardization job is aligned with the captured runtime settings:

- Glue version: 5.1
- Language: Python 3
- Worker type: G.1X by default
- Job bookmark: disabled
- Spark config:
  `spark.eventLog.rolling.enabled=true --conf spark.sql.catalog.glue_catalog.glue.skip-name-validation=true`
- SIT can coalesce to a single output file. UAT/PROD defaults to parallel writes.

## Note

If this directory contains only README files and no `*.py` files, `terraform plan` will show zero `aws_s3_object` resources for this subdirectory. This is expected. Add at least one `.py` script before running Glue standardization jobs.
