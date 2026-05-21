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

`{env}` is `sit`, `uat`, or `prod` for new BPI-MS deployments. The legacy `pre-prod`
root remains temporarily for sandbox/reference use only.

---

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

---

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
| Lake Formation account governance and data lake admin settings | BPI MS |
| CodePipeline / CI-CD enterprise access | BPI MS, later phase |

---

## Terraform Deployment Role Setup (Action Required by BPI MS IT)

Terraform requires an IAM identity to assume when provisioning CDCU resources.
The recommended approach is an IAM role. An IAM user is acceptable for pre-prod
testing only — it must not be used in production.

### IAM Role vs IAM User — Why It Matters

| | IAM User | IAM Role (Recommended) |
|---|---|---|
| Credentials | Long-lived access keys — never expire | Temporary credentials — expire after session |
| If keys are leaked | Permanent access until manually rotated | Attacker gets maximum 1 hour of access |
| Audit trail | Actions logged as the user | Actions logged with session name — easier to trace |
| CI/CD (GitHub Actions) | Keys stored as secrets — rotation burden | OIDC — no keys stored at all |
| BPI MS security baseline | Likely blocked by existing deny policies | Standard enterprise pattern |
| Compliance | Risky for PII data environment | Required for banking/financial compliance |

> **For pre-prod testing:** IAM user is acceptable if BPI MS IT cannot set up the
> role before testing starts. Migrate to IAM role before production.
>
> **For production:** IAM role is non-negotiable. Production handles real customer
> PII data and must meet BPI MS compliance requirements.

---

### Option A — IAM Role Setup (Recommended)

This is a one-time setup. BPI MS IT creates the role once and provides Stratpoint
with the ARN.

#### Step 1 — Create the Deployment Role

**AWS Console → IAM → Roles → Create role**

| Field | Value |
|---|---|
| Trusted entity type | `AWS account` |
| Account ID | BPI MS AWS account ID |
| Role name | `cdcu-pre-prod-terraform-deployment-role` |
| Description | `Terraform deployment role for CDCU pre-prod infrastructure` |

**Tags:**

| Key | Value |
|---|---|
| Project | CDCU |
| Environment | pre-prod |
| ManagedBy | Manual |
| Owner | BPI MS |

#### Step 2 — Attach Permissions

Attach these AWS managed policies to the role:

| Policy | Why Needed |
|---|---|
| `PowerUserAccess` | Covers S3, Glue, SageMaker, Athena, QuickSight, EC2, CloudWatch provisioning |
| `IAMFullAccess` | Required to create ST-CDCU roles, groups, and policies |

> If BPI MS security team cannot approve `IAMFullAccess`, a custom scoped IAM policy
> can be created. Contact Stratpoint Cloud Engineering for the exact policy document.

#### Step 3 — Add Trust Policy

