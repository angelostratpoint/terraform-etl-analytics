# CDCU Production Deployment MOP and Operational Runbook

## Document Status

This runbook is a production promotion draft. Use it as the production MOP
only after UAT validation is accepted and BPI-MS approves the production change.

Recommended repository location:

```text
docs/prod-deployment-mop-runbook.md
```

This document complements, but does not replace, the existing CDCU Terraform
documentation:

| Reference | Purpose |
|---|---|
| `deployment-guide.md` | High-level repository deployment guidance |
| `docs/deployment-guide.md` | Environment deployment prerequisites and Terraform run flow |
| `docs/bootstrap-guide.md` | One-time Terraform backend setup |
| `docs/terraform-vpc-production-readiness.md` | Production architecture, VPC baseline, and readiness checklist |
| `docs/iam-service-role-reference.md` | IAM groups, runtime roles, PassRole, and Lake Formation guidance |
| `docs/runtime-connectivity-validation.md` | Glue, JDBC, VPC, Athena, SageMaker, and runtime validation commands |

## Purpose

This Method of Procedure (MOP) is the production deployment and operational
runbook for the CDCU Terraform-managed AWS environment. It should be used only
after UAT validation is passed and BPI-MS provides formal production promotion
approval.

The runbook consolidates the validated UAT automation approach, manual actions
performed during UAT stabilization, deployment commands, validation checks,
rollback guidance, and operational ownership recommendations.

## Intended Audience

- BPI-MS Cloud / Infrastructure operators
- Stratpoint Cloud Engineering
- Stratpoint Data Engineering
- QA or reporting owners validating Athena and QuickSight outputs
- Change approvers reviewing production promotion readiness

## Production Promotion Entry Criteria

| Gate | Required confirmation | Owner |
|---|---|---|
| UAT acceptance | UAT smoke testing results accepted and signed off by BPI-MS / QA / Business | BPI-MS / QA / Business |
| Access approval | PROD access matrix reviewed and approved; human access follows group-based access and BPI-MS supervision | BPI-MS |
| Production inputs | Production account ID, VPC, subnets, security group, RDS endpoint, database name, KMS key, backend, and bucket names confirmed | BPI-MS Cloud |
| Change approval | Production change window and rollback window approved | BPI-MS / Stratpoint |
| Artifact approval | Glue scripts, SageMaker processing script, notebooks, wheelhouse, and runtime image version approved for PROD | DE / CE |
| Operational ownership | Steady-state owners identified for Terraform, image build, manual rerun, notebook refresh, Athena export, and support | BPI-MS Cloud / DE |

Do not proceed to production if any required value still points to SIT or UAT.
Production must have its own account/resource values, backend state, data lake,
Athena results bucket, Glue catalog, runtime roles, and approved network inputs.

## Validated UAT Automation Pattern to Promote

```text
Yearly schedule or approved manual trigger
  -> Glue raw extraction
  -> Glue standardization
  -> standardized crawler / Glue Data Catalog update
  -> EventBridge starts SageMaker matching pipeline after standardization success
  -> SageMaker Processing writes matching outputs to S3
  -> SageMaker script starts processed matching crawler
  -> Athena catalog refreshes for QA/reporting queries
  -> QuickSight consumes Athena datasets when reporting is enabled
```

Production must use production-specific values only. No SIT/UAT ARNs, bucket
names, subnet IDs, JDBC endpoints, or security groups should remain in the
production plan.

Athena export uses the regular Athena Query Editor and Glue Data Catalog.
SageMaker Unified Studio/DataZone setup is not required for Athena export.

## Production Naming Pattern

Use the standard environment-specific naming pattern:

| Resource type | Production pattern |
|---|---|
| Glue Catalog database | `cdcu_prod_catalog` |
| Glue workflow | `cdcu-prod-etl-workflow` |
| Raw extraction job | `cdcu-prod-merged-raw-extraction` |
| Standardization job | `cdcu-prod-merged-standardization` |
| SageMaker matching pipeline | `cdcu-prod-matching-pipeline` |
| Processed matching crawler | `cdcu-prod-processed-matching-crawler` |
| SageMaker processing repository | `cdcu-prod-sagemaker-processing` |
| Data lake bucket | BPI-MS approved production bucket, for example `cdcu-prod-data-lake-apse1` |
| Athena results bucket | BPI-MS approved production bucket, for example `cdcu-prod-athena-results-apse1` |

