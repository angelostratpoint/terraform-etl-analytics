# CDCU Terraform IAM Scripts — Ready for Review with Pre-Deployment Notes

**Prepared by:** Stratpoint Cloud Engineering
**For:** BPI MS Cloud Engineering Team
**Branch:** `codex-client-governed-service-scope`
**Date:** 2025-05-14

---

## What Stratpoint Has Prepared

The following Terraform scripts are ready for BPI MS review and execution.

### New IAM Module — `modules/iam/`

All resources use the `ST-CDCU` naming prefix as agreed.

| Resource Type | Name |
|---|---|
| Glue execution role | `ST-CDCU-{env}-GlueExecutionRole` |
| SageMaker execution role | `ST-CDCU-{env}-SageMakerExecutionRole` |
| Athena / QuickSight query role | `ST-CDCU-{env}-AthenaQueryRole` |
| Cloud Engineering group | `ST-CDCU-{env}-CloudEngineering` |
| Data Engineering group | `ST-CDCU-{env}-DataEngineering` |
| QA group | `ST-CDCU-{env}-QA` |

`{env}` is either `pre-prod` or `prod`.

### Infrastructure Modules — Ready

All 6 infrastructure modules are wired and ready for deployment:

| Activity | Module |
|---|---|
| 3.3.1 AWS S3 Bucket Creation | `modules/s3/` |
| 3.3.2 AWS Glue Provisioning and Folder Structuring | `modules/glue/` |
| 3.3.3 Amazon SageMaker Unified Studio Provisioning | `modules/sagemaker/` |
| 3.3.4 Amazon Athena Provisioning | `modules/athena/` |
| 3.3.5 AWS Crawler Provisioning | `modules/glue/` (crawlers) |
| 3.3.6 AWS QuickSight Provisioning | `modules/quicksight/` |

### Reference Documents

| Document | Location |
|---|---|
| IAM policy details and RBAC matrix | `docs/iam-additional-policies.md` |
| Deployment instructions | `docs/deployment-guide.md` |
| IAM role matrix | `docs/iam-role-matrix.md` |

---

## Pre-Deployment Action Required from BPI MS

Before running `terraform apply`, BPI MS needs to resolve the following 2 conflicts
between the new IAM module and the existing deny policies on the AWS account.

---

### 1. Secrets Manager Conflict — Glue Jobs Will Fail at Runtime

**Existing policy causing the conflict:**

```json
{
  "PolicyName": "cdcu-deny-sensitive-services",
  "Effect": "Deny",
  "Action": ["secretsmanager:*"],
  "Resource": "*"
}
```

**Why this is a problem:**

The `ST-CDCU-{env}-GlueExecutionRole` needs `secretsmanager:GetSecretValue` at
runtime to read the MySQL JDBC credentials for the two source database connections:

```
cdcu/{environment}/microsite-mysql-connection
cdcu/{environment}/legacy-mysql-connection
```

Without this, all Glue extraction jobs will fail when they attempt to connect to
the MySQL RDS source databases.

**Requested action from BPI MS:**

Narrow the existing deny from `secretsmanager:*` to exclude `GetSecretValue` and
`DescribeSecret` for the Glue execution role, scoped to `cdcu/*` secrets only:

```json
{
  "Effect": "Allow",
  "Action": [
    "secretsmanager:GetSecretValue",
    "secretsmanager:DescribeSecret"
  ],
  "Resource": "arn:aws:secretsmanager:ap-southeast-1:<account-id>:secret:cdcu/*"
}
```

---

### 2. PassRole Conflict — SageMaker Jobs Will Fail at Runtime

**Existing policy causing the conflict:**

```json
{
  "PolicyName": "cdcu-deny-passrole",
  "Effect": "Deny",
  "Action": ["iam:PassRole"],
  "Resource": "*"
}
```

**Why this is a problem:**

The `ST-CDCU-{env}-SageMakerExecutionRole` needs `iam:PassRole` scoped to itself
when submitting processing jobs, training jobs, and pipelines to SageMaker. Without
this, all SageMaker job submissions will fail with an authorization error.

**Requested action from BPI MS:**

Add a PassRole exception for the SageMaker execution role with a service condition:

