# CDCU Stratpoint Sandbox — Daily Network Setup Guide

> Note: This guide records the earlier Stratpoint sit sandbox setup. After the
> SIT/UAT/Prod environment split, use environments/sit for new sandbox-style
> validation unless you are intentionally reproducing the older test path.

This guide covers the manual AWS setup required each time the Stratpoint sandbox
account resets. These are temporary placeholder resources that simulate the BPI MS
baseline network environment. They are NOT managed by Terraform.

> **Scope:** Sandbox testing only. In the BPI MS environment, all of these are
> pre-provisioned by BPI MS before Terraform runs.

---

## What You Need to Recreate Each Reset

| Resource | Name | Required By |
|---|---|---|
| VPC | `cdcu-sit-vpc` | Glue, SageMaker |
| Private Subnet | `cdcu-sit-private-subnet-1a` | Glue connections, SageMaker Studio |
| Security Group | `cdcu-sit-sg` | Glue JDBC, SageMaker VPC placement |
| S3 Gateway Endpoint | `cdcu-sit-s3-endpoint` | Glue jobs writing to S3 (Error 20 fix) |
| Secrets Manager Endpoint | `cdcu-sit-secretsmanager-endpoint` | Glue reading MySQL credentials at runtime |
| Glue Endpoint | `cdcu-sit-glue-endpoint` | Glue service API calls from inside VPC |
| CloudWatch Logs Endpoint | `cdcu-sit-logs-endpoint` | Glue and SageMaker log writes |
| Terraform State Bucket | `cdcu-terraform-state-sit-<account-id>` | Terraform remote state |
| Terraform Lock Table | `cdcu-terraform-locks-sit` | Terraform state locking |
| Secrets Manager Secrets | `cdcu/sit/*` | Glue MySQL connections |

---

## Step 1 — Verify AWS CLI Identity

Before doing anything, confirm you are connected to the correct sandbox account:

```powershell
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "<sandbox-account-id>",
    "Arn": "arn:aws:iam::<sandbox-account-id>:user/<sandbox-iam-user>"
}
```

> If this fails, run `aws configure` and enter your sandbox access key, secret key,
> and default region `ap-southeast-1`.

---

## Step 2 — Create VPC

**AWS Console → VPC → Your VPCs → Create VPC**

| Field | Value |
|---|---|
| Resources to create | `VPC only` |
| Name tag | `cdcu-sit-vpc` |
| IPv4 CIDR | `10.0.0.0/16` |
| IPv6 CIDR block | No IPv6 CIDR block |
| Tenancy | Default |
| VPC encryption | None |

**Tags:**

| Key | Value |
|---|---|
| Project | CDCU |
| Environment | sit |
| ManagedBy | Manual |
| Owner | Stratpoint |

> After creation, note the VPC ID (e.g. `vpc-07c2999f40dcca77c`).
> AWS automatically creates a main route table — no need to create a separate one.

---

## Step 3 — Create Private Subnet

**AWS Console → VPC → Subnets → Create subnet**

| Field | Value |
|---|---|
| VPC ID | Select `cdcu-sit-vpc` |
| Subnet name | `cdcu-sit-private-subnet-1a` |
| Availability Zone | `ap-southeast-1a` |
| IPv4 VPC CIDR block | `10.0.0.0/16` |
| IPv4 subnet CIDR block | `10.0.1.0/24` |

> Change the default CIDR from `10.0.0.0/20` to `10.0.1.0/24`.

**Tags:**

| Key | Value |
|---|---|
| Project | CDCU |
| Environment | sit |
| ManagedBy | Manual |
| Owner | Stratpoint |

> After creation, note the Subnet ID (e.g. `subnet-07dd42695551cf52d`).
> The subnet automatically uses the VPC main route table.

---

## Step 4 — Create Security Group

**AWS Console → VPC → Security Groups → Create security group**

| Field | Value |
|---|---|
| Security group name | `cdcu-sit-sg` |
| Description | `CDCU sit security group for Glue and SageMaker` |
| VPC | Select `cdcu-sit-vpc` |

**Inbound rules — add these 2 rules:**

