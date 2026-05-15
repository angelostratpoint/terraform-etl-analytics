# CDCU Terraform Infrastructure Repository

**BPI-MS Customer Data Clean-Up (CDCU) - AWS application infrastructure**

This repository provisions the Terraform-owned service layer for the CDCU data pipeline:

```text
MySQL RDS sources -> AWS Glue -> S3 -> SageMaker -> Athena -> QuickSight
```

BPI MS / Stratpoint manually prepares the AWS account baseline before Terraform runs. This includes the deployment role, security baseline, VPC/subnets, security groups, KMS baseline, source database access, and approved Secrets Manager secret containers. Terraform consumes those existing IDs and ARNs as inputs, then provisions the approved CDCU application services plus the additional `ST-CDCU` IAM roles and groups requested for this project.

## Terraform Scope

Terraform owns:

| Activity | Terraform coverage |
|---|---|
| Additional IAM/RBAC | `ST-CDCU` service roles, human groups, additive policies, and shared deny policies |
| 3.3.1 AWS S3 Bucket Creation | Data lake and Athena results buckets |
| 3.3.2 AWS Glue Provisioning and Folder Structuring | Glue catalog database, connections, jobs, S3 script paths |
| 3.3.3 Amazon SageMaker Unified Studio Provisioning | Studio domain, user profiles, optional notebooks, code repository |
| 3.3.4 Amazon Athena Provisioning | Workgroup and query configuration |
| 3.3.5 AWS Crawler Provisioning | Glue crawlers for raw, standardized, processed, and error prefixes |
| 3.3.6 AWS QuickSight Provisioning | QuickSight groups, Athena data source, and dataset when enabled |

Terraform does not own:

- AWS account/IAM/security baseline
- Existing BPI MS IAM roles, baseline RBAC policies, or GitHub OIDC deployment role creation
- VPCs, subnets, route tables, or security group creation
- KMS key creation or key policy ownership
- RDS/source database provisioning
- Secret values
- Data Engineering script logic

## Repository Structure

```text
terraform-etl-analytics/
|-- .github/workflows/          # Terraform plan/apply pipelines
|-- artifacts/                  # DE-owned scripts uploaded to S3 by Terraform
|   |-- glue/
|   |   |-- extraction/         # Glue extraction scripts (*.py)
|   |   `-- standardization/    # Glue standardization scripts (*.py)
|   |-- sagemaker/
|   |   |-- matching/           # SageMaker matching scripts (*.py)
|   |   `-- processing/         # SageMaker processing scripts (*.py)
|   `-- sql/
|       `-- athena/             # Athena SQL files (*.sql)
|-- bootstrap/                  # Optional remote state bootstrap helper
|-- environments/
|   |-- pre-prod/               # Pre-production root module
|   `-- prod/                   # Production root module
|-- modules/
|   |-- artifacts/              # Uploads artifacts/* files to S3
|   |-- athena/
|   |-- cloudwatch/             # Reference only; not active in env roots
|   |-- glue/
|   |-- iam/                    # Additional ST-CDCU IAM roles, groups, and policies
|   |-- quicksight/
|   |-- s3/
|   `-- sagemaker/
`-- docs/
```

Some legacy/reference modules remain in `modules/` for KMS, security groups, Secrets Manager, and CloudWatch, but the active `pre-prod` and `prod` environment roots do not instantiate them. Those areas are manually governed or outside the agreed Terraform scripting list for this project.

## Required External Inputs

Each environment needs these values from BPI MS / manual setup before `terraform plan`:

```hcl
terraform_role_arn
vpc_id
subnet_id
subnet_ids
availability_zone
existing_security_group_id
existing_kms_key_arn # required when enable_kms = true
existing_quicksight_access_role_arn # optional, for BPI-managed QuickSight role references
```

`existing_glue_execution_role_arn` and `existing_sagemaker_execution_role_arn` are deprecated compatibility inputs. Active environment roots use the `ST-CDCU` roles created by `modules/iam`.

Glue connections expect these Secrets Manager secret names to already exist:

```text
cdcu/{environment}/microsite-mysql-connection
cdcu/{environment}/legacy-mysql-connection
```

Terraform references the secret names only. It does not read or store database credentials in state.

## DE Artifact Uploads

Data Engineering scripts are committed under `artifacts/` and uploaded to the CDCU S3 data lake on `terraform apply`.

| Local directory | File type | S3 key prefix |
|---|---|---|
| `artifacts/glue/extraction/` | `*.py` | `{env}/glue-scripts/extraction/` |
| `artifacts/glue/standardization/` | `*.py` | `{env}/glue-scripts/standardization/` |
| `artifacts/sagemaker/matching/` | `*.py` | `{env}/sagemaker-scripts/matching/` |
| `artifacts/sagemaker/processing/` | `*.py` | `{env}/sagemaker-scripts/processing/` |
| `artifacts/sql/athena/` | `*.sql` | `{env}/sql/` |

Directories containing only README files produce zero S3 objects. That is expected until DEs add scripts.

## Local Execution

```bash
cd environments/pre-prod
cp terraform.tfvars.example terraform.tfvars
# Fill terraform.tfvars with BPI MS provided values
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

Production uses the same flow from `environments/prod` and requires the prod GitHub environment approval gate for CI/CD applies.
