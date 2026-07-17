import sys
import re
from urllib.parse import urlparse

import boto3
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import functions as F
from pyspark.sql.types import StringType
 
 
# =============================================================================
# GLUE JOB INITIALIZATION
# =============================================================================
 
def get_optional_arg(name, default=None):
    flag = f"--{name}"
    if flag not in sys.argv:
        return default
    index = sys.argv.index(flag)
    if index + 1 >= len(sys.argv):
        return default
    return sys.argv[index + 1]


def get_bool_arg(name, default=False):
    value = get_optional_arg(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "y"}


def split_s3_uri(s3_uri):
    parsed = urlparse(s3_uri)
    if parsed.scheme != "s3" or not parsed.netloc:
        raise ValueError(f"Expected an s3:// URI, got: {s3_uri}")
    return parsed.netloc, parsed.path.lstrip("/")


def resolve_input_partition(input_path):
    """Return an extraction_date partition path when a raw parent prefix is given."""
    normalized_path = input_path.rstrip("/") + "/"
    if re.search(r"extraction_date=\d{4}-\d{2}-\d{2}/?$", normalized_path):
        return normalized_path

    bucket, prefix = split_s3_uri(normalized_path)
    s3_client = boto3.client("s3")
    response = s3_client.list_objects_v2(
        Bucket=bucket,
        Prefix=prefix,
        Delimiter="/",
    )
    partition_prefixes = [
        item["Prefix"]
        for item in response.get("CommonPrefixes", [])
        if re.search(r"extraction_date=\d{4}-\d{2}-\d{2}/$", item["Prefix"])
    ]
    if not partition_prefixes:
        return normalized_path

    latest_partition = sorted(partition_prefixes)[-1]
    return f"s3://{bucket}/{latest_partition}"


args = getResolvedOptions(sys.argv, ["JOB_NAME"])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

# Re-run for one extraction_date overwrites only that partition.
spark.conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")

# CRITICAL: make date parsing tolerant. With the Spark 3 default (EXCEPTION),
# to_date() THROWS on an invalid/ambiguous date and aborts the job. CORRECTED
# returns NULL instead, so a bad DOB is flagged rather than fatal.
spark.conf.set("spark.sql.legacy.timeParserPolicy", "CORRECTED")
 
 
# =============================================================================
# CONFIGURATION 
# =============================================================================
 


ENVIRONMENT = get_optional_arg("ENVIRONMENT", "uat")
INPUT_PATH = (
    get_optional_arg("INPUT_PATH")
    or get_optional_arg("SOURCE_S3_PATH")
)
OUTPUT_PATH = (
    get_optional_arg("OUTPUT_PATH")
    or get_optional_arg("TARGET_S3_PATH")
)

if not INPUT_PATH or not OUTPUT_PATH:
    raise RuntimeError(
        "Standardization requires INPUT_PATH/OUTPUT_PATH or "
        "SOURCE_S3_PATH/TARGET_S3_PATH Glue arguments."
    )

INPUT_PATH = INPUT_PATH.rstrip("/") + "/"
OUTPUT_PATH = OUTPUT_PATH.rstrip("/") + "/"
RESOLVED_INPUT_PATH = resolve_input_partition(INPUT_PATH)

STANDARDIZE_ADDRESS_TO_UPPERCASE = get_bool_arg("STANDARDIZE_ADDRESS_TO_UPPERCASE", True)
ENABLE_POSTAL_ZERO_PADDING = get_bool_arg("ENABLE_POSTAL_ZERO_PADDING", False)

# SIT compatibility can coalesce to one file. UAT/PROD should allow parallel writes by default.
SINGLE_OUTPUT_FILE = get_bool_arg("SINGLE_OUTPUT_FILE", ENVIRONMENT == "sit")

# Masked suffix mapping from SIT data.
SUFFIX_DECODE = {
    "VV": "II",
    "VVV": "III",
    "VI": "IV",
    "FE": "SR",
    "WE": "JR",
}

