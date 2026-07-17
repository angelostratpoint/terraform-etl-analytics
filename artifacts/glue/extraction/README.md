# Glue Extraction Scripts

This directory contains AWS Glue ETL scripts for the raw extraction phase of
the CDCU pipeline.

## Expected Files

| File | Description |
| --- | --- |
| `merged_raw_extraction.py` | Production-aligned MySQL extraction job derived from `prod_customer_ingestion_job.docx`; extracts the configured source table into `s3://.../raw/merged/` with metadata, schema checks, row-count validation, and S3 write verification. |

## File Type

`*.py` - PySpark scripts compatible with AWS Glue 4.0 (Python 3).

## Naming Convention

Use lowercase with underscores: `{source}_{phase}.py`

Example:

```text
merged_raw_extraction.py
```

## S3 Upload Path

Terraform uploads files from this directory to:

```text
s3://{scripts_bucket}/{environment}/glue-scripts/extraction/{filename}
```

The Glue job `script_location` references this exact path. The filename in this
directory must match the filename expected by the Glue job definition in
`modules/glue/main.tf`.

## Runtime Arguments

The Terraform Glue job definition passes:

```text
--SOURCE_CONNECTION
--TARGET_S3_PATH
--ENVIRONMENT
--SECRET_NAME
--SOURCE_TABLE
--MIN_EXPECTED_ROWS
--COALESCE_FILES
--conf
```

For the current CDCU merged source, `--SOURCE_TABLE` defaults to `customers`.

The extraction job is aligned with the captured `prod_customer_ingestion_job`
runtime settings:

- Glue version: 5.1
- Language: Python 3
- Worker type: G.1X by default
- Job bookmark: disabled
- Source table: `customers`
- Spark config:
  `spark.eventLog.rolling.enabled=true --conf spark.sql.catalog.glue_catalog.glue.skip-name-validation=true`

## Note

If this directory contains only README files and no `*.py` files, `terraform
plan` will show zero `aws_s3_object` resources for this subdirectory. This is
expected; add at least one `.py` script before running Glue extraction jobs.
