# BPI-MS CDCU IAM Policy Alignment

This document maps the current Terraform IAM implementation to the BPI-MS CDCU access
matrix. It is intended for sandbox testing and BPI-MS handover review.

## Scope Boundary

Terraform provisions only the CDCU workload service layer and the additional `ST-CDCU`
roles, groups, and policies required for that workload.

BPI-MS remains the owner of enterprise IAM governance, AWS Identity Center, networking,
KMS governance, RDS/source database access, security baselines, and remote backend
bootstrap resources.

## Current Governance Decisions

The latest BPI-MS direction is to use formal environment separation:

```text
sit/
uat/
prod/
```

Terraform now includes `environments/sit/`, `environments/uat/`, and
`environments/prod/` roots for the approved BPI-MS environment model.
`environments/pre-prod/` remains temporarily as a legacy/sandbox root and should not be
used for new BPI-MS deployments. This document uses `{env}` to represent the approved
environment name.

BPI-MS will provide and review IAM policy resources by group, especially Cloud
Engineering, Data Engineering, and QA. Terraform may create CDCU-scoped `ST-CDCU`
groups/policies for those responsibilities, but it must not take ownership of enterprise
IAM governance, AWS Identity Center, organization policy, or account-wide security
controls.

Secrets Manager secret containers are approved for these names:

```text
cdcu/{env}/microsite-mysql-connection
cdcu/{env}/legacy-mysql-connection
```

A future Terraform update may create the secret containers only. Secret values,
passwords, rotation credentials, and RDS connection material remain BPI-MS owned and must
not be committed, stored in `terraform.tfvars`, or written through Terraform state.

Lake Formation is expected in BPI-MS accounts. The current IAM implementation does not
create Lake Formation permissions yet; those grants should be handled in a CDCU-scoped
future phase after BPI-MS confirms data lake admin settings and the exact principals.

CodePipeline / CI-CD access is later scope and is not required for the current Phase 1
Terraform handover.

## Implemented IAM Groups

| Group | Terraform name pattern | Attached policies |
|---|---|---|
| Cloud Engineering | `ST-CDCU-{env}-CloudEngineering` | Glue S3, Glue ETL, Glue Secrets, combined CloudWatch, SageMaker, SageMaker S3, Athena, DynamoDB state lock, EventBridge rule management, DenySensitiveServices |
| Data Engineering | `ST-CDCU-{env}-DataEngineering` | Glue S3, Glue ETL, SageMaker, SageMaker S3, Athena, Secrets read, CloudWatch read, DenySensitiveServices |
| QA | `ST-CDCU-{env}-QA` | QA read-only access, DenySensitiveServices |

Amazon Q Developer access is intentionally not attached to the Cloud Engineering group
because AWS IAM groups have a hard limit of 10 managed policy attachments. If approved,
BPI-MS should grant the Amazon Q policy individually per user using this policy ARN
pattern:

```text
arn:aws:iam::<account-id>:policy/ST-CDCU-{env}-AmazonQDeveloperAccess
```

## Implemented Service Roles

| Role | Trust principal | Purpose |
|---|---|---|
| `ST-CDCU-{env}-GlueExecutionRole` | `glue.amazonaws.com` | Glue ETL jobs, crawlers, Glue connections, Secrets Manager read, and Glue log writes |
| `ST-CDCU-{env}-SageMakerExecutionRole` | `sagemaker.amazonaws.com` | SageMaker Studio domain, user profiles, JupyterLab spaces, jobs, pipelines, S3 data lake access, and SageMaker log writes |
| `ST-CDCU-{env}-AthenaQueryRole` | `quicksight.amazonaws.com` | Intended/review role for QuickSight-to-Athena query execution and Glue Data Catalog metadata reads. The current QuickSight module does not wire this role directly into `aws_quicksight_data_source.athena`. |

## Policy Alignment Notes