The examples in this document use placeholders such as `<prod-profile>` and
`<prod-data-lake-bucket>`. Replace them with BPI-MS approved production values
before execution.

## Manual UAT Actions to Record for PROD Improvement

| Manual action performed | Reason | PROD recommendation |
|---|---|---|
| Manual deletion of default notebook | Default notebook allocation conflicted with the desired CDCU-managed notebook/Jupyter setup | Document notebook lifecycle procedure and avoid ad hoc deletion unless approved |
| Manual reallocation of notebook after manual creation | Notebook/Jupyter workspace needed to point to the correct managed files and updated artifacts | Use repo-managed artifact sync and verify notebook/script timestamps after deployment |
| Manual build of runtime via Docker Compose/local Docker | Initial SageMaker image was built from Apple Silicon and lacked linux/amd64 manifest required by SageMaker Processing | Build and push production runtime from an amd64 Linux build environment or explicit `docker buildx --platform linux/amd64` |
| Manual CloudWatch/SageMaker diagnostics | Required to isolate runtime failures such as missing `psutil`, unsafe memory formatting, and region configuration | Keep diagnostic scripts in the operational runbook and reuse for PROD smoke validation |

## Pre-Deployment Checklist

| Area | Checklist item | Status before PROD |
|---|---|---|
| Repository | Production branch/tag reviewed and approved | Required |
| Terraform backend | S3 state bucket and DynamoDB lock table exist for PROD | Required |
| tfvars | `environments/prod/terraform.tfvars` populated with approved production values and not committed | Required |
| RDS/JDBC | Production merged JDBC URL and database name confirmed; Secrets Manager secret populated outside Terraform | Required |
| Network | Production VPC, private subnets, runtime security group, route table, RDS SG rule, and endpoints validated | Required |
| IAM | `ST-CDCU-prod` runtime roles, QA/DE/CE groups, scoped S3 delete where approved, and Lake Formation grants reviewed | Required |
| SageMaker image | Production ECR image exists and has linux/amd64 manifest | Required if pipeline enabled |
| Artifacts | Glue scripts, `matching_prod.py`, notebooks, wheelhouse, and SQL artifacts approved | Required |
| Athena | Production workgroup, result bucket, and `cdcu_prod_catalog` access confirmed | Required |
| QuickSight | Enable only if BPI-MS confirms subscription, principal, and dataset/dashboard promotion plan | Conditional |

Before running Terraform, also confirm that the accidental repository-root
Terraform entry point is not used for deployment. The valid Terraform entry
point for production is:

```text
environments/prod/
```

Run `terraform init`, `terraform plan`, and `terraform apply` from the
environment folder only.

## Production Terraform Deployment Procedure

### Prepare Local Workspace

```bash
git clone <approved-codecommit-or-git-repo-url>
cd cdcu
git checkout <approved-production-release-branch-or-tag>
cd environments/prod
```

Confirm the backend configuration is production-specific:

```bash
cat backend.tf
```

Expected backend values should reference production state resources, for
example:

```text
bucket         = "cdcu-terraform-state-prod"
key            = "cdcu/prod/terraform.tfstate"
dynamodb_table = "cdcu-terraform-locks-prod"
region         = "ap-southeast-1"
```

### Initialize and Validate

```bash
AWS_PROFILE=<prod-profile> terraform init -reconfigure
AWS_PROFILE=<prod-profile> terraform fmt -check -recursive ../../
AWS_PROFILE=<prod-profile> terraform validate
```

### Plan and Review

```bash
AWS_PROFILE=<prod-profile> terraform plan -var-file="terraform.tfvars" -out=tfplan
AWS_PROFILE=<prod-profile> terraform show tfplan
```

Before apply:

- Confirm there are no UAT or SIT values in the plan.
- Confirm no unexpected destroy or replacement actions.
- Confirm EventBridge, Glue, SageMaker, S3, Athena, and IAM resources are
  scoped to prod names.
- Archive the reviewed plan as deployment evidence before apply.
- Confirm no secrets or JDBC credentials are exposed in the plan.
- Confirm `enable_quicksight`, SageMaker pipeline flags, workflow schedule
  flags, and processing image build flags match the approved production scope.

### Apply After Approval

```bash
AWS_PROFILE=<prod-profile> terraform apply tfplan
```

## SageMaker Processing Runtime Build

If the production processing image must be rebuilt, use an amd64-compatible
build path.

