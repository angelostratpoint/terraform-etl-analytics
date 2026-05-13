# Glue Extraction Scripts

This directory contains AWS Glue ETL scripts for the **raw extraction phase** of the CDCU pipeline.

## Expected Files

| File | Description |
|------|-------------|
| `microsite_raw_extraction.py` | Extracts raw customer data from the Microsite MySQL RDS source into `s3://.../raw/microsite/` |
| `legacy_raw_extraction.py` | Extracts raw customer data from the Legacy MySQL RDS source into `s3://.../raw/legacy/` |

## File Type

`*.py` — PySpark scripts compatible with AWS Glue 4.0 (Python 3)

## Naming Convention

Use lowercase with underscores: `{source}_{phase}.py`
Example: `microsite_raw_extraction.py`

## S3 Upload Path

Terraform uploads files from this directory to:
```
s3://{scripts_bucket}/{environment}/glue-scripts/extraction/{filename}
```

The Glue job `script_location` references this exact path. The filename in this directory **must match** the filename expected by the Glue job definition in `modules/glue/main.tf`.

## Note

If this directory contains only README files (no `*.py` files), `terraform plan` will show **zero** `aws_s3_object` resources for this subdirectory. This is expected — add at least one `.py` script before running Glue extraction jobs.
