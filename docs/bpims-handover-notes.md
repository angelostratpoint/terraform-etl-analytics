# CDCU Terraform IAM Scripts - Ready for BPI MS Review

**Prepared by:** Stratpoint Cloud Engineering
**For:** BPI MS Cloud Engineering Team
**Branch:** `codex-client-governed-service-scope`
**Date:** 2026-05-15

---

## What Stratpoint Has Prepared

The Terraform scripts in this branch are ready for BPI MS review and execution. They use
the `ST-CDCU` naming prefix for the additional IAM roles and groups requested by BPI MS.

| Resource Type | Name |
|---|---|
| Glue execution role | `ST-CDCU-{env}-GlueExecutionRole` |
| SageMaker execution role | `ST-CDCU-{env}-SageMakerExecutionRole` |
| Athena / QuickSight query role | `ST-CDCU-{env}-AthenaQueryRole` |
| Cloud Engineering group | `ST-CDCU-{env}-CloudEngineering` |
| Data Engineering group | `ST-CDCU-{env}-DataEngineering` |
| QA group | `ST-CDCU-{env}-QA` |

`{env}` is either `pre-prod` or `prod`.

## Terraform-Owned Scope

| Activity | Module |
|---|---|
| Additional ST-CDCU IAM roles, groups, and policies | `modules/iam/` |
| 3.3.1 AWS S3 Bucket Creation | `modules/s3/` |
| 3.3.2 AWS Glue Provisioning and Folder Structuring | `modules/glue/` |
| 3.3.3 Amazon SageMaker Unified Studio Provisioning | `modules/sagemaker/` |
| 3.3.4 Amazon Athena Provisioning | `modules/athena/` |
| 3.3.5 AWS Crawler Provisioning | `modules/glue/` |
| 3.3.6 AWS QuickSight Provisioning | `modules/quicksight/` |

## Existing BPI MS Baseline

Terraform does not create or modify the following BPI MS baseline resources:

| Item | Owner |
|---|---|
| Deployment role used to run Terraform | BPI MS |
| VPC, subnets, route tables, security groups | BPI MS |
| KMS key creation and key policy | BPI MS |
| RDS/source database provisioning | BPI MS |
| Secret values for MySQL connections | BPI MS |
| Existing `cdcu-*` user roles and policies | BPI MS |
| GitHub OIDC role creation | BPI MS |

## Required BPI MS Inputs

Please fill these values in each environment's `terraform.tfvars` before running
`terraform apply`.

| Variable | Source | Required |
|---|---|---|
| `terraform_role_arn` | BPI MS deployment role ARN | Always |
| `vpc_id` | BPI MS network baseline | Always |
| `subnet_id` | BPI MS network baseline | Always |
| `subnet_ids` | BPI MS network baseline | Always |
| `existing_security_group_id` | BPI MS security baseline | Always |
| `existing_kms_key_arn` | BPI MS KMS baseline | Prod only when `enable_kms = true` |
| `existing_quicksight_access_role_arn` | BPI MS QuickSight setup | Optional reference |
| `terraform_lock_table_name` | DynamoDB lock table name | Must match backend table: `cdcu-terraform-locks-pre-prod` or `cdcu-terraform-locks-prod` |

`existing_glue_execution_role_arn` and `existing_sagemaker_execution_role_arn` are
deprecated compatibility inputs. The active environment roots use the ST-CDCU roles
created by `modules/iam`.

## Secrets Manager Review Note

Glue jobs read the MySQL JDBC credentials from these BPI MS-managed secrets:

```text
cdcu/{environment}/microsite-mysql-connection
cdcu/{environment}/legacy-mysql-connection
```

Terraform grants `GetSecretValue` and `DescribeSecret` to the ST-CDCU Glue execution role.
Terraform does not create, update, or store the secret values.

If the existing BPI MS deny policy blocks `secretsmanager:*` for all CDCU roles, BPI MS
must allow the approved read-only actions for the ST-CDCU runtime roles on `cdcu/*`
secrets. Without that exception, Glue extraction jobs will not be able to connect to the
RDS source databases.

## PassRole Review Note

`iam:PassRole` is intentionally excluded from the latest approved ST-CDCU policy list.
The existing BPI MS `cdcu-deny-passrole` control can remain in place unless BPI MS later
requires and approves a scoped PassRole exception for SageMaker job submission.

## Deployment Steps

```bash
cd environments/pre-prod
cp terraform.tfvars.example terraform.tfvars
# Fill terraform.tfvars with BPI MS-provided values

terraform init
terraform fmt -check -recursive ../../
terraform validate
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

Production uses the same flow from `environments/prod` after pre-prod sign-off.

## Post-Deployment Verification

```bash
aws iam get-role --role-name ST-CDCU-pre-prod-GlueExecutionRole
aws iam get-role --role-name ST-CDCU-pre-prod-SageMakerExecutionRole
aws iam get-role --role-name ST-CDCU-pre-prod-AthenaQueryRole

aws iam get-group --group-name ST-CDCU-pre-prod-CloudEngineering
aws iam get-group --group-name ST-CDCU-pre-prod-DataEngineering
aws iam get-group --group-name ST-CDCU-pre-prod-QA

aws s3 ls s3://cdcu-pre-prod-data-lake
aws glue get-database --name cdcu_pre_prod_catalog --region ap-southeast-1
aws athena get-work-group --work-group cdcu-pre-prod-workgroup --region ap-southeast-1
```

## Next Steps

| Step | Action | Owner |
|---|---|---|
| 1 | Review and approve Terraform scripts | BPI MS |
| 2 | Review Secrets Manager read-only exception requirement | BPI MS |
| 3 | Fill `terraform.tfvars` with environment values | BPI MS |
| 4 | Run `terraform apply` on pre-prod | BPI MS Cloud Engineer |
| 5 | Verify post-deployment checklist | Both teams |
| 6 | Grant CE access to Stratpoint after scripts are reviewed and approved | BPI MS |
| 7 | Run `terraform apply` on prod after pre-prod sign-off | BPI MS Cloud Engineer |
