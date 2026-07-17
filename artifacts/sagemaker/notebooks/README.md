# SageMaker Notebook Artifacts

Terraform uploads notebooks in this directory to:

```text
s3://{scripts_bucket}/{environment}/sagemaker-notebooks/{filename}
```

## Production Matching Notebook

`Matching_prod.ipynb` is the current DE matching notebook artifact for the
CDCU SageMaker matching flow. It is prepared from the notebook provided by the
DE team and adjusted only to remove SIT-specific hard-coded paths.

Default runtime paths:

```text
input  = s3://cdcu-{environment}-data-lake/standardized/merged/
output = s3://cdcu-{environment}-data-lake/processed/matching/
```

The notebook writes crawler-friendly partitioned Parquet outputs under:

```text
processed/matching/merge_sagemaker/run_date=...
processed/matching/eyeball_sagemaker/run_date=...
processed/matching/unique_sagemaker/run_date=...
processed/matching/merge_survivors_sagemaker/run_date=...
processed/matching/deduped_input_sagemaker/run_date=...
processed/matching/clusters_sagemaker/run_date=...
```

Override these variables in SageMaker Studio when validating a legacy SIT path:

```text
CDCU_ENVIRONMENT
CDCU_DATA_LAKE_BUCKET
CDCU_STANDARDIZED_S3_URI
CDCU_MATCHING_OUTPUT_S3_URI
```

Regenerate the repo-managed copy after replacing the source notebook in
Downloads:

```bash
python scripts/prepare_matching_notebook_artifact.py
```

The same helper also exports the notebook code to
`artifacts/sagemaker/processing/matching_prod.py`, which is the default
processing script used by the optional Terraform-managed SageMaker Pipeline.

The migrated `sagemaker-s3-input-output.ipynb` derives the sandbox data-lake
bucket name from the active AWS account. Override `CDCU_DATA_LAKE_BUCKET`,
`CDCU_SOURCE_S3_URI`, or `CDCU_TARGET_S3_URI` in the notebook environment when
using different bucket names or prefixes.

The notebook is uploaded as an artifact only. It does not create or start a
JupyterLab application and therefore does not add compute charges by itself.

For SageMaker Studio JupyterLab, Terraform attaches a lifecycle configuration
that synchronizes this S3 prefix into `~/cdcu-managed/notebooks/` when the app
starts. The directory is Terraform-managed; files absent from S3 are removed
during synchronization.

After startup, the lifecycle checks S3 every 60 seconds. Code-only changes are
deployed by `.github/workflows/sagemaker-artifact-sync.yml` on a push to `main`;
they do not require a full Terraform apply. Treat `~/cdcu-managed/` as read-only
deployment output and commit source changes under `artifacts/sagemaker/`.

For environments that do not use GitHub Actions, run
`scripts/deploy-sagemaker-artifacts.sh <environment>` or use the included VS
Code task. It uploads the same managed S3 prefixes directly with the AWS CLI.