REAL_SUFFIXES = ["JR", "SR", "II", "III", "IV"]

# [TUNE: PROD] Change to False when source has real suffixes (JR, SR, II)
SOURCE_SUFFIX_IS_MASKED = False

EMAIL_REGEX = r"^[^@\s]+@[^@\s]+\.[^@\s]+$"
MOBILE_CANONICAL_REGEX = r"^\+639\d{9}$"
TELEPHONE_REGEX = r"^\d{7,10}$"

MIN_PHONE_DIGITS = 4

JUNK_PHONES = [
    "1234567", "12345678", "123456789", "1234567890",
    "9090909090",
]

PLACEHOLDER_VALUES = ["", "none", "nan", "null", "n/a", "na", "-", "--"]

PLACEHOLDER_DOBS = ["00:00.0", "0000-00-00", "0000-00-00 00:00:00"]

ACC_FROM = "\u00d1\u00c1\u00c0\u00c2\u00c4\u00c3\u00c5\u00c9\u00c8\u00ca\u00cb\u00cd\u00cc\u00ce\u00cf\u00d3\u00d2\u00d4\u00d6\u00d5\u00da\u00d9\u00db\u00dc\u00dd\u00c7"
ACC_TO   = "NAAAAAAEEEEIIIIOOOOOUUUUYC"

# Minimum expected rows - catches empty or truncated input from ingestion
MIN_EXPECTED_ROWS = int(get_optional_arg("MIN_EXPECTED_ROWS", "1000"))
 
# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
 
def ensure_column(df, column_name, data_type=StringType()):
    """Add a missing column as NULL so the job won't fail if a field is absent."""
    if column_name not in df.columns:
        return df.withColumn(column_name, F.lit(None).cast(data_type))
    return df


def trim_to_null(col_expr):
    """Trim spaces; blanks / placeholder words -> NULL."""
    trimmed = F.trim(col_expr.cast("string"))
    return (
        F.when(col_expr.isNull(), F.lit(None))
         .when(F.lower(trimmed).isin(PLACEHOLDER_VALUES), F.lit(None))
         .otherwise(trimmed)
    )


def collapse_spaces(col_expr):
    """'JUAN   CARLOS' -> 'JUAN CARLOS'."""
    return F.regexp_replace(col_expr, r"\s{2,}", " ")


def fold_accents(col_expr):
    """N~ -> N, E' -> E, etc. Apply AFTER upper-casing."""
    return F.translate(col_expr, ACC_FROM, ACC_TO)


def build_issue_reason(conditions):
    """Comma-separated list of triggered labels, or 'OK' if none."""
    reason = F.concat_ws(
        ",",
        *[F.when(condition, F.lit(label)) for condition, label in conditions]
    )
    return F.when(F.length(reason) == 0, F.lit("OK")).otherwise(reason)

def is_junk_phone_expr(digits_col):
    """True if the phone is a repeated single digit or a known junk number."""
    repeated = (digits_col != "") & digits_col.rlike(r"^(\d)\1*$")
    subscriber = F.regexp_replace(digits_col, r"^(63|0)", "")
    listed = subscriber.isin(*JUNK_PHONES) if JUNK_PHONES else F.lit(False)
    return repeated | listed


 
# =============================================================================
# FIELD STANDARDIZERS
# =============================================================================
 
