# SageMaker Processing Scripts

## Expected File Type

`*.py` - Python scripts for SageMaker Processing Jobs.

## Purpose

`matching_prod.py` is generated from the DE-provided `Matching_prod.ipynb`
notebook and is the default SageMaker Pipeline processing entry point.

`merged_matching.py` remains as the earlier sandbox placeholder and should not
be treated as the final UAT/PROD matching implementation.

The SageMaker processing image used for the pipeline must include the notebook
runtime dependencies used by `matching_prod.py`, including pandas, numpy,
awswrangler, rapidfuzz, jellyfish, and psutil.

## S3 Upload Path

Terraform uploads scripts to:

```text
s3://{scripts_bucket}/{environment}/sagemaker-scripts/processing/{filename}
```

## Important

If this directory contains only README files and no `*.py` files, `terraform
plan` will show zero `aws_s3_object` resources for this subdirectory.
