# CDCU Terraform Deployment Guide

## Prerequisites Checklist

Before deploying, confirm the following are in place:

- [ ] AWS CLI v2 installed (`aws --version`)
- [ ] Terraform >= 1.6.0 installed (`terraform version`)
- [ ] Git installed (`git --version`)
- [ ] AWS SSO profile configured for the target environment
- [ ] VPC ID and subnet ID obtained from BPI MS Cloud Engineer
- [ ] GitHub repository cloned locally
- [ ] Bootstrap script executed for the target environment

---

## Step 1 — AWS CLI and SSO Configuration

```bash
# Configure SSO profile (run once per environment)
aws configure sso --profile cdcu-pre-prod-profile

# Authenticate (run at the start of each working session)
aws sso login --profile cdcu-pre-prod-profile

# Verify identity
aws sts get-caller-identity --profile cdcu-pre-prod-profile
```

---

## Step 2 — Bootstrap Remote State (First Time Only)

```bash
cd bootstrap
chmod +x bootstrap.sh

./bootstrap.sh pre-prod cdcu-pre-prod-profile
./bootstrap.sh prod     cdcu-prod-profile
```

Verify the bootstrap created:
- S3 bucket: `cdcu-terraform-state-{env}`
- DynamoDB table: `cdcu-terraform-locks-{env}`

---

## Step 3 — Configure Environment Variables

```bash
cd environments/pre-prod
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and fill in:

| Variable | Where to Get It |
|----------|----------------|
| `terraform_role_arn` | BPI MS Cloud Engineer |
| `vpc_id` | BPI MS Cloud Engineer |
| `subnet_id` | BPI MS Cloud Engineer |
| `availability_zone` | Must match the subnet's AZ |
| `github_org` | Your GitHub organization name |
| `github_repo` | This repository name |
| `sso_principal_arns` | AWS IAM Identity Center console |
| `git_repository_url` | This repository's HTTPS clone URL |
| `sns_topic_arn` | Create SNS topic or leave empty |

---

## Step 4 — Initialize Terraform

```bash
cd environments/pre-prod
terraform init
```

Expected output:
```
Initializing the backend...
Successfully configured the backend "s3"!
Initializing modules...
Terraform has been successfully initialized!
```

---

## Step 5 — Validate and Plan

```bash
# Format check
terraform fmt -check -recursive ../../

# Validate configuration
terraform validate

# Generate plan
terraform plan -var-file="terraform.tfvars" -out=tfplan
```

Review the plan output carefully. Confirm:
- Resource count matches expectations
- No unexpected destroys
- Naming follows `cdcu-{env}-` convention
- Tags are applied to all resources
- Artifact upload count matches files in `artifacts/`

---

## Step 6 — Apply

```bash
terraform apply tfplan
```

---

## Step 7 — Post-Deployment Validation

```bash
# Verify outputs
terraform output

# Validate S3 bucket exists
aws s3 ls s3://cdcu-pre-prod-data-lake --profile cdcu-pre-prod-profile

# Validate Athena workgroup
aws athena get-work-group \
  --work-group cdcu-pre-prod-workgroup \
  --region ap-southeast-1 \
  --profile cdcu-pre-prod-profile

# Validate Glue catalog database
aws glue get-database \
  --name cdcu_pre_prod_catalog \
  --region ap-southeast-1 \
  --profile cdcu-pre-prod-profile

# Validate artifacts were uploaded
aws s3 ls s3://cdcu-pre-prod-data-lake/pre-prod/glue-scripts/ \
  --profile cdcu-pre-prod-profile
```

---

## Step 8 — Populate Secrets

After deployment, populate the MySQL connection secret. **Never put credentials in Terraform files.**

```bash
aws secretsmanager put-secret-value \
  --secret-id "cdcu/pre-prod/mysql-connection" \
  --secret-string '{
    "host": "actual-mysql-host",
    "port": "3306",
    "dbname": "actual-db-name",
    "username": "actual-username",
    "password": "actual-password"
  }' \
  --region ap-southeast-1 \
  --profile cdcu-pre-prod-profile
```

---

## Environment Promotion Workflow

```
pre-prod → prod
```

1. Create a PR from `feature/prod-*` targeting `main`
2. CI runs `terraform plan` and posts output as PR comment
3. Peer reviewer approves the PR
4. Merge with commit message containing `[env:prod]` triggers apply to prod
5. GitHub environment protection rules require manual approval before prod apply proceeds

---

## Rollback Procedure

If an apply causes issues:

```bash
# Option 1: Revert to previous state version
aws s3 ls s3://cdcu-terraform-state-pre-prod/cdcu/pre-prod/ \
  --profile cdcu-pre-prod-profile
# Identify the previous state version and restore it

# Option 2: Terraform destroy specific resources
terraform destroy -target=module.glue -var-file="terraform.tfvars"

# Option 3: Full environment destroy (DESTRUCTIVE — use only in pre-prod)
terraform destroy -var-file="terraform.tfvars"
```

---

## Simulated Deployment Output

```
module.iam.aws_iam_role.cdcu_glue_execution: Creating...
module.iam.aws_iam_role.cdcu_sagemaker_execution: Creating...
module.s3.aws_s3_bucket.cdcu_data_lake: Creating...
module.secrets_manager.aws_secretsmanager_secret.mysql_connection: Creating...
module.cloudwatch.aws_cloudwatch_log_group.glue: Creating...
module.artifacts.aws_s3_object.glue_scripts["microsite_raw_extraction.py"]: Creating...
...
Apply complete! Resources: 52 added, 0 changed, 0 destroyed.

Outputs:
data_lake_bucket_name    = "cdcu-pre-prod-data-lake"
athena_workgroup_name    = "cdcu-pre-prod-workgroup"
glue_catalog_database    = "cdcu_pre_prod_catalog"
cloudwatch_dashboard     = "cdcu-pre-prod-operations"
artifacts_uploaded = {
  glue      = 4
  matching  = 2
  sagemaker = 1
  sql       = 3
}
```
