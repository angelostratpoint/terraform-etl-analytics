# BPI-MS CDCU IAM Policy Alignment

This document maps the current Terraform IAM implementation to the BPI-MS CDCU access
matrix. It is intended for sandbox testing and BPI-MS handover review.

## Scope Boundary

Terraform provisions only the CDCU workload service layer and the additional `ST-CDCU`
roles, groups, and policies required for that workload.

BPI-MS remains the owner of enterprise IAM governance, AWS Identity Center, networking,
KMS governance, RDS/source database access, security baselines, and remote backend
bootstrap resources.

## Implemented IAM Groups

| Group | Terraform name pattern | Attached policies |
|---|---|---|
| Cloud Engineering | `ST-CDCU-{env}-CloudEngineering` | Glue S3, Glue ETL, Glue Secrets, combined CloudWatch, SageMaker, SageMaker S3, Athena, DynamoDB state lock, EventBridge rule management, DenySensitiveServices |
| Data Engineering | `ST-CDCU-{env}-DataEngineering` | Glue S3, Glue ETL, SageMaker, SageMaker S3, Athena, Secrets read, CloudWatch read, DenySensitiveServices |
| QA | `ST-CDCU-{env}-QA` | QA read-only access, DenySensitiveServices |

Amazon Q Developer access is intentionally not attached to the Cloud Engineering group
because AWS IAM groups have a hard limit of 10 managed policy attachments. If approved,
BPI-MS should grant the Amazon Q policy individually per user.

## Implemented Service Roles

| Role | Trust principal | Purpose |
|---|---|---|
| `ST-CDCU-{env}-GlueExecutionRole` | `glue.amazonaws.com` | Glue ETL jobs, crawlers, Glue connections, Secrets Manager read, and Glue log writes |
| `ST-CDCU-{env}-SageMakerExecutionRole` | `sagemaker.amazonaws.com` | SageMaker Studio domain, user profiles, JupyterLab spaces, jobs, pipelines, S3 data lake access, and SageMaker log writes |
| `ST-CDCU-{env}-AthenaQueryRole` | `quicksight.amazonaws.com` | QuickSight-to-Athena query execution and Glue Data Catalog metadata reads |

## Policy Alignment Notes

| Area | Current Terraform alignment |
|---|---|
| S3 data lake | Object actions and bucket actions are split between bucket and object ARNs for BPI-MS least-privilege review. |
| SageMaker S3 | Read/write/list only; no delete or versioning permissions. |
| Glue | Includes catalog, table, partition, crawler, job, connection, `BatchGetPartition`, and VPC network-interface placement permissions needed for JDBC/RDS access. |
| Athena | Terraform uses the `cdcu-{env}-workgroup` ARN and includes Athena results bucket access plus Glue Data Catalog metadata reads in the same managed policy. The access matrix may show these as separate rows for review clarity. |
| CloudWatch Logs | Includes `/aws/glue/*`, `/aws-glue/*`, and `/aws/sagemaker/*` log groups plus log stream ARNs. Describe actions use `Resource = "*"` because AWS log discovery APIs commonly require it. |
| Secrets Manager | Glue runtime gets `GetSecretValue` and `DescribeSecret`. Data Engineering gets `ListSecrets` on `*` plus read-only access scoped to `cdcu/{env}/*`. Terraform does not create, update, delete, or store secret values. |
| DynamoDB | Cloud Engineering gets state-lock access only to `terraform_lock_table_name`. Environment defaults match backend tables: `cdcu-terraform-locks-pre-prod` and `cdcu-terraform-locks-prod`. |
| EventBridge | Cloud Engineering can manage only `rule/cdcu-*`; explicit deny blocks mutating non-CDCU rules. |
| Amazon Q | Conversation policy exists with `sts:SetContext` and explicit denies for plugin/admin/code-generation features, but is not attached to groups. |

## Approval-Only Items

The following are not active Terraform permissions unless BPI-MS approves them separately:

| Item | Reason |
|---|---|
| `iam:PassRole` for Glue or SageMaker | BPI-MS baseline includes PassRole deny controls. Any exception must be scoped to exact approved execution role ARNs. |
| EventBridge service execution role | Required only for S3 upload -> EventBridge -> Glue crawler automation. This needs a role trusted by `events.amazonaws.com` with `glue:StartCrawler` scoped to `crawler/cdcu-*`. |
| S3 bucket EventBridge notification | Required only if automated S3 object upload events should trigger EventBridge. |
| KMS runtime IAM policy | KMS key lifecycle and key policy remain BPI-MS owned. Terraform only consumes `existing_kms_key_arn` when `enable_kms = true`. |

## Sandbox Testing Guidance

For the Stratpoint sandbox test, use the same policy posture as BPI-MS where possible.
If a scoped policy fails during `terraform plan` or `terraform apply`, capture the exact
AWS error and adjust only the failing statement. Keep PassRole and EventBridge automation
separate until they are explicitly approved.