def standardize_names(df, surname_col="surname", givenname_col="givenname"):
    """Surname + givenname handled TOGETHER. Suffix is detected, decoded (if
    masked), and moved to the END of the surname as 'SURNAME, JR'."""
    sur_raw = F.col(surname_col)
    giv_raw = F.col(givenname_col)

    masked_keys = list(SUFFIX_DECODE.keys())
    decode_map = F.create_map([F.lit(x) for kv in SUFFIX_DECODE.items() for x in kv])

    detect_set = masked_keys if SOURCE_SUFFIX_IS_MASKED else REAL_SUFFIXES

    sur_base = F.upper(collapse_spaces(F.regexp_replace(trim_to_null(sur_raw), "[.,]", " ")))
    giv_base = F.upper(collapse_spaces(F.regexp_replace(trim_to_null(giv_raw), "[.,]", " ")))

    sur_tok = F.filter(F.split(F.coalesce(sur_base, F.lit("")), " "), lambda x: x != "")
    giv_tok = F.filter(F.split(F.coalesce(giv_base, F.lit("")), " "), lambda x: x != "")

    norm = lambda x: F.regexp_replace(x, r"\.", "")
    is_suffix = lambda x: norm(x).isin(*detect_set)

    sur_2plus = F.size(sur_tok) >= 2
    giv_2plus = F.size(giv_tok) >= 2

    sur_hits = F.filter(sur_tok, lambda x: is_suffix(x))
    giv_hits = F.filter(giv_tok, lambda x: is_suffix(x))
    sur_has_suffix = sur_2plus & (F.size(sur_hits) > 0)
    giv_has_suffix = giv_2plus & (F.size(giv_hits) > 0)

    found = F.coalesce(
        F.when(sur_has_suffix, norm(F.element_at(sur_hits, -1))),
        F.when(giv_has_suffix, norm(F.element_at(giv_hits, -1))),
    )
    suffix = F.coalesce(F.element_at(decode_map, found), found)

    sur_keep = F.when(sur_2plus, F.filter(sur_tok, lambda x: ~is_suffix(x))).otherwise(sur_tok)
    giv_keep = F.when(giv_2plus, F.filter(giv_tok, lambda x: ~is_suffix(x))).otherwise(giv_tok)

    sur_name = F.when(F.size(sur_keep) > 0, F.array_join(sur_keep, " ")).otherwise(F.lit(None))
    giv_name = F.when(F.size(giv_keep) > 0, F.array_join(giv_keep, " ")).otherwise(F.lit(None))

    sur_junk = sur_name.isNotNull() & ~sur_name.rlike("[A-Z]")
    giv_junk = giv_name.isNotNull() & ~giv_name.rlike("[A-Z]")
    sur_name = F.when(sur_junk, F.lit(None)).otherwise(sur_name)
    giv_name = F.when(giv_junk, F.lit(None)).otherwise(giv_name)

    surname_clean = (
        F.when(suffix.isNotNull() & sur_name.isNotNull(), F.concat(sur_name, F.lit(", "), suffix))
         .when(suffix.isNotNull(), suffix)
         .otherwise(sur_name)
    )

    sur_folded = fold_accents(F.upper(F.coalesce(sur_raw.cast("string"), F.lit(""))))
    giv_folded = fold_accents(F.upper(F.coalesce(giv_raw.cast("string"), F.lit(""))))

    surname_flag = build_issue_reason([
        (sur_raw.isNull() | F.lower(F.trim(sur_raw.cast("string"))).isin(PLACEHOLDER_VALUES), "MISSING"),
        (sur_raw.cast("string") != F.ltrim(sur_raw.cast("string")), "LEADING_SPACE"),
        (sur_raw.cast("string") != F.rtrim(sur_raw.cast("string")), "TRAILING_SPACE"),
        (sur_raw.rlike(r"\S\s{2,}\S"), "DOUBLE_SPACE_BETWEEN_WORDS"),
        (sur_folded.rlike(r"[^A-Z ,.'-]"), "SUSPICIOUS_SYMBOL"),
        (sur_junk, "NAME_NO_LETTER"),
        (sur_has_suffix, "SUFFIX_EXTRACTED"),
    ])
    givenname_flag = build_issue_reason([
        (giv_raw.isNull() | F.lower(F.trim(giv_raw.cast("string"))).isin(PLACEHOLDER_VALUES), "MISSING"),
        (giv_raw.cast("string") != F.ltrim(giv_raw.cast("string")), "LEADING_SPACE"),
        (giv_raw.cast("string") != F.rtrim(giv_raw.cast("string")), "TRAILING_SPACE"),
        (giv_raw.rlike(r"\S\s{2,}\S"), "DOUBLE_SPACE_BETWEEN_WORDS"),
        (giv_folded.rlike(r"[^A-Z ,.'-]"), "SUSPICIOUS_SYMBOL"),
        (giv_junk, "NAME_NO_LETTER"),
        (giv_has_suffix, "SUFFIX_EXTRACTED"),
    ])

    return (
        df.withColumn("surname_clean", surname_clean)
          .withColumn("surname_suffix", suffix)
          .withColumn("surname_dq_flag", surname_flag)
          .withColumn("givenname_clean", giv_name)
          .withColumn("givenname_suffix", F.lit(None).cast("string"))
          .withColumn("givenname_dq_flag", givenname_flag)
    )