Allow the Terraform operator (IAM user or CI/CD role) to assume this role.
Replace `<account-id>` and `<operator-user-or-role>` with actual values:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::<account-id>:user/<terraform-operator-username>"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "cdcu-terraform-deployment"
        }
      }
    }
  ]
}
```

> For GitHub Actions CI/CD, replace the `Principal` with the GitHub OIDC provider
> ARN instead of an IAM user. Contact Stratpoint for the OIDC trust policy.

#### Step 4 - Provider Behavior

The committed Terraform provider configuration uses `assume_role` so all environment
roots follow the same deployment pattern. Do not commit an IAM-user-only provider
override. If a temporary IAM user is required for sandbox testing, handle it as a local
uncommitted workaround only and migrate back to Option A before SIT/UAT/prod execution.

---

## Required BPI MS Inputs

Please fill these values in each environment's `terraform.tfvars` before running
`terraform apply`.

| Variable | Source | Required |
|---|---|---|
| `terraform_role_arn` | BPI MS deployment role ARN | Always (Option A) |
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

---

## Environment Strategy Update

BPI-MS confirmed that the preferred AWS environment approach is:

```text
SIT -> UAT -> Prod
```

Current repository state:

```text
environments/sit/
environments/uat/
environments/prod/
environments/pre-prod/  # legacy/sandbox root retained temporarily
```

This separation is cleaner for approval gates, access control, testing evidence, and
production readiness. Treat `pre-prod` as a temporary legacy/sandbox root only.

---

## Network Prerequisites

Before running `terraform apply`, BPI MS must confirm the following network
resources exist in the target AWS account:

| Resource | Requirement |
|---|---|
| VPC | Private VPC with CIDR block |
| Private subnet | At least one subnet in `ap-southeast-1a` for Glue connection placement |
| Security group | Must have a self-referencing inbound rule (all traffic from itself) — AWS Glue hard requirement |
| S3 Gateway VPC endpoint | Must be associated with the route table used by the Glue subnet |
| Secrets Manager VPC endpoint | Required for Glue to read MySQL credentials from inside VPC |
| Glue VPC endpoint | Required for Glue service API calls from inside VPC |
| CloudWatch Logs VPC endpoint | Required for Glue and SageMaker log writes from inside VPC |

> The S3 Gateway endpoint association with the route table is the most commonly
> missed prerequisite. Without it, all Glue jobs fail immediately with an S3
> endpoint validation error. See `docs/errors-and-resolutions.md` Error 20.

---

## Secrets Manager Review Note

Glue jobs read the MySQL JDBC credentials from these approved CDCU Secrets Manager
names:

```text
cdcu/{environment}/microsite-mysql-connection
cdcu/{environment}/legacy-mysql-connection
```

The latest BPI-MS review confirmed that Terraform may provision the secret containers
for these names. Terraform must not store secret values, passwords, or rotation material
in `terraform.tfvars`, committed files, or Terraform state. BPI-MS / authorized
operators should populate and rotate secret values through a secure approved process.

Current implementation note: the current `modules/glue/` code references existing
secrets by name. A later implementation phase should add an optional Secrets Manager
container module that creates the secret containers only, without `secret_string`.

If the existing BPI MS deny policy blocks `secretsmanager:*` for all CDCU roles, BPI MS
must allow the approved read-only actions for the ST-CDCU runtime roles on `cdcu/*`
secrets. Without that exception, Glue extraction jobs will not be able to connect to the
RDS source databases.

---

## Lake Formation Review Note

BPI-MS confirmed that Lake Formation is needed for the target account model. The current
Terraform code does not yet provision Lake Formation grants. Lake Formation findings are
documented from Stratpoint sandbox testing in `docs/errors-and-resolutions.md` Errors
25, 26, and 27.

Recommended next phase:

- Add a CDCU-scoped `modules/lakeformation/` module.
- Keep BPI-MS as owner of Lake Formation admin settings and enterprise governance.
- Grant only CDCU database/table/column access required by:
  - `ST-CDCU-{env}-GlueExecutionRole`
  - approved Athena query principals
  - QuickSight service role
  - QuickSight author user/group principals
- Keep Lake Formation grants environment-specific for `sit`, `uat`, and `prod`.

IAM permissions alone are not enough when Lake Formation is enabled.

---

## PassRole Review Note

`iam:PassRole` is intentionally excluded from the latest approved ST-CDCU policy list.
The existing BPI MS `cdcu-deny-passrole` control can remain in place unless BPI MS later
requires and approves a scoped PassRole exception for Terraform deployment workflows or
Glue/SageMaker job definition updates that reference execution roles.

If approved, scope PassRole only to the exact ST-CDCU execution roles:

```text
arn:aws:iam::<account-id>:role/ST-CDCU-{env}-GlueExecutionRole
arn:aws:iam::<account-id>:role/ST-CDCU-{env}-SageMakerExecutionRole
```

---

## QuickSight Review Note

`ST-CDCU-{env}-AthenaQueryRole` is created and output by Terraform for QuickSight/Athena
review, but the current `modules/quicksight/` implementation does not directly attach
that role to `aws_quicksight_data_source.athena`. QuickSight service access may be an
account-level BPI-MS/QuickSight setting rather than a per-data-source role.

Before enabling QuickSight in BPI-MS SIT/UAT/Prod, validate the access model in the
Stratpoint sandbox where QuickSight is already working:

- QuickSight can query `cdcu-{env}-workgroup`
- QuickSight can use `cdcu-{env}-athena-results`
- QuickSight can read the CDCU Glue Data Catalog metadata
- The configured `quicksight_admin_principal_arn` can access the created data source and
  dataset

If the admin principal cannot access the data source or dataset, add explicit QuickSight
permission resources in a later code update. Do not add inline permission blocks to
`aws_quicksight_data_source` or `aws_quicksight_data_set`.

---

## Amazon Q Review Note

Terraform creates the Amazon Q policy but does not attach it to any group because the
Cloud Engineering group already has 10 managed policy attachments. If BPI-MS approves
Amazon Q Developer console-assistant access, attach the policy individually per approved
user:

```text
arn:aws:iam::<account-id>:policy/ST-CDCU-{env}-AmazonQDeveloperAccess
```

---

## CodePipeline Review Note

BPI-MS noted that CodePipeline access can be provided to Cloud Engineering later. This is
not required for the current Phase 1 Terraform handover. Keep the current deployment
path as BPI-MS/Cloud Engineering running Terraform from the environment root. Add
CodePipeline only after BPI-MS approves the deployment role, repository source, approval
gates, and environment promotion model.

---

## Deployment Steps

```powershell
cd environments/sit
cp terraform.tfvars.example terraform.tfvars
# Fill terraform.tfvars with BPI MS-provided values

terraform init
terraform fmt -check -recursive ../../
terraform validate
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

UAT and production use the same flow from `environments/uat` and `environments/prod`.

---

## Post-Deployment Verification

```powershell
aws iam get-role --role-name ST-CDCU-sit-GlueExecutionRole
aws iam get-role --role-name ST-CDCU-sit-SageMakerExecutionRole
aws iam get-role --role-name ST-CDCU-sit-AthenaQueryRole

aws iam get-group --group-name ST-CDCU-sit-CloudEngineering
aws iam get-group --group-name ST-CDCU-sit-DataEngineering
aws iam get-group --group-name ST-CDCU-sit-QA

aws s3 ls s3://cdcu-sit-data-lake
aws glue get-database --name cdcu_sit_catalog --region ap-southeast-1
aws athena get-work-group --work-group cdcu-sit-workgroup --region ap-southeast-1
```

---

## Next Steps

| Step | Action | Owner |
|---|---|---|
| 1 | Review and approve Terraform scripts | BPI MS |
| 2 | Set up Terraform deployment role. IAM user access is sandbox-only if temporarily required | BPI MS IT |
| 3 | Confirm network prerequisites — VPC, subnet, SG, VPC endpoints | BPI MS |
| 4 | Review Secrets Manager container creation and read-only runtime exception requirement | BPI MS |
| 5 | Fill `terraform.tfvars` with environment values | BPI MS |
| 6 | Run `terraform apply` on SIT | BPI MS Cloud Engineer |
| 7 | Verify post-deployment checklist | Both teams |
| 8 | Grant CE access to Stratpoint after scripts are reviewed and approved | BPI MS |
| 9 | Migrate from IAM user to IAM role before UAT/prod if Option B was used temporarily | BPI MS IT |
| 10 | Run `terraform apply` on UAT and prod after sign-off | BPI MS Cloud Engineer |
| 11 | Retire the legacy `pre-prod` root after migration/state decisions are confirmed | Stratpoint / BPI-MS review |
| 12 | Add Secrets Manager container module if approved | Stratpoint / BPI-MS review |
| 13 | Add CDCU-scoped Lake Formation grants if enabled | Stratpoint / BPI-MS review |
