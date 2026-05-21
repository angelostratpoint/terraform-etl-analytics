# CDCU Terraform Infrastructure Handover Notes - Ready for BPI MS Review

**Prepared by:** Stratpoint Cloud Engineering
**For:** BPI MS Cloud Engineering Team

---

## What Stratpoint Has Prepared

The Terraform scripts in this branch are ready for BPI MS review and controlled SIT
validation. They use the `ST-CDCU` naming prefix for the additional IAM roles and
groups requested by BPI MS.

Final UAT and production execution should proceed only after BPI MS confirms the
approved naming convention, backend resources, deployment role model, network inputs,
Lake Formation approach, and QuickSight access model.

| Resource Type | Name |
|---|---|
| Glue execution role | `ST-CDCU-{env}-GlueExecutionRole` |
| SageMaker execution role | `ST-CDCU-{env}-SageMakerExecutionRole` |
| Athena / QuickSight query role | `ST-CDCU-{env}-AthenaQueryRole` |
| Cloud Engineering group | `ST-CDCU-{env}-CloudEngineering` |
| Data Engineering group | `ST-CDCU-{env}-DataEngineering` |
| QA group | `ST-CDCU-{env}-QA` |

`{env}` is `sit`, `uat`, or `prod` for BPI-MS deployments.

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
| Terraform remote state S3 bucket and DynamoDB lock table | BPI MS / bootstrap process |
| Lake Formation account governance and data lake admin settings | BPI MS |
| CodePipeline / CI-CD enterprise access | BPI MS, later phase |

---

## Terraform Deployment Role Setup (Action Required by BPI MS IT)

Terraform requires an IAM identity to assume when provisioning CDCU resources.
The recommended approach is an IAM role. An IAM user is acceptable for sit
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

> **For sit testing:** IAM user is acceptable if BPI MS IT cannot set up the
> role before testing starts. Migrate to IAM role before production.
>
> **For production:** IAM role is non-negotiable. Production handles real customer
> PII data and must meet BPI MS compliance requirements.

---

### Option A — IAM Role Setup (Recommended)

This setup is required before BPI MS executes Terraform. BPI MS IT may create one
deployment role per environment or one approved cross-environment deployment role,
depending on the final governance model. The role ARN must be provided in
`terraform.tfvars`.

#### Step 1 — Create the Deployment Role

**AWS Console → IAM → Roles → Create role**

| Field | Value |
|---|---|
| Trusted entity type | `AWS account` |
| Account ID | BPI MS AWS account ID |
| Role name | `cdcu-{env}-terraform-deployment-role` or BPI-MS approved name |
| Description | `Terraform deployment role for CDCU {env} infrastructure` |

**Tags:**

| Key | Value |
|---|---|
| Project | CDCU |
| Environment | `{env}` |
| ManagedBy | Manual |
| Owner | BPI MS |

#### Step 2 — Attach Permissions

For initial review and sandbox validation, the following AWS managed policies describe
the broad access needed to provision the CDCU service layer:

| Policy | Why Needed |
|---|---|
| `PowerUserAccess` | Covers S3, Glue, SageMaker, Athena, QuickSight, EC2, CloudWatch provisioning |
| `IAMFullAccess` | Required to create ST-CDCU roles, groups, and policies |

> BPI MS may replace these with a custom scoped deployment policy. The deployment
> policy must still be able to create and update the CDCU service resources and
> additional `ST-CDCU` IAM roles, groups, policies, and attachments.

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

The Terraform roots are designed to be run by an approved BPI-MS deployment identity.
For production, the committed `prod` root already uses `assume_role` with
`terraform_role_arn`.

The `sit` and `uat` roots currently allow active AWS CLI profile execution for sandbox
validation, with comments showing the `assume_role` block to restore for BPI-MS
execution. Before BPI-MS controlled SIT/UAT execution, either:

1. Restore the `assume_role` block in `environments/sit/providers.tf` and
   `environments/uat/providers.tf`, or
2. Run Terraform from an already-assumed approved deployment role session.