def standardize_dob(df, col_name="dob"):
    """Parseable dates -> YYYYMMDD. Unparseable kept as-is. Junk -> NULL."""
    raw = trim_to_null(F.col(col_name))
    digits = F.regexp_replace(F.coalesce(raw, F.lit("")), r"[^0-9]", "")
    date_prefix = F.regexp_extract(raw, r"^(\d{4}-\d{2}-\d{2})", 1)

    parsed_dob = F.coalesce(
        F.to_date(raw, "yyyy-MM-dd"),
        F.to_date(raw, "yyyyMMdd"),
        F.to_date(raw, "MM/dd/yyyy"),
        F.to_date(raw, "dd/MM/yyyy"),
        F.to_date(raw, "MM-dd-yyyy"),
        F.to_date(raw, "dd-MM-yyyy"),
        F.to_date(date_prefix, "yyyy-MM-dd"),
    )

    is_text_ph    = F.lower(raw).isin(PLACEHOLDER_VALUES)
    is_listed_ph  = F.lower(F.trim(F.col(col_name).cast("string"))).isin(PLACEHOLDER_DOBS)
    is_repeated   = (digits != "") & digits.rlike(r"^(\d)\1*$")
    is_junk       = raw.isNull() | is_text_ph | is_listed_ph | is_repeated

    dob_clean_value = (
        F.when(is_junk, F.lit(None))
         .when(parsed_dob.isNotNull(), F.date_format(parsed_dob, "yyyyMMdd"))
         .otherwise(raw)
    )

    dob_flag = (
        F.when(raw.isNull(), "DOB_MISSING")
         .when(is_text_ph | is_listed_ph | is_repeated, "DOB_PLACEHOLDER_OR_SUSPECT")
         .when(parsed_dob.isNull(), "DOB_INVALID_FORMAT")
         .when(parsed_dob > F.current_date(), "DOB_FUTURE_DATE")
         .otherwise("OK")
    )

    return (
        df
        .withColumn("dob_clean", dob_clean_value)
        .withColumn("dob_dq_flag", dob_flag)
    )


def standardize_address(df, col_name="address"):
    """Trim, collapse spaces, upper-case + fold accents. Symbols kept."""
    raw = F.col(col_name)
    base = trim_to_null(raw)
    cleaned = collapse_spaces(base)
    if STANDARDIZE_ADDRESS_TO_UPPERCASE:
        cleaned = F.upper(cleaned)

    issue_reason = build_issue_reason([
        (base.isNull(), "ADDRESS_MISSING_OR_PLACEHOLDER"),
        (raw.cast("string") != F.ltrim(raw.cast("string")), "LEADING_SPACE"),
        (raw.cast("string") != F.rtrim(raw.cast("string")), "TRAILING_SPACE"),
        (raw.rlike(r"\S\s{2,}\S"), "DOUBLE_SPACE_BETWEEN_WORDS"),
    ])

    return df.withColumn("address_clean", cleaned).withColumn("address_dq_flag", issue_reason)


