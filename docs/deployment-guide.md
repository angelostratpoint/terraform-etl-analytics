# CDCU Terraform Deployment Guide

This workspace provisions the CDCU application service layer plus the additional `ST-CDCU` IAM roles and groups requested for the project. BPI MS / Stratpoint manually prepares the account baseline, deployment role, security baseline, VPC/subnets, security groups, KMS, and source database access before Terraform runs.

## Confirmed BPI-MS Deployment Direction

The latest BPI-MS review confirmed these alignment decisions:

- Target AWS environment separation is now represented by `environments/sit`, `environments/uat`, and `environments/prod`.
- BPI-MS will provide/review IAM policy resources by human group: Cloud Engineering, Data Engineering, and QA.
- VPC configuration is read-only for this repository. Security group, subnet, and route suggestions may be documented for BPI-MS, but Terraform does not own enterprise networking.
- Terraform should provision CDCU Secrets Manager secret containers for Microsite and Legacy, but must not provision secret values.
- Lake Formation is required when BPI-MS enables it; CDCU-scoped Lake Formation grants should be implemented as a separate Terraform phase.
- CodePipeline is later scope and is not required for the current Phase 1 deployment.

## Prerequisites

Before deploying, confirm the following are in place:

- [ ] AWS CLI v2 installed
- [ ] Terraform >= 1.6.0 installed
- [ ] AWS SSO profile configured for the target environment
- [ ] Remote state bucket and lock table bootstrapped, if not already created
- [ ] `terraform_role_arn` is an IAM role ARN that the operator or CI identity can assume, not an IAM user ARN
- [ ] BPI MS provided VPC ID, subnet ID, security group ID, and availability zone
- [ ] Glue subnet has S3 access through an S3 Gateway VPC endpoint or NAT route
- [ ] Existing KMS key ARN provided when `enable_kms = true`
- [ ] Required Secrets Manager secret containers exist, or the approved Secrets Manager container module has been enabled
- [ ] Real RDS JDBC URLs provided for Microsite and Legacy MySQL sources
- [ ] QuickSight is enabled in `ap-southeast-1` when `enable_quicksight = true`
- [ ] BPI MS has approved the additional `ST-CDCU` IAM roles, groups, and policies
- [ ] GitHub environment named `prod` created with at least one required reviewer

## Manual Baseline Inputs

Fill these in `terraform.tfvars` for each environment:

| Variable | Source |
|---|---|
| `terraform_role_arn` | BPI MS deployment role ARN. Must be a role ARN, not a user ARN |
| `vpc_id` | BPI MS network baseline |
| `subnet_id` / `subnet_ids` | BPI MS network baseline |
| `availability_zone` | Must match the Glue subnet |
| `existing_security_group_id` | BPI MS network/security baseline |
| `terraform_lock_table_name` | DynamoDB lock table used by Terraform state locking; should match the backend lock table for the target environment unless BPI MS intentionally uses another table |
| `existing_quicksight_access_role_arn` | Optional BPI-managed QuickSight role reference, if required |
| `existing_kms_key_arn` | Manual KMS baseline, required when KMS is enabled |
| `git_repository_url` | GitHub repository URL for SageMaker code repository |
| `quicksight_admin_principal_arn` | Existing QuickSight user/group owner, if not using Terraform-created group |
| `microsite_jdbc_url` | JDBC URL for the BPI MS Microsite MySQL RDS source |
| `legacy_jdbc_url` | JDBC URL for the BPI MS Legacy MySQL RDS source |
| `github_org` / `github_repo` | GitHub repository identifiers used by IAM/OIDC-related inputs |
| `sso_principal_arns` | BPI MS approved SSO principal ARNs for human-facing roles, if applicable |
| `glue_worker_count` / `glue_worker_type` | BPI MS approved Glue capacity settings |
| `enable_sagemaker_unified_studio` | Whether to create SageMaker Studio resources |
| `sagemaker_studio_user_profile_names` | SageMaker Studio user profiles to provision |
| `sagemaker_studio_space_instance_type` | JupyterLab Space instance type |
| `sagemaker_studio_space_volume_size_gb` | JupyterLab Space EBS volume size |
| `sagemaker_studio_app_network_access_type` | SageMaker Studio app network mode, typically `VpcOnly` |
| `enable_quicksight` | Whether Terraform should create QuickSight resources |
| `quicksight_spice_capacity_gb` | Approved SPICE capacity setting |

The backend configuration uses these remote state lock tables:

| Environment | Backend lock table |
|---|---|
| `sit` | `cdcu-terraform-locks-sit` |
| `uat` | `cdcu-terraform-locks-uat` |
| `prod` | `cdcu-terraform-locks-prod` |

Set `terraform_lock_table_name` to the same environment-specific table unless BPI MS provides a different approved lock table name for the IAM policy.

Terraform checks the required external IDs before provisioning CDCU services. Glue and SageMaker execution roles are created by the `modules/iam` module using the `ST-CDCU` prefix.

## Required Secrets

Glue connections use these approved Secrets Manager secret names:

```text
cdcu/{environment}/microsite-mysql-connection
cdcu/{environment}/legacy-mysql-connection
```

Current Terraform references these secret names. The next approved alignment phase should allow Terraform to create the secret containers only. Terraform must not create `aws_secretsmanager_secret_version` resources containing passwords and must not store `secret_string` values in state. BPI MS / authorized operators should populate and rotate the secret values outside Terraform or through a BPI-approved rotation mechanism.

