# SageMaker Processing Scripts

Place all SageMaker processing job scripts here. Scripts are automatically uploaded to S3 during `terraform apply`.

## Purpose

SageMaker Processing Jobs are used for:
- Customer matching logic (fuzzy matching, blocking, scoring)
- Data quality validation
- Large-scale data transformations that exceed Glue's capabilities

## Script Template

```python
import argparse
import pandas as pd
import boto3
from rapidfuzz import fuzz

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-path", type=str, required=True)
    parser.add_argument("--output-path", type=str, required=True)
    parser.add_argument("--environment", type=str, required=True)
    args = parser.parse_args()

    # Your processing logic here
    
    print(f"Processing complete for {args.environment}")
```

## Running a Processing Job

SageMaker Processing Jobs are invoked via AWS CLI or console:

```bash
aws sagemaker create-processing-job \
  --processing-job-name cdcu-matching-job \
  --role-arn arn:aws:iam::ACCOUNT:role/cdcu-sit-sagemaker-execution-role \
  --app-specification ImageUri=683313688378.dkr.ecr.ap-southeast-1.amazonaws.com/sagemaker-scikit-learn:1.0-1-cpu-py3,ContainerEntrypoint=python3,ContainerArguments=/opt/ml/processing/input/code/matching_processor.py,--input-path,s3://bucket/standardized/,--output-path,s3://bucket/processed/ \
  --processing-inputs SourceUri=s3://cdcu-sit-data-lake/sit/sagemaker-scripts/matching_processor.py,Destination=/opt/ml/processing/input/code \
  --processing-outputs SourceUri=/opt/ml/processing/output,Destination=s3://cdcu-sit-data-lake/processed/matching/
```

## S3 Upload Path

Scripts are uploaded to: `s3://cdcu-{env}-data-lake/{env}/sagemaker-scripts/`

## Note on SageMaker Unified Studio

This repository does NOT provision a SageMaker Unified Studio domain. The CDCU workload uses lightweight Processing Jobs invoked on-demand, which do not require a persistent domain or notebook server. This avoids idle costs and VPC complexity.
