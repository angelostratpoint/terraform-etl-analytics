# CDCU ST-CDCU IAM Role and Policy Matrix

This matrix summarizes the additional IAM resources created by `modules/iam/`.
BPI MS existing `cdcu-*` roles remain outside Terraform scope and are not modified.

## Environment Naming Note

The approved BPI-MS Terraform roots are:

```text
environments/sit/
environments/uat/
environments/prod/
```

This matrix uses `{env}` generically so it can apply to `sit`, `uat`, and `prod`.
The legacy `environments/pre-prod/` root remains temporarily for sandbox/reference use
and should not be used for new BPI-MS deployments.

## Service Roles

| Role Name | Trust Principal | Purpose |
|---|---|---|
| `ST-CDCU-{env}-GlueExecutionRole` | `glue.amazonaws.com` | Runs Glue jobs and crawlers |
| `ST-CDCU-{env}-SageMakerExecutionRole` | `sagemaker.amazonaws.com` | Runs SageMaker Studio, JupyterLab spaces, processing jobs, training jobs, and pipelines |
| `ST-CDCU-{env}-AthenaQueryRole` | `quicksight.amazonaws.com` | Allows QuickSight to query Athena and browse Glue Data Catalog metadata |

## Human Groups

| IAM Group | Intended Users | Access Level |
|---|---|---|
| `ST-CDCU-{env}-CloudEngineering` | BPI MS / approved Cloud Engineers | Application service deployment permissions, Terraform state locking, and EventBridge rule management. Amazon Q is granted individually if approved. |
| `ST-CDCU-{env}-DataEngineering` | Data Engineers | S3 data lake, Glue, SageMaker, Athena, read-only Secrets Manager, and CloudWatch Logs |
| `ST-CDCU-{env}-QA` | QA testers | Read-only validation through Athena results and CloudWatch Logs |

## Policy Summary

| Policy Area | Coverage |
|---|---|
| S3 data lake | Read/write/delete project data under `cdcu-{env}-data-lake` |
| Glue | Catalog, table, partition, crawler, job, and connection operations required by ETL |
| SageMaker | Processing, training, model, endpoint, and pipeline operations from the approved request |
| Athena | Query execution against `cdcu-{env}-workgroup` |
| Athena results S3 | Read/write access to `cdcu-{env}-athena-results` |
| Secrets Manager | Read-only access to `cdcu/{env}/*` secrets; no create/update/delete/put secret value |
| CloudWatch Logs | Glue and SageMaker log creation/write/read actions as appropriate per role/group |
| EventBridge | Rule management scoped to `arn:aws:events:ap-southeast-1:{account}:rule/cdcu-*` |
| DynamoDB | Terraform state lock access to the configured environment backend table, such as `cdcu-terraform-locks-pre-prod` or `cdcu-terraform-locks-prod` |
| Amazon Q | Console assistant conversation actions only, with `sts:SetContext` and explicit denies for plugin/admin/code-generation actions. Policy exists but is not attached to groups. |
| Lake Formation | Not currently provisioned by Terraform. If BPI-MS enables Lake Formation, CDCU-scoped database/table grants are required for Glue, Athena, and QuickSight principals. |

## Shared Deny Boundary

The ST-CDCU roles and groups receive a shared deny policy to protect the BPI MS baseline:

| Deny Area | Denied Actions |
|---|---|
| Sensitive services | `iam:*`, `organizations:*`, `rds:*`, selected Secrets Manager write/delete actions, `cloudformation:*`, `cloudshell:*` |
| Region boundary | Denies regional actions outside `ap-southeast-1`, while allowing necessary global IAM/STS and S3 location/list operations |

`iam:PassRole` is not included in the latest approved ST-CDCU policy list. If SageMaker
job submission later requires a scoped PassRole exception, BPI MS should review and
approve that separately.

Lake Formation is a separate governance layer from IAM. The current IAM roles can still
fail to discover or query Glue Catalog tables in Lake Formation-enabled accounts until
BPI-MS grants the approved CDCU database/table permissions to the relevant service and
human principals.