def standardize_email(df, col_name="email"):
    """Extract first valid email from potentially messy input."""
    base = trim_to_null(F.col(col_name))

    parts = F.transform(
        F.split(F.coalesce(base, F.lit("")), r"[;:,/]"),
        lambda x: F.lower(F.trim(x))
    )
    valid_parts = F.filter(parts, lambda x: (x != "") & x.rlike(EMAIL_REGEX))

    sub_parts = F.flatten(F.transform(
        F.filter(parts, lambda x: (x != "") & x.contains("@") & ~x.rlike(EMAIL_REGEX)),
        lambda x: F.filter(F.split(x, r"\s+"), lambda y: y.rlike(EMAIL_REGEX))
    ))

    cleaned = (
        F.when(base.isNull(), F.lit(None))
         .when(F.size(valid_parts) > 0, F.element_at(valid_parts, 1))
         .when(F.size(sub_parts)   > 0, F.element_at(sub_parts, 1))
         .otherwise(F.lower(base))
    )
    cleaned = F.when(cleaned == "", F.lit(None)).otherwise(cleaned)

    email_flag = (
        F.when(cleaned.isNull(), "EMAIL_MISSING")
         .when(~cleaned.rlike(EMAIL_REGEX), "EMAIL_INVALID_FORMAT")
         .otherwise("OK")
    )
    return (
        df.withColumn("email_clean", cleaned)
          .withColumn("email_valid", cleaned.rlike(EMAIL_REGEX))
          .withColumn("email_dq_flag", email_flag)
    )

def normalize_ph_mobile_expr(raw_col):
    """Normalise a PH mobile to +639XXXXXXXXX, else NULL."""
    raw = trim_to_null(raw_col)
    digits = F.regexp_replace(raw, r"[^0-9]", "")
    return (
        F.when(raw.isNull(), F.lit(None))
         .when(digits.rlike(r"^09\d{9}$"), F.concat(F.lit("+63"), F.substring(digits, 2, 10)))
         .when(digits.rlike(r"^9\d{9}$"), F.concat(F.lit("+63"), digits))
         .when(digits.rlike(r"^639\d{9}$"), F.concat(F.lit("+"), digits))
         .otherwise(F.lit(None))
    )


def standardize_mobile(df, col_name="mobileno"):
    """Valid PH mobile -> +639XXXXXXXXX. Non-mobile kept as digits. Junk -> NULL."""
    base = trim_to_null(F.col(col_name))
    digits = F.regexp_replace(base, r"[^0-9]", "")
    normalized = normalize_ph_mobile_expr(F.col(col_name))
    is_junk = is_junk_phone_expr(digits)

    cleaned = (
        F.when(base.isNull() | (digits == ""), F.lit(None))
         .when(is_junk, F.lit(None))
         .when(normalized.isNotNull(), normalized)
         .when(F.length(digits) >= MIN_PHONE_DIGITS, digits)
         .otherwise(F.lit(None))
    )
    is_valid = cleaned.rlike(MOBILE_CANONICAL_REGEX)
    mobile_flag = (
        F.when(base.isNull(), "MOBILE_MISSING")
         .when(is_junk, "MOBILE_JUNK")
         .when(is_valid, "OK")
         .otherwise("MOBILE_INVALID_FORMAT_OR_LENGTH")
    )
    return (
        df.withColumn("mobileno_clean", cleaned)
          .withColumn("mobileno_valid", is_valid)
          .withColumn("mobileno_dq_flag", mobile_flag)
    )


def standardize_postal(df, col_name="postal"):
    """Keep digits, zero-pad short codes, validate 4-digit PH postal code."""
    base = trim_to_null(F.col(col_name))
    digits = F.regexp_replace(base, r"[^0-9]", "")
    if ENABLE_POSTAL_ZERO_PADDING:
        digits = F.when(F.length(digits).between(1, 3), F.lpad(digits, 4, "0")).otherwise(digits)

    is_valid = digits.rlike(r"^\d{4}$") & (digits != "0000")
    cleaned = F.when(base.isNull() | (digits == ""), F.lit(None)).otherwise(digits)

    postal_flag = (
        F.when(base.isNull(), "POSTAL_MISSING")
         .when(is_valid, "OK")
         .otherwise("POSTAL_INVALID_FORMAT")
    )
    return (
        df.withColumn("postal_clean", cleaned)
          .withColumn("postal_valid", is_valid)
          .withColumn("postal_dq_flag", postal_flag)
    )