```json
{
  "Effect": "Allow",
  "Action": ["iam:PassRole"],
  "Resource": "arn:aws:iam::<account-id>:role/ST-CDCU-{env}-SageMakerExecutionRole",
  "Condition": {
    "StringEquals": {
      "iam:PassedToService": "sagemaker.amazonaws.com"
    }
  }
}
```

---

## What BPI MS Needs to Provide Before Deployment

Please fill in the following values in `terraform.tfvars` before running
`terraform apply`. These are BPI MS-managed resources that Terraform consumes
as inputs only — Terraform does not create or modify them.

| Variable | Source | Required |
|---|---|---|
| `terraform_role_arn` | BPI MS deployment role ARN | ✅ Always |
| `vpc_id` | BPI MS network baseline | ✅ Always |
| `subnet_id` | BPI MS network baseline | ✅ Always |
| `subnet_ids` | BPI MS network baseline | ✅ Always |
| `existing_security_group_id` | BPI MS security baseline | ✅ Always |
| `existing_kms_key_arn` | BPI MS KMS baseline | ✅ Prod only |
| `existing_quicksight_access_role_arn` | BPI MS QuickSight setup | Optional |
| `terraform_lock_table_name` | DynamoDB lock table name | Default: `cdcu-terraform-state-lock` |

---

## What Is NOT in Terraform Scope

The following are confirmed outside Stratpoint's Terraform scope and will not be
created or modified by these scripts:

| Item | Owner |
|---|---|
| VPC, subnets, route tables, security groups | BPI MS |
| KMS key creation and key policy | BPI MS |
| Secret values for MySQL connections | BPI MS |
| Existing `cdcu-developer-role` and its policies | BPI MS — not modified |
| Existing `cdcu-qa-role` and its policies | BPI MS — not modified |
| Existing `cdcu-business-review-role` | BPI MS — not modified |
| Existing `cdcu-codepipeline-viewer-role` | BPI MS — not modified |
| Existing `cdcu-release-manager-role` | BPI MS — not modified |
| GitHub OIDC role creation | BPI MS — not modified |

---

## Deployment Steps for BPI MS

Once the 2 policy conflicts above are resolved and `terraform.tfvars` is filled in:

```bash
# Pre-production
cd environments/pre-prod
cp terraform.tfvars.example terraform.tfvars
# Fill terraform.tfvars with BPI MS provided values

terraform init
terraform fmt -check -recursive ../../
terraform validate
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

```bash
# Production (requires GitHub environment approval gate)
cd environments/prod
cp terraform.tfvars.example terraform.tfvars
# Fill terraform.tfvars with BPI MS provided values

terraform init
terraform validate
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

---

## Post-Deployment Verification

After `terraform apply` completes, verify the following:

```bash
# Check IAM roles were created
aws iam get-role --role-name ST-CDCU-pre-prod-GlueExecutionRole
aws iam get-role --role-name ST-CDCU-pre-prod-SageMakerExecutionRole
aws iam get-role --role-name ST-CDCU-pre-prod-AthenaQueryRole

# Check IAM groups were created
aws iam get-group --group-name ST-CDCU-pre-prod-CloudEngineering
aws iam get-group --group-name ST-CDCU-pre-prod-DataEngineering
aws iam get-group --group-name ST-CDCU-pre-prod-QA

# Check S3 buckets
aws s3 ls | grep cdcu

# Check Glue catalog
aws glue get-database --name cdcu_pre_prod_catalog --region ap-southeast-1

# Check Athena workgroup
aws athena get-work-group --work-group cdcu-pre-prod-workgroup --region ap-southeast-1
```

---

## Next Steps After BPI MS Review

| Step | Action | Owner |
|---|---|---|
| 1 | Review and approve Terraform scripts | BPI MS |
| 2 | Resolve Secrets Manager and PassRole conflicts | BPI MS |
| 3 | Fill `terraform.tfvars` with environment values | BPI MS |
| 4 | Run `terraform apply` on pre-prod | BPI MS Cloud Engineer |
| 5 | Verify post-deployment checklist | Both teams |
| 6 | Grant CE access to Stratpoint on AWS environment | BPI MS |
| 7 | Run `terraform apply` on prod after pre-prod sign-off | BPI MS Cloud Engineer |
