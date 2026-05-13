# CDCU Artifacts Directory

This directory contains all Data Engineering artifacts that are automatically deployed to S3 during `terraform apply`.

## Directory Structure

```
artifacts/
├── glue/              # AWS Glue ETL scripts (Python)
├── sagemaker/         # SageMaker processing scripts (Python)
├── matching/          # Customer matching logic (Python)
└── sql/               # Athena SQL queries and views
```

## How It Works

1. **Add your scripts** to the appropriate subdirectory
2. **Commit and push** to the repository
3. **Run terraform apply** — the `artifacts` module automatically uploads all files to S3
4. **Scripts are versioned** using MD5 hashes — Terraform only uploads changed files

## S3 Upload Paths

Artifacts are uploaded to environment-specific prefixes:

| Local Path | S3 Path (pre-prod) | S3 Path (prod) |
|------------|-------------------|----------------|
| `glue/*.py` | `s3://cdcu-pre-prod-data-lake/pre-prod/glue-scripts/` | `s3://cdcu-prod-data-lake/prod/glue-scripts/` |
| `sagemaker/*.py` | `s3://cdcu-pre-prod-data-lake/pre-prod/sagemaker-scripts/` | `s3://cdcu-prod-data-lake/prod/sagemaker-scripts/` |
| `matching/*.py` | `s3://cdcu-pre-prod-data-lake/pre-prod/matching-scripts/` | `s3://cdcu-prod-data-lake/prod/matching-scripts/` |
| `sql/*.sql` | `s3://cdcu-pre-prod-data-lake/pre-prod/sql/` | `s3://cdcu-prod-data-lake/prod/sql/` |

## Naming Conventions

- **Glue scripts**: `{source}_{stage}.py` (e.g., `microsite_raw_extraction.py`, `legacy_standardization.py`)
- **SageMaker scripts**: `{purpose}.py` (e.g., `matching_processor.py`, `data_quality_check.py`)
- **Matching scripts**: `{algorithm}.py` (e.g., `fuzzy_name_matcher.py`, `blocking_rules.py`)
- **SQL files**: `{purpose}.sql` (e.g., `create_matching_view.sql`, `validate_counts.sql`)

## Subdirectory Organization

You can organize scripts into subdirectories:

```
glue/
├── extraction/
│   ├── microsite_raw_extraction.py
│   └── legacy_raw_extraction.py
└── standardization/
    ├── microsite_standardization.py
    └── legacy_standardization.py
```

The S3 path will preserve the subdirectory structure:
- `s3://bucket/pre-prod/glue-scripts/extraction/microsite_raw_extraction.py`
- `s3://bucket/pre-prod/glue-scripts/standardization/microsite_standardization.py`

## Artifact Versioning

Each file is tagged with its MD5 hash. Terraform uses the `etag` attribute to detect changes:
- **File unchanged** → Terraform skips upload
- **File modified** → Terraform uploads new version

## Viewing Uploaded Artifacts

After `terraform apply`, check the output:

```
Outputs:

artifacts_uploaded = {
  glue      = 4
  matching  = 2
  sagemaker = 1
  sql       = 3
}
```

## Best Practices

1. **Test locally first** — validate scripts before committing
2. **Use meaningful names** — script names should describe their purpose
3. **Add docstrings** — document what each script does
4. **Version control** — commit scripts alongside infrastructure changes
5. **Review before merge** — PR reviews should include artifact changes

## Troubleshooting

**Q: My script isn't uploading**  
A: Check that the file extension matches the pattern (`.py` for Python, `.sql` for SQL)

**Q: How do I delete an artifact from S3?**  
A: Delete the file from this directory and run `terraform apply` — Terraform will remove it from S3

**Q: Can I upload non-Python/SQL files?**  
A: Yes — update `modules/artifacts/main.tf` to add new file patterns using `fileset()`