```bash
export AWS_PROFILE=<prod-profile>
export REGION=ap-southeast-1
export ACCOUNT_ID=<prod-account-id>
export REPO_NAME=cdcu-prod-sagemaker-processing
export IMAGE_TAG=py312

aws ecr get-login-password --profile "$AWS_PROFILE" --region "$REGION" | \
  docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

docker buildx build \
  --platform linux/amd64 \
  -t "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:$IMAGE_TAG" \
  docker/sagemaker-processing \
  --push
```

If buildx is unavailable, build from an approved amd64 Linux environment or
build runner.

After the image is pushed, confirm the production image URI and tag are aligned
in `environments/prod/terraform.tfvars`:

```hcl
sagemaker_matching_pipeline_processing_image_uri = "<prod-account-id>.dkr.ecr.ap-southeast-1.amazonaws.com/cdcu-prod-sagemaker-processing:py312"
```

## Post-Deployment Validation

### Validate Glue Connection

```bash
AWS_PROFILE=<prod-profile> aws glue get-connection \
  --region ap-southeast-1 \
  --name cdcu-prod-merged-mysql
```

If connection testing is performed from the AWS Console, verify that the
connection uses the production JDBC endpoint, production secret, production
subnet, and production runtime security group.

### Run Full E2E Validation

```bash
AWS_PROFILE=<prod-profile> aws glue start-workflow-run \
  --region ap-southeast-1 \
  --name cdcu-prod-etl-workflow
```

### Check Workflow and Glue Jobs

```bash
AWS_PROFILE=<prod-profile> aws glue get-workflow-runs \
  --region ap-southeast-1 \
  --name cdcu-prod-etl-workflow \
  --max-results 3

AWS_PROFILE=<prod-profile> aws glue get-job-runs \
  --region ap-southeast-1 \
  --job-name cdcu-prod-merged-raw-extraction \
  --max-results 3

AWS_PROFILE=<prod-profile> aws glue get-job-runs \
  --region ap-southeast-1 \
  --job-name cdcu-prod-merged-standardization \
  --max-results 3
```

### Check SageMaker Pipeline

```bash
AWS_PROFILE=<prod-profile> aws sagemaker list-pipeline-executions \
  --region ap-southeast-1 \
  --pipeline-name cdcu-prod-matching-pipeline
```

### Check Processed Matching Crawler

```bash
AWS_PROFILE=<prod-profile> aws glue get-crawler \
  --region ap-southeast-1 \
  --name cdcu-prod-processed-matching-crawler \
  --query "Crawler.{Name:Name,State:State,LastCrawl:LastCrawl.Status,LastCrawlTime:LastCrawl.StartTime}" \
  --output table
```

### Check S3 Outputs

```bash
AWS_PROFILE=<prod-profile> aws s3 ls \
  s3://<prod-data-lake-bucket>/standardized/merged/ \
  --recursive \
  --region ap-southeast-1

AWS_PROFILE=<prod-profile> aws s3 ls \
  s3://<prod-data-lake-bucket>/processed/matching/ \
  --recursive \
  --region ap-southeast-1
```

### Athena Smoke Queries

```sql
SELECT COUNT(*) FROM cdcu_prod_catalog.merged;
SELECT COUNT(*) FROM cdcu_prod_catalog.merge_review_sagemaker;
SELECT COUNT(*) FROM cdcu_prod_catalog.eyeball_review_sagemaker;
SELECT COUNT(*) FROM cdcu_prod_catalog.unique_sagemaker;

SELECT * FROM cdcu_prod_catalog.merge_review_sagemaker LIMIT 10;
SELECT * FROM cdcu_prod_catalog.eyeball_review_sagemaker LIMIT 10;
SELECT * FROM cdcu_prod_catalog.unique_sagemaker LIMIT 10;
```

If Athena reports no output location, configure the Athena workgroup or query
editor to use the approved production Athena result S3 location. Do not enable
SageMaker Unified Studio/DataZone just to export Athena results.

## Expected Output Tables

| Table | Purpose | Expected reviewer use |
|---|---|---|
| `merged` | All standardized source data produced by Glue standardization | Source-data validation and row-count comparison |
| `merge_sagemaker` | Pair-level merge results | Technical matching result checks |
| `eyeball_sagemaker` | Pair-level eyeball/manual-review candidate results | Technical candidate checks |
| `merge_review_sagemaker` | Reviewer-ready merge output with left/right customer details | QA/business review in Athena |
| `eyeball_review_sagemaker` | Reviewer-ready eyeball output with left/right customer details | QA/business review in Athena |
| `unique_sagemaker` | Unique/unmatched source records with full available customer columns and matching metadata | QA/business review and export |

