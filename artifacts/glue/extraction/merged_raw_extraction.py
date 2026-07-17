"""Extract a BPI-MS MySQL source table into the CDCU raw S3 layer."""

import sys
from datetime import datetime

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql.functions import current_timestamp, lit
from pyspark.sql.types import IntegerType, LongType, StringType, StructField, StructType


def get_optional_arg(name, default):
    flag = f"--{name}"
    if flag not in sys.argv:
        return default
    index = sys.argv.index(flag)
    if index + 1 >= len(sys.argv):
        return default
    return sys.argv[index + 1]


args = getResolvedOptions(
    sys.argv,
    [
        "JOB_NAME",
        "SOURCE_CONNECTION",
        "TARGET_S3_PATH",
        "ENVIRONMENT",
    ],
)

source_table = get_optional_arg("SOURCE_TABLE", "customers")
min_expected_rows = int(get_optional_arg("MIN_EXPECTED_ROWS", "1000"))
coalesce_files = int(get_optional_arg("COALESCE_FILES", "1"))

sc = SparkContext()
glue_context = GlueContext(sc)
spark = glue_context.spark_session
job = Job(glue_context)
job.init(args["JOB_NAME"], args)

connection_name = args["SOURCE_CONNECTION"]
target_s3_path = args["TARGET_S3_PATH"].rstrip("/")
environment = args["ENVIRONMENT"]
extraction_date = datetime.now().strftime("%Y-%m-%d")

expected_columns = [
    "id",
    "client_no",
    "surname",
    "givenname",
    "address",
    "tin",
    "dob",
    "email",
    "gender",
    "civil_status",
    "mobileno",
    "homeno",
    "officeno",
    "source",
    "inserted_at",
    "timestamp",
    "postal",
    "contract_type",
]

print("========================================")
print("CDCU MYSQL TO S3 RAW EXTRACTION")
print(f"Job name          : {args['JOB_NAME']}")
print(f"Environment       : {environment}")
print(f"Source connection : {connection_name}")
print(f"Source table      : {source_table}")
print(f"Extraction date   : {extraction_date}")
print(f"Target path       : {target_s3_path}")
print(f"Coalesce files    : {coalesce_files}")
print("========================================")

try:
    print(f"Reading data from MySQL table: {source_table}")
    mysql_dynamic_frame = glue_context.create_dynamic_frame.from_options(
        connection_type="mysql",
        connection_options={
            "useConnectionProperties": "true",
            "connectionName": connection_name,
            "dbtable": source_table,
        },
    )

    source_df = mysql_dynamic_frame.toDF()
    record_count = source_df.count()
    print(f"Successfully read {record_count:,} records from {source_table}")

    if record_count == 0:
        raise RuntimeError(
            f"Zero rows returned from {source_table}. Check source data, "
            f"connection {connection_name}, and source schema/database."
        )

    if record_count < min_expected_rows:
        print(
            f"WARNING: Only {record_count:,} rows found "
            f"(expected >= {min_expected_rows:,}). Possible truncation or wrong table."
        )

    missing_columns = [column for column in expected_columns if column not in source_df.columns]
    if missing_columns:
        raise RuntimeError(
            f"Source table missing expected columns: {missing_columns}\n"
            f"Available columns: {source_df.columns}\n"
            "Check if the source DDL matches expectations."
        )

    extra_columns = [column for column in source_df.columns if column not in expected_columns]
    if extra_columns:
        print(f"INFO: Source has extra columns that will be passed through: {extra_columns}")

    enriched_df = (
        source_df.withColumn("extraction_date", lit(extraction_date).cast(StringType()))
        .withColumn("extraction_timestamp", current_timestamp())
        .withColumn("source_table", lit(source_table).cast(StringType()))
        .withColumn("source_connection", lit(connection_name).cast(StringType()))
    )

    table_output_path = target_s3_path
    print(f"Writing extracted data to S3: {table_output_path}")

    (
        enriched_df.coalesce(coalesce_files)
        .write.mode("overwrite")
        .partitionBy("extraction_date")
        .option("compression", "snappy")
        .parquet(table_output_path)
    )

    verify_count = spark.read.parquet(table_output_path).count()
    if verify_count != record_count:
        print(
            f"WARNING: Write verification mismatch. "
            f"Source={record_count:,}, Written={verify_count:,}"
        )
    else:
        print(f"Write verified: {verify_count:,} rows in S3")

    summary_schema = StructType(
        [
            StructField("extraction_date", StringType(), True),
            StructField("extraction_timestamp", StringType(), True),
            StructField("job_name", StringType(), True),
            StructField("source_table", StringType(), True),
            StructField("source_connection", StringType(), True),
            StructField("record_count", LongType(), True),
            StructField("column_count", IntegerType(), True),
            StructField("s3_output_path", StringType(), True),
            StructField("extraction_status", StringType(), True),
        ]
    )
    summary_data = [
        (
            extraction_date,
            datetime.now().isoformat(),
            args["JOB_NAME"],
            source_table,
            connection_name,
            record_count,
            len(source_df.columns),
            table_output_path,
            "success",
        )
    ]
    summary_df = spark.createDataFrame(summary_data, summary_schema)
    summary_path = f"{target_s3_path}/_metadata/extractions/{source_table}/date={extraction_date}"
    (
        summary_df.coalesce(1)
        .write.mode("overwrite")
        .option("compression", "snappy")
        .parquet(summary_path)
    )

    print("EXTRACTION COMPLETED SUCCESSFULLY")
    print(f"  Table: {source_table}")
    print(f"  Records: {record_count:,}")
    print(f"  Date: {extraction_date}")
    print(f"  S3 location: {table_output_path}")

except Exception as exc:
    print(f"JOB FAILED WITH ERROR: {str(exc)}")
    print(f"Error type: {type(exc).__name__}")

    try:
        error_schema = StructType(
            [
                StructField("extraction_date", StringType(), True),
                StructField("extraction_timestamp", StringType(), True),
                StructField("job_name", StringType(), True),
                StructField("source_table", StringType(), True),
                StructField("extraction_status", StringType(), True),
                StructField("error_message", StringType(), True),
                StructField("error_type", StringType(), True),
            ]
        )
        error_data = [
            (
                extraction_date,
                datetime.now().isoformat(),
                args["JOB_NAME"],
                source_table,
                "failed",
                str(exc),
                type(exc).__name__,
            )
        ]
        error_df = spark.createDataFrame(error_data, error_schema)
        error_path = f"{target_s3_path}/_metadata/errors/{source_table}/date={extraction_date}"
        error_df.write.mode("overwrite").option("compression", "snappy").parquet(error_path)
        print(f"Error details saved to: {error_path}")
    except Exception as save_error:
        print(f"Could not save error details: {str(save_error)}")

    raise

finally:
    job.commit()
    print(f"Glue job committed: {args['JOB_NAME']}")