Do not commit personal IAM user credentials, access keys, or IAM-user-only provider
overrides.

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
| `existing_kms_key_arn` | BPI MS KMS baseline | Required when `enable_kms = true` |
| `existing_quicksight_access_role_arn` | BPI MS QuickSight setup | Optional reference |
| `terraform_lock_table_name` | DynamoDB lock table name | Must match backend table: `cdcu-terraform-locks-sit`, `cdcu-terraform-locks-uat`, or `cdcu-terraform-locks-prod` |

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
```

This separation is cleaner for approval gates, access control, testing evidence, and
production readiness.

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

Current implementation note: the current `modules/glue/` code references secrets by
name, so the secret containers must exist before `terraform plan` / `terraform apply`
unless Phase 2B is implemented first. A later implementation phase should add an
optional Secrets Manager container module that creates the secret containers only,
without `secret_string`.

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

## Pending BPI-MS Naming Convention

BPI-MS will provide the final naming convention for CDCU AWS resources. Until that is
received, do not implement new Terraform resource-naming changes or the Secrets Manager
container module. The current `sit`, `uat`, and `prod` environment roots are ready for
review, but naming-sensitive changes should wait for BPI-MS confirmation.

Use this intake table when the naming convention is provided:

| Resource area | Current Terraform pattern | BPI-MS naming convention | Action needed |
|---|---|---|---|
| S3 data lake bucket | `cdcu-{env}-data-lake` | Pending | Confirm or update module naming |
| Athena results bucket | `cdcu-{env}-athena-results` | Pending | Confirm or update module naming |
| Secrets Manager paths | `cdcu/{env}/microsite-mysql-connection`, `cdcu/{env}/legacy-mysql-connection` | Pending | Confirm before Phase 2B |
| IAM roles | `ST-CDCU-{env}-GlueExecutionRole`, `ST-CDCU-{env}-SageMakerExecutionRole`, `ST-CDCU-{env}-AthenaQueryRole` | Pending | Confirm role names and trust scope |
| IAM groups | `ST-CDCU-{env}-CloudEngineering`, `ST-CDCU-{env}-DataEngineering`, `ST-CDCU-{env}-QA` | Pending | Confirm CE/DE/QA group names |
| IAM policies | `ST-CDCU-{env}-<PolicyName>` | Pending | Confirm policy naming and attachment model |
| Glue catalog database | `cdcu_{env}_catalog` | Pending | Confirm Athena-safe database naming |
| Glue jobs/crawlers/connections | `cdcu-{env}-...` | Pending | Confirm service object naming |
| Athena workgroup | `cdcu-{env}-workgroup` | Pending | Confirm workgroup naming |
| SageMaker Studio domain/spaces | `cdcu-{env}-studio`, `cdcu-{env}-<profile>-jupyterlab` | Pending | Confirm Studio naming |
| QuickSight groups/assets | `cdcu-{env}-...` | Pending | Confirm QuickSight namespace/group/data source naming |
| Terraform backend bucket | `cdcu-terraform-state-{env}` | Pending | Confirm backend naming before `terraform init` |
| Terraform lock table | `cdcu-terraform-locks-{env}` | Pending | Confirm lock table naming before `terraform init` |

Recommended order after BPI-MS provides the naming convention:

1. Map each naming rule against the table above.
2. Decide whether each pattern remains hardcoded, becomes a variable, or is generated through a shared naming local.
3. Update Terraform modules only for confirmed naming changes.
4. Implement the Secrets Manager container module for approved names only.
5. Re-run `terraform fmt -recursive` and validate `sit`, `uat`, and `prod`.

---

## Deployment Steps

For syntax-only validation before backend resources exist, use
`terraform init -backend=false`. For real deployment, the backend S3 bucket and
DynamoDB lock table must exist first.

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
Replace `sit` with `uat` or `prod` in commands and expected resource names when
validating those environments.

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
| 1 | Review Terraform scripts and confirm BPI-MS naming convention | BPI MS |
| 2 | Bootstrap or confirm backend S3 bucket and DynamoDB lock table per environment | BPI MS |
| 3 | Set up Terraform deployment role. IAM user access is sandbox-only if temporarily required | BPI MS IT |
| 4 | Confirm network prerequisites - VPC, subnet, SG, VPC endpoints | BPI MS |
| 5 | Review Secrets Manager container creation and read-only runtime exception requirement | BPI MS |
| 6 | Fill `terraform.tfvars` with environment values | BPI MS |
| 7 | Run `terraform apply` on SIT | BPI MS Cloud Engineer |
| 8 | Verify post-deployment checklist | Both teams |
| 9 | Grant CE access to Stratpoint after scripts are reviewed and approved | BPI MS |
| 10 | Migrate from IAM user to IAM role before UAT/prod if Option B was used temporarily | BPI MS IT |
| 11 | Run `terraform apply` on UAT and prod after sign-off | BPI MS Cloud Engineer |
| 12 | Add Secrets Manager container module after naming approval, if approved | Stratpoint / BPI-MS review |
| 13 | Add CDCU-scoped Lake Formation grants if enabled | Stratpoint / BPI-MS review |