| Type | Protocol | Port range | Source | Description |
|---|---|---|---|---|
| All traffic | All | All | `sg-xxxxxxxxx` (this SG's own ID) | Glue self-referencing rule |
| HTTPS | TCP | 443 | `10.0.0.0/16` | VPC internal HTTPS for SageMaker and endpoints |

> To add the self-referencing rule: in the Source field, start typing
> `cdcu-sit-sg` and select it from the dropdown.
>
> The self-referencing rule is an AWS Glue hard requirement. Without it,
> Glue JDBC connections fail even if all IAM permissions are correct.

**Outbound rules:** Leave defaults (All traffic to `0.0.0.0/0`)

**Tags:**

| Key | Value |
|---|---|
| Project | CDCU |
| Environment | sit |
| ManagedBy | Manual |
| Owner | Stratpoint |

> After creation, note the Security Group ID (e.g. `sg-0b846b6693948278a`).

---

## Step 5 — Create VPC Endpoints

Create all 4 endpoints. S3 Gateway first (no SG needed), then the 3 Interface
endpoints (require the SG from Step 4).

### Endpoint 1 — S3 Gateway (create first)

**AWS Console → VPC → Endpoints → Create endpoint**

| Field | Value |
|---|---|
| Name tag | `cdcu-sit-s3-endpoint` |
| Type | AWS services |
| Service name | `com.amazonaws.ap-southeast-1.s3` — select **Gateway** type |
| VPC | `cdcu-sit-vpc` |
| Route tables | ✅ Check the main route table (e.g. `rtb-041f1bc85d37f41b5`) |
| Policy | Full access |

### Endpoint 2 — Secrets Manager (Interface)

| Field | Value |
|---|---|
| Name tag | `cdcu-sit-secretsmanager-endpoint` |
| Type | AWS services |
| Service name | `com.amazonaws.ap-southeast-1.secretsmanager` — **Interface** |
| VPC | `cdcu-sit-vpc` |
| Subnet | `cdcu-sit-private-subnet-1a` |
| Security group | `cdcu-sit-sg` |
| Policy | Full access |

### Endpoint 3 — Glue (Interface)

| Field | Value |
|---|---|
| Name tag | `cdcu-sit-glue-endpoint` |
| Type | AWS services |
| Service name | `com.amazonaws.ap-southeast-1.glue` — **Interface** |
| VPC | `cdcu-sit-vpc` |
| Subnet | `cdcu-sit-private-subnet-1a` |
| Security group | `cdcu-sit-sg` |
| Policy | Full access |

### Endpoint 4 — CloudWatch Logs (Interface)

| Field | Value |
|---|---|
| Name tag | `cdcu-sit-logs-endpoint` |
| Type | AWS services |
| Service name | `com.amazonaws.ap-southeast-1.logs` — **Interface** |
| VPC | `cdcu-sit-vpc` |
| Subnet | `cdcu-sit-private-subnet-1a` |
| Security group | `cdcu-sit-sg` |
| Policy | Full access |

### Expected Endpoints After All 4 Are Created

| Name | Type | Status |
|---|---|---|
| `cdcu-sit-s3-endpoint` | Gateway | Available |
| `cdcu-sit-secretsmanager-endpoint` | Interface | Available |
| `cdcu-sit-glue-endpoint` | Interface | Available |
| `cdcu-sit-logs-endpoint` | Interface | Available (takes ~1 min) |

---

## Step 6 — Bootstrap Terraform Remote State

> **Important:** S3 bucket names are globally unique across all AWS accounts.
> Always append your AWS account ID to avoid `BucketAlreadyExists` errors.
> The Stratpoint sandbox account ID is `<sandbox-account-id>`.

Run in PowerShell:

```powershell
# Create S3 state bucket with account ID suffix
aws s3api create-bucket `
  --bucket cdcu-terraform-state-sit-<sandbox-account-id> `
  --region ap-southeast-1 `
  --create-bucket-configuration LocationConstraint=ap-southeast-1
```

Expected output:
```json
{
    "Location": "http://cdcu-terraform-state-sit-<sandbox-account-id>.s3.amazonaws.com/",
    "BucketArn": "arn:aws:s3:::cdcu-terraform-state-sit-<sandbox-account-id>"
}
```

```powershell
# Enable versioning
aws s3api put-bucket-versioning `
  --bucket cdcu-terraform-state-sit-<sandbox-account-id> `
  --versioning-configuration Status=Enabled
```

```powershell
# Block public access
aws s3api put-public-access-block `
  --bucket cdcu-terraform-state-sit-<sandbox-account-id> `
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

```powershell
# Create DynamoDB lock table
# DynamoDB is account-scoped so no suffix needed
aws dynamodb create-table `
  --table-name cdcu-terraform-locks-sit `
  --attribute-definitions AttributeName=LockID,AttributeType=S `
  --key-schema AttributeName=LockID,KeyType=HASH `
  --billing-mode PAY_PER_REQUEST `
  --region ap-southeast-1
```

```powershell
# Wait for table to become ACTIVE
aws dynamodb wait table-exists `
  --table-name cdcu-terraform-locks-sit `
  --region ap-southeast-1
```

No output from the wait command = table is ACTIVE.

Verify both exist:
```powershell
aws s3api head-bucket --bucket cdcu-terraform-state-sit-<sandbox-account-id>

aws dynamodb describe-table `
  --table-name cdcu-terraform-locks-sit `
  --region ap-southeast-1 `
  --query "Table.TableStatus"
```

Expected: `"ACTIVE"`

---

## Step 7 — Update backend.tf

After creating the bucket with the account ID suffix, update
`environments/sit/backend.tf` to match:

```hcl
terraform {
  backend "s3" {
    bucket         = "cdcu-terraform-state-sit-<sandbox-account-id>"
    key            = "cdcu/sit/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "cdcu-terraform-locks-sit"
    encrypt        = true
  }
}
```

---

## Step 8 — Create Secrets Manager Secrets

Placeholder secrets so the Glue module can resolve them at `terraform plan` time.
Real credentials will be provided by BPI MS in their environment.

```powershell
aws secretsmanager create-secret `
  --name "cdcu/sit/microsite-mysql-connection" `
  --description "CDCU sit Microsite MySQL placeholder" `
  --secret-string '{\"host\":\"placeholder.rds.amazonaws.com\",\"port\":\"3306\",\"dbname\":\"cdcu\",\"username\":\"cdcu_user\",\"password\":\"placeholder\"}' `
  --region ap-southeast-1
```

Expected output:
```json
{
    "ARN": "arn:aws:secretsmanager:ap-southeast-1:<sandbox-account-id>:secret:cdcu/sit/microsite-mysql-connection-HF0p8D",
    "Name": "cdcu/sit/microsite-mysql-connection",
    "VersionId": "dc8f0740-f02d-43c5-97f9-5e4142e6c534"
}
```

```powershell
aws secretsmanager create-secret `
  --name "cdcu/sit/legacy-mysql-connection" `
  --description "CDCU sit Legacy MySQL placeholder" `
  --secret-string '{\"host\":\"placeholder.rds.amazonaws.com\",\"port\":\"3306\",\"dbname\":\"cdcu\",\"username\":\"cdcu_user\",\"password\":\"placeholder\"}' `
  --region ap-southeast-1
```

Expected output:
```json
{
    "ARN": "arn:aws:secretsmanager:ap-southeast-1:<sandbox-account-id>:secret:cdcu/sit/legacy-mysql-connection-c4xfKz",
    "Name": "cdcu/sit/legacy-mysql-connection",
    "VersionId": "ceb7436f-30e3-49f1-9e9b-a414dc4cb2b7"
}
```

Verify both secrets exist:
```powershell
aws secretsmanager list-secrets `
  --region ap-southeast-1 `
  --query "SecretList[?starts_with(Name, 'cdcu/sit')].Name"
```

Expected:
```json
[
    "cdcu/sit/microsite-mysql-connection",
    "cdcu/sit/legacy-mysql-connection"
]
```

---

## Step 9 — Fill in terraform.tfvars

Open `environments/sit/terraform.tfvars` and fill in the values collected
from Steps 2–4:

```hcl
environment        = "sit"
terraform_role_arn = "arn:aws:iam::<sandbox-account-id>:role/<your-sandbox-deployment-role>"

vpc_id    = "<vpc-id from Step 2>"
subnet_id = "<subnet-id from Step 3>"
subnet_ids = [
  "<subnet-id from Step 3>"
]
availability_zone = "ap-southeast-1a"

existing_security_group_id = "<sg-id from Step 4>"

github_org         = "<your-github-org>"
github_repo        = "terraform-etl-analytics"
git_repository_url = "https://github.com/<your-github-org>/terraform-etl-analytics.git"

enable_kms    = false
sns_topic_arn = ""

glue_worker_count = 2
glue_worker_type  = "G.1X"

# Placeholder JDBC URLs — Glue connections will not actually connect in sandbox
# Real RDS endpoints will be provided by BPI MS
microsite_jdbc_url = "jdbc:mysql://placeholder.rds.amazonaws.com:3306/microsite_db"
legacy_jdbc_url    = "jdbc:mysql://placeholder.rds.amazonaws.com:3306/legacy_db"

enable_sagemaker_unified_studio          = true
sagemaker_studio_user_profile_names      = ["data-scientist-01"]
sagemaker_studio_space_instance_type     = "ml.t3.medium"
sagemaker_studio_space_volume_size_gb    = 5

# Use PublicInternetOnly in sandbox — no SageMaker VPC endpoints provisioned
# BPI MS environment uses VpcOnly
sagemaker_studio_app_network_access_type = "PublicInternetOnly"

# Keep QuickSight disabled until Phase 2 validation
enable_quicksight              = false
quicksight_admin_principal_arn = ""
quicksight_spice_capacity_gb   = 10

manage_iam                = false
terraform_lock_table_name = "cdcu-terraform-locks-sit"

existing_glue_execution_role_arn      = ""
existing_sagemaker_execution_role_arn = ""
existing_quicksight_access_role_arn   = ""
existing_kms_key_arn                  = ""
```

---

## Step 10 — Run Terraform

```powershell
cd environments/sit

terraform init
terraform fmt -check -recursive ../../
terraform validate
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

---

## Step 11 — Quick Verification After Apply

```powershell
# S3 buckets created by Terraform
aws s3 ls --region ap-southeast-1 | findstr cdcu

# Glue catalog database
aws glue get-database --name cdcu_sit_catalog --region ap-southeast-1

# Athena workgroup
aws athena get-work-group `
  --work-group cdcu-sit-workgroup `
  --region ap-southeast-1 `
  --query "WorkGroup.State"

# SageMaker Studio domain
aws sagemaker list-domains `
  --region ap-southeast-1 `
  --query "Domains[?DomainName=='cdcu-sit-studio'].Status"

# IAM roles created
aws iam list-roles `
  --query "Roles[?starts_with(RoleName, 'ST-CDCU')].RoleName"
```

---

## Sandbox vs BPI MS Differences

| Item | Sandbox (Stratpoint) | BPI MS Environment |
|---|---|---|
| VPC / Subnet / SG | Created manually each reset | Pre-provisioned by BPI MS |
| Route table | VPC main route table (auto-created) | BPI MS managed |
| VPC endpoints | Created manually each reset | Pre-provisioned by BPI MS |
| S3 state bucket name | Suffixed with account ID (`-<sandbox-account-id>`) | BPI MS naming convention |
| Deployment role | Sandbox admin role | BPI MS approved deployment role |
| RDS / MySQL | Placeholder JDBC URLs | Real RDS endpoints |
| Secrets Manager values | Placeholder credentials | Real credentials by BPI MS |
| KMS encryption | Disabled (`enable_kms = false`) | Enabled in prod |
| SageMaker network | `PublicInternetOnly` | `VpcOnly` |
| QuickSight | Disabled for now | Enabled after Phase 2 validation |

---

## Cost Control — Stop These When Not Testing

| Resource | How to Stop |
|---|---|
| SageMaker JupyterLab apps | Console → SageMaker → Spaces → Stop app |
| Glue jobs | Only charge when running — no idle cost |
| S3 / Athena / IAM | Minimal or no idle cost |

Run `terraform destroy` when done with the sandbox session to avoid charges.

---

## Checklist — Before Every `terraform apply`

- [ ] AWS CLI identity verified (`aws sts get-caller-identity`)
- [ ] VPC created — note VPC ID
- [ ] Private subnet created in `ap-southeast-1a` — note Subnet ID
- [ ] Security group created with self-referencing inbound rule + HTTPS from `10.0.0.0/16` — note SG ID
- [ ] S3 Gateway endpoint created and associated with main route table
- [ ] Secrets Manager Interface endpoint created and Available
- [ ] Glue Interface endpoint created and Available
- [ ] CloudWatch Logs Interface endpoint created and Available
- [ ] S3 state bucket `cdcu-terraform-state-sit-<sandbox-account-id>` exists
- [ ] DynamoDB lock table `cdcu-terraform-locks-sit` exists and is ACTIVE
- [ ] `environments/sit/backend.tf` bucket name matches the S3 state bucket
- [ ] Both Secrets Manager secrets exist (`cdcu/sit/microsite-mysql-connection` and `cdcu/sit/legacy-mysql-connection`)
- [ ] `terraform.tfvars` filled with current session IDs
