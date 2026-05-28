# SageMaker Matching Scripts

This directory contains Python scripts for the **matching phase** of the CDCU pipeline, executed as SageMaker Processing Jobs.

## Expected Files

| File | Description |
|------|-------------|
| `matching_processor.py` | Main matching logic using standardized CDCU customer records, string distance, and date compute algorithms |

## Matching Phases

The matching engine runs in three phases:
1. **Phase 1 (MVP)** - Blocking and initial matching using Names, Birthdates, Mobile Numbers, Emails, TINs
2. **Phase 2 (Tuning)** - Weighted scoring and threshold refinement; classifies records as Merge / Manual Review / Unique
3. **Phase 3 (Production)** - Scale optimization, error handling, reason codes (for example, `same_mobile_same_birthdate`)

## File Type

`*.py` - Python scripts executed as SageMaker Processing Jobs

## Naming Convention

Use lowercase with underscores: `{function}_processor.py` or `{function}_matching.py`

## S3 Upload Path

Terraform uploads files from this directory to:
```
s3://{scripts_bucket}/{environment}/sagemaker-scripts/matching/{filename}
```

## Note

If this directory contains only README files (no `*.py` files), `terraform plan` will show **zero** `aws_s3_object` resources for this subdirectory.
