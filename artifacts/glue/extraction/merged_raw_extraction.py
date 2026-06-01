import sys

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql.functions import current_date, current_timestamp


args = getResolvedOptions(
    sys.argv,
    [
        "JOB_NAME",
        "SOURCE_CONNECTION",
        "TARGET_S3_PATH",
        "ENVIRONMENT",
        "SECRET_NAME",
    ],
)

sc = SparkContext()
glue_context = GlueContext(sc)
spark = glue_context.spark_session
job = Job(glue_context)
job.init(args["JOB_NAME"], args)

database_name = "cdcu"
table_name = "Employees"
source_table = f"{database_name}.{table_name}"
target_s3_path = args["TARGET_S3_PATH"].rstrip("/") + "/"
source_connection = args["SOURCE_CONNECTION"]

print("========================================")
print("CDCU MYSQL TO S3 RAW EXTRACTION")
print(f"Environment       : {args['ENVIRONMENT']}")
print(f"Source connection : {source_connection}")
print(f"Source table      : {source_table}")
print(f"Target path       : {target_s3_path}")
print("========================================")

try:
    dynamic_frame = glue_context.create_dynamic_frame.from_options(
        connection_type="mysql",
        connection_options={
            "useConnectionProperties": "true",
            "connectionName": source_connection,
            "dbtable": source_table,
        },
    )

    source_df = dynamic_frame.toDF()

    print("Source schema:")
    source_df.printSchema()

    record_count = source_df.count()
    print(f"Source row count: {record_count}")

    if record_count == 0:
        print("Source table has 0 rows. Skipping S3 write and verification.")
    else:
        print("Sample source data:")
        source_df.show(10, truncate=False)

        enriched_df = (
            source_df.withColumn("extraction_date", current_date())
            .withColumn("extraction_timestamp", current_timestamp())
        )

        print(f"Writing extracted data to S3: {target_s3_path}")
        (
            enriched_df.write.mode("overwrite")
            .partitionBy("extraction_date")
            .parquet(target_s3_path)
        )
        print("S3 write completed.")

        verify_df = spark.read.parquet(target_s3_path)
        verify_count = verify_df.count()
        print(f"S3 verification row count: {verify_count}")

        if verify_count == record_count:
            print("S3 verification successful. Source and target row counts match.")
        else:
            print(f"Warning: Row count mismatch. Source={record_count}, S3={verify_count}")

        print("Sample S3 data:")
        verify_df.show(10, truncate=False)

except Exception as exc:
    print("Extraction failed.")
    print(str(exc))
    raise

job.commit()
