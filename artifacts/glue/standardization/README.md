# Glue Standardization Scripts

This directory contains AWS Glue ETL scripts for the **standardization phase** of the CDCU pipeline.

## Expected Files

| File | Description |
|------|-------------|
| `merged_standardization.py` | Reads merged raw source data from S3, applies cleaning rules, and writes Parquet to `s3://.../standardized/merged/` |

See `source-to-target-standardization-checklist.md` for the DA/DE-owned source-to-target
cleanup checklist and the Terraform-provisioned data lake prefixes.

## File Type

`*.py` — PySpark scripts compatible with AWS Glue 4.0 (Python 3)

## Naming Convention

Use lowercase with underscores: `{source}_standardization.py`
Example: `merged_standardization.py`

## S3 Upload Path

Terraform uploads files from this directory to:
```
s3://{scripts_bucket}/{environment}/glue-scripts/standardization/{filename}
```

The Glue job `script_location` references this exact path. The filename in this directory **must match** the filename expected by the Glue job definition in `modules/glue/main.tf`.

## Note

If this directory contains only README files (no `*.py` files), `terraform plan` will show **zero** `aws_s3_object` resources for this subdirectory. This is expected — add at least one `.py` script before running Glue standardization jobs.
