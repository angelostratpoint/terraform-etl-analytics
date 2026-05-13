# CDCU Artifacts Directory

This directory contains all pipeline scripts and SQL assets that Terraform automatically uploads to S3 during `terraform apply`.

## Directory Structure

```
artifacts/
├── glue/
│   ├── extraction/          ← Glue extraction scripts (*.py)
│   │   └── README.md
│   └── standardization/     ← Glue standardization scripts (*.py)
│       └── README.md
├── sagemaker/
│   ├── matching/            ← SageMaker matching scripts (*.py)
│   │   └── README.md
│   └── processing/          ← SageMaker general processing scripts (*.py)
│       └── README.md
└── sql/
    └── athena/              ← Athena SQL queries and views (*.sql)
        └── README.md
```

## S3 Upload Paths

| Local directory | S3 key prefix |
|---|---|
| `glue/extraction/` | `{env}/glue-scripts/extraction/` |
| `glue/standardization/` | `{env}/glue-scripts/standardization/` |
| `sagemaker/matching/` | `{env}/sagemaker-scripts/matching/` |
| `sagemaker/processing/` | `{env}/sagemaker-scripts/processing/` |
| `sql/athena/` | `{env}/sql/` |

## Important — Empty Directories

`terraform plan` will show **zero** `aws_s3_object` resources for any subdirectory that contains only README files and no matching script files (`*.py` or `*.sql`). This is expected behavior — `fileset()` returns an empty map when no files match the pattern.

Data Engineers must add at least one script file to each subdirectory before the corresponding Glue jobs or SageMaker processing jobs can run successfully.

## Glue Job Script Alignment

Glue job `script_location` values in `modules/glue/main.tf` are hardcoded to match the S3 paths above. If you rename a script file, update the corresponding `script_location` in the Glue module.