The reviewer-ready tables for QA/business validation are:

- `merge_review_sagemaker`
- `eyeball_review_sagemaker`
- `unique_sagemaker`

The pair-level tables `merge_sagemaker` and `eyeball_sagemaker` are useful for
technical validation but are not the primary reviewer tables because they do not
carry all left/right customer detail columns.

## Schedule and Trigger Guidance

UAT was adjusted to avoid unnecessary repeated runs while retaining manual
rerun capability. Production schedule should be approved by BPI-MS based on
business need.

```hcl
glue_workflow_schedule_expression = "cron(0 18 1 1 ? *)" # 2:00 AM Asia/Manila yearly on January 1
```

For production:

- Keep scheduled automation disabled until BPI-MS approves timing and frequency.
- Manual workflow or pipeline runs remain available for approved reprocessing.
- If business requires regular refresh, prefer an approved monthly, quarterly,
  or yearly schedule and confirm S3 retention/overwrite policy.

If BPI-MS does not require regular production refresh, keep the schedule disabled
and use manual approved reprocessing. This avoids unnecessary Glue, SageMaker,
S3, Athena, and crawler cost.

## Rollback and Contingency

| Scenario | Immediate action | Recovery |
|---|---|---|
| Terraform plan shows unexpected destroy/replace | Do not apply; stop and review with BPI-MS | Correct tfvars/code, regenerate plan, and re-approve |
| Glue connection fails | Do not rerun downstream jobs repeatedly | Verify JDBC URL, secret, subnet, SG, route, and RDS allow rule |
| Raw extraction overwrite fails with DeleteObject | Confirm scoped delete access is approved and limited to generated output paths | Apply IAM correction and rerun extraction |
| SageMaker image pull fails with linux/amd64 manifest error | Stop pipeline reruns | Rebuild/push image using linux/amd64 platform |
| SageMaker AlgorithmError | Check step details and CloudWatch ProcessingJobs logs | Patch script artifact, terraform apply, rerun pipeline |
| Crawler did not refresh Athena | Check crawler status and CloudWatch logs | Start crawler manually only after output is written, then reconcile automation |

Avoid full production destroy. Prefer corrective Terraform plans and preserve
S3/state evidence unless BPI-MS explicitly approves cleanup.

Any emergency console change must be documented and reconciled into Terraform
or supporting source files before the next planned deployment.

## Operational Ownership

| Operational item | Recommended owner | Notes |
|---|---|---|
| Terraform apply and state management | BPI-MS Cloud / approved operator | Use production change window and reviewed tfplan |
| SageMaker image rebuild | BPI-MS Cloud / DE | Use amd64 build path and approved image tag |
| Matching script/notebook updates | DE | Promote from reviewed source; Terraform uploads artifacts to S3 |
| Manual rerun | BPI-MS Cloud / DE | Use runbook commands and record evidence |
| Athena export support | QA / BPI-MS Cloud | Regular Athena Query Editor; no Unified Studio setup required |
| QuickSight dashboard design | DE / Reporting owner | Visual design can be done in UI; promote datasource/dataset/template/dashboard via approved path |

QuickSight dashboard layout creation, such as dragging tables, charts, and
graphs in the UI, should remain with the reporting/dashboard owner. Terraform
can manage deployable QuickSight resources such as data sources, datasets,
templates, and dashboards after the dashboard design pattern is approved.

## Evidence to Capture

- Approved Terraform plan and apply output.
- Glue workflow run ID and job run IDs.
- SageMaker PipelineExecutionArn and final `Succeeded` status.
- CloudWatch log stream references for Glue and SageMaker.
- S3 output path listing for raw, standardized, processed matching, and
  matching CSV outputs when applicable.
- Crawler `LastCrawl` status and timestamp.
- Athena query screenshots or CSV exports for required QA tables.
- Approval emails or change ticket references.

## Sign-off

| Role | Name | Decision | Date | Remarks |
|---|---|---|---|---|
| BPI-MS Approver |  | Approve / Reject / Defer |  |  |
| BPI-MS Cloud Owner |  | Approve / Reject / Defer |  |  |
| BPI-MS QA / Business |  | Approve / Reject / Defer |  |  |
| Stratpoint Cloud Engineering |  | Approve / Reject / Defer |  |  |
| Stratpoint Data Engineering |  | Approve / Reject / Defer |  |  |