def normalize_contact_number(df, col_name):
    """Home / office number: mobile -> +63, landline -> digits, junk -> NULL."""
    base = trim_to_null(F.col(col_name))
    digits = F.regexp_replace(base, r"[^0-9]", "")
    mobile_clean = normalize_ph_mobile_expr(F.col(col_name))
    is_junk = is_junk_phone_expr(digits)

    contact_clean = (
        F.when(base.isNull(), F.lit(None))
         .when(is_junk, F.lit(None))
         .when(mobile_clean.isNotNull(), mobile_clean)
         .when(F.length(digits) >= MIN_PHONE_DIGITS, digits)
         .otherwise(F.lit(None))
    )
    contact_type = (
        F.when(base.isNull(), "MISSING")
         .when(is_junk, "JUNK")
         .when(mobile_clean.isNotNull(), "MOBILE")
         .when(digits.rlike(TELEPHONE_REGEX), "TELEPHONE")
         .when(F.length(digits) >= MIN_PHONE_DIGITS, "OTHER")
         .otherwise("INVALID")
    )
    return (
        df.withColumn(f"{col_name}_clean", contact_clean)
          .withColumn(f"{col_name}_type", contact_type)
          .withColumn(f"{col_name}_dq_flag",
                      F.when(contact_type.isin("MOBILE", "TELEPHONE"), "OK").otherwise(contact_type))
    )
 
 
# =============================================================================
# READ DATA
# =============================================================================
 
try:
    print(f"Configured input path: {INPUT_PATH}")
    print(f"Resolved input path  : {RESOLVED_INPUT_PATH}")
    reader = spark.read
    if RESOLVED_INPUT_PATH != INPUT_PATH:
        reader = reader.option("basePath", INPUT_PATH)
    raw_df = reader.parquet(RESOLVED_INPUT_PATH)
except Exception as e:
    raise RuntimeError(
        f"Failed to read input from {RESOLVED_INPUT_PATH}\n"
        f"Error: {e}\n"
        f"Check: ingestion job ran successfully, S3 path is correct."
    ) from e

input_count = raw_df.count()
print(f"Read {input_count:,} rows from {RESOLVED_INPUT_PATH}")

# Guard: zero rows from ingestion
if input_count == 0:
    raise RuntimeError(
        f"Zero rows in input {RESOLVED_INPUT_PATH}. "
        f"Check if the ingestion job completed successfully."
    )

# Guard: suspiciously low row count
if input_count < MIN_EXPECTED_ROWS:
    print(f"  WARNING: Only {input_count:,} rows (expected >= {MIN_EXPECTED_ROWS:,}). "
          f"Possible ingestion truncation.")

expected_cols = [
    "id", "client_no", "surname", "givenname", "address", "tin", "dob",
    "email", "gender", "civil_status", "mobileno", "homeno", "officeno",
    "source", "inserted_at", "timestamp", "postal", "contract_type",
]
for col_name in expected_cols:
    raw_df = ensure_column(raw_df, col_name)

_m = re.search(r"extraction_date=(\d{4}-\d{2}-\d{2})", RESOLVED_INPUT_PATH)
extraction_date_col = F.to_date(F.lit(_m.group(1))) if _m else F.current_date()

df = raw_df.select(
    "id", "client_no", "surname", "givenname", "address", "tin", "dob",
    "email", "gender", "civil_status", "mobileno", "homeno", "officeno",
    "source", "inserted_at",
    F.col("timestamp").alias("event_timestamp"),
    "postal", "contract_type",
).withColumn(
    "extraction_date", extraction_date_col
).withColumn(
    "standardization_timestamp", F.current_timestamp()
)
 
 
# =============================================================================
# STANDARDIZATION / CLEANING
# =============================================================================

