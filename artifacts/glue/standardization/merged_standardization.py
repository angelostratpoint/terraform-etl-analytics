import sys

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql.functions import col, current_timestamp, trim


args = getResolvedOptions(
    sys.argv,
    [
        "JOB_NAME",
        "SOURCE_S3_PATH",
        "TARGET_S3_PATH",
        "ENVIRONMENT",
    ],
)

sc = SparkContext()
glue_context = GlueContext(sc)
spark = glue_context.spark_session
job = Job(glue_context)
job.init(args["JOB_NAME"], args)

source_s3_path = args["SOURCE_S3_PATH"].rstrip("/") + "/"
target_s3_path = args["TARGET_S3_PATH"].rstrip("/") + "/"

print("========================================")
print("CDCU MERGED STANDARDIZATION")
print(f"Environment : {args['ENVIRONMENT']}")
print(f"Source path : {source_s3_path}")
print(f"Target path : {target_s3_path}")
print("========================================")

try:
    source_df = spark.read.parquet(source_s3_path)

    print("Source schema:")
    source_df.printSchema()

    record_count = source_df.count()
    print(f"Source row count: {record_count}")

    if record_count == 0:
        print("Source path has 0 rows. Skipping standardized write.")
    else:
        standardized_df = source_df

        for field in standardized_df.schema.fields:
            if field.dataType.simpleString() == "string":
                standardized_df = standardized_df.withColumn(field.name, trim(col(field.name)))

        standardized_df = standardized_df.withColumn(
            "standardization_timestamp",
            current_timestamp(),
        )

        print(f"Writing standardized data to S3: {target_s3_path}")
        standardized_df.write.mode("overwrite").parquet(target_s3_path)
        print("Standardized S3 write completed.")

        verify_df = spark.read.parquet(target_s3_path)
        verify_count = verify_df.count()
        print(f"Standardized verification row count: {verify_count}")

        if verify_count == record_count:
            print("Standardization verification successful. Source and target row counts match.")
        else:
            print(f"Warning: Row count mismatch. Source={record_count}, Target={verify_count}")

except Exception as exc:
    print("Standardization failed.")
    print(str(exc))
    raise

job.commit()
