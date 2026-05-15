# CDCU Terraform Deployment Guide

This workspace provisions the CDCU application service layer plus the additional `ST-CDCU` IAM roles and groups requested for the project. BPI MS / Stratpoint manually prepares the account baseline, deployment role, security baseline, VPC/subnets, security groups, KMS, source database access, and approved Secrets Manager secret containers before Terraform runs.

## Prerequisites

Before deploying, confirm the following are in place:

- [ ] AWS CLI v2 installed
- [ ] Terraform >= 1.6.0 installed
- [ ] AWS SSO profile configured for the target environment
- [ ] Remote state bucket and lock table bootstrapped, if not already created
- [ ] BPI MS provided VPC ID, subnet ID, security group ID, and availability zone
- [ ] Existing KMS key ARN provided when `enable_kms = true`
- [ ] Required Secrets Manager secrets already created
- [ ] BPI MS has approved the additional `ST-CDCU` IAM roles, groups, and policies
- [ ] GitHub environment named `prod` created with at least one required reviewer

## Manual Baseline Inputs

Fill these in `terraform.tfvars` for each environment:

| Variable | Source |
|---|---|
| `terraform_role_arn` | BPI MS / deployment access setup |
| `vpc_id` | BPI MS network baseline |
| `subnet_id` / `subnet_ids` | BPI MS network baseline |
| `availability_zone` | Must match the Glue subnet |
| `existing_security_group_id` | BPI MS network/security baseline |
| `terraform_lock_table_name` | DynamoDB lock table used by Terraform state locking |
| `existing_quicksight_access_role_arn` | Optional BPI-managed QuickSight role reference, if required |
| `existing_kms_key_arn` | Manual KMS baseline, required when KMS is enabled |
| `git_repository_url` | GitHub repository URL for SageMaker code repository |
| `quicksight_admin_principal_arn` | Existing QuickSight user/group owner, if not using Terraform-created group |

Terraform checks the required external IDs before provisioning CDCU services. Glue and SageMaker execution roles are created by the `modules/iam` module using the `ST-CDCU` prefix.

## Required Secrets

Glue connections reference these existing Secrets Manager secret names:

```text
cdcu/{environment}/microsite-mysql-connection
cdcu/{environment}/legacy-mysql-connection
```

Terraform does not create secret values and does not read `secret_string`, so database credentials are not stored in Terraform state. BPI MS / authorized operators should create and populate these secrets outside Terraform.

## Deployment

```bash
cd environments/pre-prod
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with BPI MS provided values

terraform init
terraform fmt -check -recursive ../../
terraform validate
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

For production, run the same flow from `environments/prod`.

## Post-Deployment Checks

```bash
terraform output

aws s3 ls s3://cdcu-pre-prod-data-lake --profile cdcu-pre-prod-profile

aws glue get-database \
  --name cdcu_pre_prod_catalog \
  --region ap-southeast-1 \
  --profile cdcu-pre-prod-profile

aws athena get-work-group \
  --work-group cdcu-pre-prod-workgroup \
  --region ap-southeast-1 \
  --profile cdcu-pre-prod-profile

aws s3 ls s3://cdcu-pre-prod-data-lake/pre-prod/glue-scripts/ \
  --profile cdcu-pre-prod-profile
```

## DE Script Uploads

DE-owned scripts are stored in the codebase and uploaded to S3 during `terraform apply`.

| Local path | S3 prefix |
|---|---|
| `artifacts/glue/extraction/*.py` | `{env}/glue-scripts/extraction/` |
| `artifacts/glue/standardization/*.py` | `{env}/glue-scripts/standardization/` |
| `artifacts/sagemaker/matching/*.py` | `{env}/sagemaker-scripts/matching/` |
| `artifacts/sagemaker/processing/*.py` | `{env}/sagemaker-scripts/processing/` |
| `artifacts/sql/athena/*.sql` | `{env}/sql/` |

Empty directories containing only README files produce zero S3 objects. That is expected until DEs add scripts.

## GitHub Environment Protection Rule

The `terraform-apply.yml` workflow sets `environment: ${{ needs.detect-environment.outputs.environment }}` on the apply job. When the detected environment is `prod`, GitHub evaluates the protection rules configured for the `prod` environment before allowing the job to run.

To set it up:

1. Go to repository Settings -> Environments.
2. Create an environment named exactly `prod`.
3. Enable Required reviewers and add at least one reviewer or team.
4. Save the environment.

Without this GitHub environment protection rule, a push to `main` with `[env:prod]` in the commit message can apply to production without an approval gate.

## Rollback

Prefer reverting the Terraform change and applying a new plan. For emergency pre-prod cleanup only, targeted destroy can be used:

```bash
terraform destroy -target=module.glue -var-file="terraform.tfvars"
```

Avoid full environment destroy in production.