Glue connections also require non-local JDBC URLs in `terraform.tfvars`:

```hcl
microsite_jdbc_url = "jdbc:mysql://<bpi-microsite-rds-endpoint>:3306/<database>"
legacy_jdbc_url    = "jdbc:mysql://<bpi-legacy-rds-endpoint>:3306/<database>"
```

The variables reject `localhost` values so test placeholders are not accidentally deployed to BPI MS environments.

## Lake Formation

Lake Formation is not currently provisioned by this Terraform workspace. The Stratpoint sandbox proved that IAM alone is not sufficient when Lake Formation is enabled: Glue crawlers, Athena users, and QuickSight principals all require explicit Lake Formation grants.

When BPI-MS enables Lake Formation, add a CDCU-scoped Lake Formation phase before production use. The future Terraform scope should include only workload grants, not account-wide Lake Formation governance:

| Principal | Minimum CDCU grants to review |
|---|---|
| `ST-CDCU-{env}-GlueExecutionRole` | Database/table permissions needed by Glue crawlers and jobs |
| Athena/Query role or approved Athena users | Database `DESCRIBE`, table `DESCRIBE`, and column/table `SELECT` |
| QuickSight service role | Database `DESCRIBE`, table `DESCRIBE`, and column/table `SELECT` |
| QuickSight author user/group | Database `DESCRIBE`, table `DESCRIBE`, and column/table `SELECT` |

BPI-MS remains owner of Lake Formation admin settings, data lake administrators, cross-account settings, and any enterprise data governance standards.

## QuickSight

QuickSight resources are controlled by `enable_quicksight`.

Set `enable_quicksight = true` only after BPI MS confirms:

- QuickSight is enabled in `ap-southeast-1`
- The namespace/user/group setup is ready
- `quicksight_admin_principal_arn` is available and approved
- SPICE capacity is approved

If QuickSight is not ready, set `enable_quicksight = false` for the first infrastructure deployment and enable it in a later approved Terraform run.

## EventBridge Automation

Current Terraform IAM includes human Cloud Engineering permissions to manage CDCU EventBridge rules scoped to `rule/cdcu-*`.

S3 upload -> EventBridge -> Glue crawler automation is not enabled unless BPI MS separately approves the additional service-side components:

- An EventBridge execution role trusted by `events.amazonaws.com`
- A policy on that role allowing `glue:StartCrawler` on `crawler/cdcu-*`
- S3 bucket EventBridge notifications for the approved upload prefixes

Keep this automation as a separate approval item because it introduces a new service trust relationship.

## Deployment

```bash
cd environments/sit
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with BPI MS provided values

terraform init
terraform fmt -check -recursive ../../
terraform validate
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

For UAT and production, run the same flow from `environments/uat` and `environments/prod`.

Run Terraform from the environment folder only. Running `terraform init`, `validate`, or `plan` from the repository root will not validate this project because the root folder is not a Terraform root module.

## Post-Deployment Checks

```bash
terraform output

aws s3 ls s3://cdcu-sit-data-lake --profile cdcu-sit-profile

aws glue get-database \
  --name cdcu_sit_catalog \
  --region ap-southeast-1 \
  --profile cdcu-sit-profile

aws athena get-work-group \
  --work-group cdcu-sit-workgroup \
  --region ap-southeast-1 \
  --profile cdcu-sit-profile

aws s3 ls s3://cdcu-sit-data-lake/sit/glue-scripts/ \
  --profile cdcu-sit-profile
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

## Fresh Machine Setup

When cloning this repository on a new machine, the following are **not included** in the repo and must be set up manually before `terraform plan` will work:

| Missing Item | Why | Fix |
|---|---|---|
| `terraform.tfvars` | Gitignored — contains real credentials and IDs | Copy from `terraform.tfvars.example` and fill in values |
| `.terraform/` directory | Gitignored — contains downloaded provider plugins | Run `terraform init` |
| AWS credentials | Machine-specific | Run `aws sso login` or `aws configure` |
| Terraform CLI | Must be installed | Install >= 1.6.0 from https://developer.hashicorp.com/terraform/install |

Step-by-step for a fresh clone:

```powershell
# 1. Clone and switch to the working branch
git clone https://github.com/angelostratpoint/terraform-etl-analytics.git
cd terraform-etl-analytics
git checkout codex-client-governed-service-scope-v3

# 2. Authenticate to AWS
aws sso login --profile your-profile
# or
aws configure

# 3. Create terraform.tfvars from the example
cd environments/sit
copy terraform.tfvars.example terraform.tfvars
# Fill in all real values — VPC, subnet, SG, role ARN, JDBC URLs

# 4. Initialize Terraform
terraform init

# 5. Validate and plan
terraform validate
terraform plan -var-file="terraform.tfvars" -out=tfplan
```

> Note: Since resources are tracked in remote state, `terraform apply` on a fresh clone will not recreate anything when the backend points to the correct environment state bucket, such as `cdcu-terraform-state-sit`, `cdcu-terraform-state-uat`, or `cdcu-terraform-state-prod`. Any machine with the correct `terraform.tfvars` and AWS credentials can manage the same infrastructure.

---

## Rollback

Prefer reverting the Terraform change and applying a new plan. For emergency SIT/UAT cleanup only, targeted destroy can be used:

```bash
terraform destroy -target=module.glue -var-file="terraform.tfvars"
```

Avoid full environment destroy in production.
