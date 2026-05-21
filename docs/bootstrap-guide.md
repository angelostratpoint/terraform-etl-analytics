# CDCU Terraform Bootstrap Guide

This guide covers the one-time setup required before running `terraform init` for any environment.

## What Bootstrap Provisions

| Resource | Name | Purpose |
|---|---|---|
| S3 Bucket | `cdcu-terraform-state-{environment}` | Stores Terraform remote state |
| DynamoDB Table | `cdcu-terraform-locks-{environment}` | Prevents concurrent state writes |

These must exist **before** `terraform init` is run. They are not managed by Terraform itself.

---

## Prerequisites

- AWS CLI installed and configured
- IAM user or role with `AdministratorAccess` or equivalent S3 and DynamoDB permissions
- Target region: `ap-southeast-1`

---

## Option 1: Linux / macOS (bash)

```bash
cd bootstrap
chmod +x bootstrap.sh
./bootstrap.sh sit
./bootstrap.sh uat
./bootstrap.sh prod
```

---

## Option 2: Windows PowerShell (manual steps)

Run the following commands per environment. Replace `sit` with `uat` or `prod` as needed.

### Step 1 — Create S3 state bucket

```powershell
aws s3api create-bucket `
  --bucket cdcu-terraform-state-sit `
  --region ap-southeast-1 `
  --create-bucket-configuration LocationConstraint=ap-southeast-1
```

### Step 2 — Enable versioning

```powershell
aws s3api put-bucket-versioning `
  --bucket cdcu-terraform-state-sit `
  --versioning-configuration Status=Enabled
```

### Step 3 — Block public access

```powershell
aws s3api put-public-access-block `
  --bucket cdcu-terraform-state-sit `
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

> Note: S3 encryption (AES256) is enabled by default in `ap-southeast-1` since 2023. No manual encryption step is required.

### Step 4 — Create DynamoDB lock table

```powershell
aws dynamodb create-table `
  --table-name cdcu-terraform-locks-sit `
  --attribute-definitions AttributeName=LockID,AttributeType=S `
  --key-schema AttributeName=LockID,KeyType=HASH `
  --billing-mode PAY_PER_REQUEST `
  --region ap-southeast-1
```

### Step 5 — Wait for DynamoDB table to be active

```powershell
aws dynamodb wait table-exists `
  --table-name cdcu-terraform-locks-sit `
  --region ap-southeast-1
```

---

## After Bootstrap

Once the S3 bucket and DynamoDB table are active, proceed with Terraform:

```powershell
cd environments/sit
terraform init
terraform validate
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

---

## Verification

Confirm the backend resources exist before running `terraform init`:

```powershell
aws s3api head-bucket --bucket cdcu-terraform-state-sit
aws dynamodb describe-table --table-name cdcu-terraform-locks-sit --region ap-southeast-1
```

Both commands should return without error.

---

## Notes for BPI MS Environment

- The bootstrap steps are run **once per environment** by the Stratpoint engineer during initial setup.
- In the BPI MS AWS account, ensure the IAM role used has permissions to create S3 buckets and DynamoDB tables in `ap-southeast-1`.
- The `dynamodb_table` parameter in `backend.tf` may show a deprecation warning in Terraform `>= 1.10`. This is a warning only and does not affect functionality. It will be updated to `use_lockfile` in a future release.
- The S3 bucket name must be globally unique. If `cdcu-terraform-state-sit` is already taken, append an approved account/environment suffix and update `backend.tf` accordingly.