try:
    clean_df = df
    clean_df = standardize_names(clean_df, "surname", "givenname")
    clean_df = standardize_dob(clean_df, "dob")
    clean_df = standardize_address(clean_df, "address")
    clean_df = standardize_email(clean_df, "email")
    clean_df = standardize_mobile(clean_df, "mobileno")
    clean_df = standardize_postal(clean_df, "postal")
    clean_df = normalize_contact_number(clean_df, "homeno")
    clean_df = normalize_contact_number(clean_df, "officeno")


    # =============================================================================
    # VALIDATION (counts only - no PII in logs)
    # =============================================================================

    print("\n================ CLEANING VALIDATION ================\n")

    validation_df = clean_df.select(
        F.count("*").alias("total_records"),
        F.count(F.when(F.col("surname_clean").isNull(), 1)).alias("surname_clean_nulls"),
        F.count(F.when(F.col("givenname_clean").isNull(), 1)).alias("givenname_clean_nulls"),
        F.count(F.when(F.col("surname_dq_flag") != "OK", 1)).alias("surname_flagged_count"),
        F.count(F.when(F.col("givenname_dq_flag") != "OK", 1)).alias("givenname_flagged_count"),
        F.count(F.when(F.col("dob_dq_flag") != "OK", 1)).alias("dob_flagged_count"),
        F.count(F.when(F.col("address_dq_flag") != "OK", 1)).alias("address_flagged_count"),
        F.count(F.when(F.col("email_dq_flag") != "OK", 1)).alias("email_flagged_count"),
        F.count(F.when(F.col("mobileno_dq_flag") != "OK", 1)).alias("mobileno_flagged_count"),
        F.count(F.when(F.col("postal_dq_flag") != "OK", 1)).alias("postal_flagged_count"),
        F.count(F.when(F.col("homeno_dq_flag") != "OK", 1)).alias("homeno_flagged_count"),
        F.count(F.when(F.col("officeno_dq_flag") != "OK", 1)).alias("officeno_flagged_count"),
    )
    validation_df.show(truncate=False)


    # =============================================================================
    # RENAME COLUMNS FOR OUTPUT
    # =============================================================================

    RENAME_FIELDS = [
        "surname", "givenname", "address", "dob",
        "email", "mobileno", "postal", "homeno", "officeno",
    ]
    for _f in RENAME_FIELDS:
        clean_df = (clean_df
                    .withColumnRenamed(_f, _f + "_raw")
                    .withColumnRenamed(_f + "_clean", _f))


    # =============================================================================
    # WRITE OUTPUT TO S3
    # =============================================================================

    print(f"Writing standardized data to: {OUTPUT_PATH}")

    writer = clean_df.coalesce(1) if SINGLE_OUTPUT_FILE else clean_df
    (writer.write
        .mode("overwrite")
        .partitionBy("extraction_date")
        .option("compression", "snappy")
        .parquet(OUTPUT_PATH))

    # Guard: verify output row count matches input
    output_count = spark.read.parquet(OUTPUT_PATH).count()
    if output_count != input_count:
        print(f"  WARNING: Row count mismatch. Input={input_count:,}, Output={output_count:,}")
    else:
        print(f"  Row count verified: {output_count:,} rows OK")

    print(f"Standardization completed successfully.")
    print(f"  Input: {input_count:,} rows from {RESOLVED_INPUT_PATH}")
    print(f"  Output: {output_count:,} rows to {OUTPUT_PATH}")
    print(f"  Suffix mode: {'masked (SIT)' if SOURCE_SUFFIX_IS_MASKED else 'real (PROD)'}")

except Exception as e:
    print(f"STANDARDIZATION FAILED: {e}")
    print(f"Error type: {type(e).__name__}")
    raise e

job.commit()
print(f"Glue job committed: {args['JOB_NAME']}")
