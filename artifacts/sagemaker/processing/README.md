# SageMaker Processing Scripts

Place general SageMaker Processing Job scripts in this directory.

## Expected file type
`*.py` — Python scripts for SageMaker Processing Jobs

## Purpose
General-purpose SageMaker processing scripts that are not part of the matching pipeline (e.g., feature engineering, data profiling, EDA).

## S3 upload path
Terraform uploads scripts to:
```
s3://{scripts_bucket}/{environment}/sagemaker-scripts/processing/{filename}
```

## Important
If this directory contains only README files (no `*.py` files), `terraform plan` will show **zero** `aws_s3_object` resources for this subdirectory.
