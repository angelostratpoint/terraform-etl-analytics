# CDCU Source-to-Target Standardization Checklist

This document is for DA/DE ownership once Glue standardization scripts are developed.
Terraform provisions the Glue jobs, S3 prefixes, and script upload locations, but the data cleanup rules and source-to-target mapping logic belong to the DA/DE implementation.

## Current Terraform S3 Layout

The current Terraform data lake bucket is:

```text
s3://cdcu-{env}-data-lake/
```

Terraform currently creates these data prefixes:

```text
s3://cdcu-{env}-data-lake/raw/microsite/
s3://cdcu-{env}-data-lake/raw/legacy/
s3://cdcu-{env}-data-lake/standardized/microsite/
s3://cdcu-{env}-data-lake/standardized/legacy/
s3://cdcu-{env}-data-lake/processed/matching/merge/
s3://cdcu-{env}-data-lake/processed/matching/unique/
s3://cdcu-{env}-data-lake/processed/matching/manual_review/
```

Do not hardcode bucket names inside Glue scripts. Use the Glue job arguments passed by
Terraform, such as `--SOURCE_S3_PATH` and `--TARGET_S3_PATH`.

## Expected Glue Standardization Scripts

DA/DE should provide these files before standardization jobs are run:

```text
artifacts/glue/standardization/microsite_standardization.py
artifacts/glue/standardization/legacy_standardization.py
```

Terraform uploads these files to:

```text
s3://cdcu-{env}-data-lake/{env}/glue-scripts/standardization/
```

## Source-to-Target Cleanup Checklist

| Field | Standardization rule |
|---|---|
| Client Number | Trim spaces, remove invalid hidden characters, preserve leading zeroes if applicable. |
| Given Name | Trim extra spaces, remove double spaces, standardize casing, remove unnecessary symbols if applicable. |
| Address | Trim spaces, remove double spaces, standardize casing, normalize common abbreviations if required. |
| Postal | Trim spaces, validate expected postal format, keep as string to preserve leading zeroes. |
| Date of Birth | Parse to standard date format, preferably `YYYY-MM-DD`; flag invalid or unparseable dates. |
| Email Address | Lowercase, trim spaces, validate email format, remove unnecessary spaces. |
| Mobile Number | Remove spaces, dashes, parentheses, and symbols; standardize to local PH format or agreed format. |
| Telephone Home | Remove spaces/symbols, standardize number format, allow null if not available. |
| Telephone Office | Remove spaces/symbols, standardize number format, allow null if not available. |
| Source System Identifier | Populate as `Legacy` or `Microsite` depending on the source dataset. |

## Output Expectations

Standardization scripts should write clean, typed, queryable outputs to the standardized
prefixes in Parquet unless DA/DE and BPI MS approve another format.

Recommended output behavior:

- Preserve source record identifiers required for reconciliation.
- Add or preserve `source_system` with values `Legacy` or `Microsite`.
- Keep postal codes and client numbers as strings when leading zeroes may matter.
- Write invalid or rejected records to an agreed error/reconciliation location.
- Avoid logging raw PII values in Glue logs.
- Keep transformations deterministic and documented in code comments or a mapping sheet.

## Ownership Boundary

| Area | Owner |
|---|---|
| S3 bucket and prefixes | Terraform / Cloud Engineering |
| Glue job definitions and job arguments | Terraform / Cloud Engineering |
| Standardization business rules | DA/DE |
| Glue script implementation | DA/DE |
| Field mapping approval | DA/DE with BPI MS validation |
| PII handling, retention, and masking decisions | BPI MS governance |
