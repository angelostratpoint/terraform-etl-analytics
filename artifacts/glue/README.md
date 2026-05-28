# Glue ETL Scripts

Place all AWS Glue ETL scripts here. Scripts are automatically uploaded to S3 during `terraform apply`.

## Expected Scripts

Based on the Glue jobs defined in `modules/glue/main.tf`, you should create:

1. **merged_raw_extraction.py** - Extracts raw customer data from the merged MySQL source.
2. **merged_standardization.py** - Standardizes merged raw data to Parquet.

## Script Template

```python
import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'SOURCE_CONNECTION',
    'TARGET_S3_PATH',
    'ENVIRONMENT',
    'SECRET_NAME'
])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Your ETL logic here

job.commit()
```

## S3 Upload Path

Scripts are uploaded to: `s3://cdcu-{env}-data-lake/{env}/glue-scripts/`

Glue jobs reference them through the `script_location` parameter in `modules/glue/main.tf`.
