# CDCU Terraform Deployment Guide

This repository provisions the CDCU Terraform-managed service layer for BPI-MS.
It is organized into separate environment roots for SIT, UAT, and production.

Terraform provisions CDCU-managed resources such as S3, Glue, Athena,
SageMaker, QuickSight configuration, and the additional `ST-CDCU` IAM resources
defined for the project. Terraform does not own the BPI-MS enterprise network
baseline. The VPC, private subnet, security group, endpoints, KMS baseline, and
source database connectivity must be approved by BPI-MS and passed into
Terraform as inputs.

## Repository Environments

| Environment | Terraform root |
|---|---|
| SIT | `environments/sit` |
| UAT | `environments/uat` |
| Prod | `environments/prod` |

Run Terraform from the target environment folder only. The repository root is
not a Terraform root module.

## Naming Convention

The Terraform implementation uses these CDCU naming patterns:

| Resource area | Pattern | Example |
|---|---|---|
| AWS service resources | `cdcu-{env}-*` | `cdcu-sit-data-lake` |
| Secrets Manager paths | `cdcu/{env}/*` | `cdcu/sit/microsite-mysql-connection` |
| Glue catalog database | `cdcu_{env}_catalog` | `cdcu_sit_catalog` |
| IAM roles, groups, policies | `ST-CDCU-{env}-*` | `ST-CDCU-sit-GlueExecutionRole` |
| Terraform backend bucket | `cdcu-terraform-state-{env}` | `cdcu-terraform-state-sit` |
| Terraform lock table | `cdcu-terraform-locks-{env}` | `cdcu-terraform-locks-sit` |

## Required BPI-MS Inputs

Before deployment, BPI-MS must provide or approve the following values for the
target environment:

| Input | Purpose |
|---|---|
| `terraform_role_arn` | IAM role Terraform assumes during deployment |
| `vpc_id` | Approved BPI-MS VPC for CDCU runtime placement |
| `subnet_id` | Primary approved private subnet for Glue placement |
| `subnet_ids` | Approved private subnet list for SageMaker and related services |
| `availability_zone` | Availability zone matching the primary subnet |
| `existing_security_group_id` | Approved runtime security group for Glue and SageMaker |
| `terraform_lock_table_name` | DynamoDB table used by Terraform state locking |
| `existing_kms_key_arn` | BPI-MS KMS key ARN when KMS is enabled |
| `microsite_jdbc_url` | Microsite MySQL RDS JDBC URL |
| `legacy_jdbc_url` | Legacy MySQL RDS JDBC URL |
| `git_repository_url` | Git repository URL for SageMaker code repository |
| `quicksight_admin_principal_arn` | Approved QuickSight principal when QuickSight is enabled |

The approved subnet and security group must support private Glue/SageMaker
runtime connectivity to the source MySQL RDS environment and required AWS
managed-service endpoints. Keep the network resource ownership with BPI-MS;
Terraform only consumes the approved IDs.

## Backend Prerequisite

Before running `terraform init`, create the remote state backend for the target
environment. See `docs/bootstrap-guide.md`.

Expected backend resources:

| Environment | State bucket | Lock table |
|---|---|---|
| SIT | `cdcu-terraform-state-sit` | `cdcu-terraform-locks-sit` |
| UAT | `cdcu-terraform-state-uat` | `cdcu-terraform-locks-uat` |
| Prod | `cdcu-terraform-state-prod` | `cdcu-terraform-locks-prod` |

## Secrets

Glue connections use these Secrets Manager names:

```text
cdcu/{environment}/microsite-mysql-connection
cdcu/{environment}/legacy-mysql-connection
```

Terraform references the approved secret names. Secret values, passwords, and
rotation material must not be committed to Git and must not be stored in
Terraform variables or Terraform state. BPI-MS or an approved operator should
populate and rotate the secret values through the approved secure process.

The JDBC URL variables must point to real RDS endpoints:

```hcl
microsite_jdbc_url = "jdbc:mysql://<rds-endpoint>:3306/<database>"
legacy_jdbc_url    = "jdbc:mysql://<rds-endpoint>:3306/<database>"
```

The variables reject `localhost` values to avoid deploying test placeholders.

## Lake Formation

If Lake Formation is enabled in the BPI-MS account, IAM permissions alone are
not sufficient. BPI-MS must apply CDCU-scoped Lake Formation permissions for the
runtime and query principals.

Minimum grants to review:

| Principal | Minimum grants |
|---|---|
| `ST-CDCU-{env}-GlueExecutionRole` | Database/table permissions for Glue crawler and job updates |
| Approved Athena query principal | Database `DESCRIBE`, table `DESCRIBE`, and `SELECT` |
| Approved QuickSight principal | Database `DESCRIBE`, table `DESCRIBE`, and `SELECT` |

BPI-MS remains owner of Lake Formation account settings, administrators, and
enterprise data governance rules.

## Deployment Steps

From the repository root, choose the target environment.

```powershell
cd environments/sit
Copy-Item terraform.tfvars.example terraform.tfvars
```

Fill `terraform.tfvars` with BPI-MS approved values, then run:

```powershell
terraform init
terraform fmt -check -recursive ../../
terraform validate
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

For UAT and production, run the same flow from `environments/uat` and
`environments/prod`.

## Post-Deployment Checks

Run these from the environment folder after `terraform apply` completes:

```powershell
terraform output

aws s3 ls s3://cdcu-sit-data-lake --region ap-southeast-1

aws glue get-database `
  --name cdcu_sit_catalog `
  --region ap-southeast-1

aws athena get-work-group `
  --work-group cdcu-sit-workgroup `
  --region ap-southeast-1
```

Replace `sit` with `uat` or `prod` when validating another environment.

## Runtime Validation

Infrastructure deployment and runtime application validation are separate
activities. Terraform can deploy the service layer before the final ETL and
matching scripts are complete.

The main runtime validations are:

1. Real MySQL RDS extraction through Glue.
2. Glue ETL script validation.
3. SageMaker matching script validation.
4. Athena and QuickSight validation.

DE-owned scripts are uploaded from the repository when matching files exist:

| Local path | S3 prefix |
|---|---|
| `artifacts/glue/extraction/*.py` | `{env}/glue-scripts/extraction/` |
| `artifacts/glue/standardization/*.py` | `{env}/glue-scripts/standardization/` |
| `artifacts/sagemaker/matching/*.py` | `{env}/sagemaker-scripts/matching/` |
| `artifacts/sagemaker/processing/*.py` | `{env}/sagemaker-scripts/processing/` |
| `artifacts/sql/athena/*.sql` | `{env}/sql/` |

Empty script folders produce zero uploaded objects. That is expected until the
approved runtime scripts are added.

## Fresh Machine Setup

The following local files and credentials are not committed:

| Item | Action |
|---|---|
| `terraform.tfvars` | Copy from `terraform.tfvars.example` and fill approved values |
| `.terraform/` | Run `terraform init` |
| AWS credentials | Authenticate with the approved BPI-MS profile or role |
| Terraform CLI | Install Terraform 1.6.0 or newer |

Example:

```powershell
git clone https://github.com/angelostratpoint/terraform-etl-analytics.git
cd terraform-etl-analytics
git checkout bpi-ms-terraform

cd environments/sit
Copy-Item terraform.tfvars.example terraform.tfvars

terraform init
terraform validate
terraform plan -var-file="terraform.tfvars" -out=tfplan
```

## Rollback

Prefer reverting the Terraform change and applying a new plan. Avoid full
environment destroy in production. For emergency SIT or UAT cleanup only, use a
targeted destroy after review:

```powershell
terraform destroy -target=module.glue -var-file="terraform.tfvars"
```