| Area | Current Terraform alignment |
|---|---|
| S3 data lake | Object actions and bucket actions are split between bucket and object ARNs for BPI-MS least-privilege review. |
| SageMaker S3 | Read/write/list only; no delete or versioning permissions. |
| Glue | Catalog, table, partition, crawler, job, and connection permissions are scoped to CDCU Glue resources where AWS supports resource-level permissions. Glue list/read helpers and VPC network-interface placement permissions remain on `*` where AWS APIs require broad discovery/runtime scope. |
| Athena | Terraform uses the `cdcu-{env}-workgroup` ARN and includes Athena results bucket access plus Glue Data Catalog metadata reads in the same managed policy. The access matrix may show these as separate rows for review clarity. |
| CloudWatch Logs | Includes `/aws/glue/*`, `/aws-glue/*`, and `/aws/sagemaker/*` log groups plus log stream ARNs. Describe actions use `Resource = "*"` because AWS log discovery APIs commonly require it. |
| Secrets Manager | Glue runtime gets `GetSecretValue` and `DescribeSecret`. Data Engineering gets `ListSecrets` on `*` plus read-only access scoped to `cdcu/{env}/*`. Terraform does not create, update, delete, or store secret values. |
| Lake Formation | Not yet implemented in Terraform. If enabled by BPI-MS, CDCU-scoped grants are required for Glue, Athena, and QuickSight principals in addition to IAM. |
| DynamoDB | Cloud Engineering gets state-lock access only to `terraform_lock_table_name`. Environment defaults match backend tables: `cdcu-terraform-locks-pre-prod` and `cdcu-terraform-locks-prod`. |
| EventBridge | Cloud Engineering can manage only `rule/cdcu-*`; explicit deny blocks mutating non-CDCU rules. |
| SageMaker | CDCU processing/training/model/endpoint/pipeline actions are scoped to `cdcu-*` SageMaker ARNs. Studio control-plane and list/tag actions remain on `*` where the SageMaker APIs do not cleanly support the same CDCU resource scoping. |
| Amazon Q | Conversation policy exists with `sts:SetContext` and explicit denies for plugin/admin/code-generation features, but is not attached to groups. |

## QuickSight Alignment Notes

QuickSight is available in the Stratpoint sandbox and should be validated there before
BPI-MS SIT/UAT/Prod enablement.

Current Terraform creates QuickSight groups, an Athena data source, and a dataset when
`enable_quicksight = true`. The module does not currently attach
`ST-CDCU-{env}-AthenaQueryRole` to the QuickSight data source because the supported AWS
QuickSight access model may be account-level service access rather than a direct role
field on the Terraform data source resource.

Validation path:

1. Deploy the core stack first with QuickSight disabled.
2. Enable QuickSight in the Stratpoint sandbox using a valid
   `quicksight_admin_principal_arn`.
3. Confirm whether QuickSight can query the CDCU Athena workgroup, access the Athena
   results bucket, and read Glue Data Catalog metadata.
4. If QuickSight assets are not visible to the admin principal, add explicit QuickSight
   data source and dataset permission resources in a later code update. Do not use inline
   permission blocks on `aws_quicksight_data_source` or `aws_quicksight_data_set`.

## Approval-Only Items

The following are not active Terraform permissions unless BPI-MS approves them separately:

| Item | Reason |
|---|---|
| `iam:PassRole` for Glue or SageMaker | BPI-MS baseline includes PassRole deny controls. Any exception must be scoped to exact approved execution role ARNs. |
| EventBridge service execution role | Required only for S3 upload -> EventBridge -> Glue crawler automation. This needs a role trusted by `events.amazonaws.com` with `glue:StartCrawler` scoped to `crawler/cdcu-*`. |
| S3 bucket EventBridge notification | Required only if automated S3 object upload events should trigger EventBridge. |
| KMS runtime IAM policy | KMS key lifecycle and key policy remain BPI-MS owned. Terraform only consumes `existing_kms_key_arn` when `enable_kms = true`. |
| S3 bucket versioning administration | Runtime Glue and DE S3 access excludes `s3:PutBucketVersioning`. Terraform manages bucket versioning through the deployment role and S3 module, not through the Glue runtime policy. |

## Sandbox Testing Guidance

For the Stratpoint sandbox test, use the same policy posture as BPI-MS where possible.
If a scoped policy fails during `terraform plan` or `terraform apply`, capture the exact
AWS error and adjust only the failing statement. Keep PassRole and EventBridge automation
separate until they are explicitly approved.

For Lake Formation-enabled accounts, IAM permission alone is not enough. The sandbox
QuickSight/Athena test already showed that missing Lake Formation `DESCRIBE`/`SELECT`
grants can block table discovery even when IAM allows Athena and Glue read actions.
