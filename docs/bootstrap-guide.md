# CDCU Terraform Bootstrap Guide

This guide covers the one-time Terraform backend setup required before running
`terraform init` for each CDCU environment.

## Backend Resources

Terraform uses an S3 backend and DynamoDB state locking.

| Resource | Naming pattern | Purpose |
|---|---|---|
| S3 bucket | `cdcu-terraform-state-{env}` | Stores Terraform remote state |
| DynamoDB table | `cdcu-terraform-locks-{env}` | Prevents concurrent Terraform state writes |

These backend resources must exist before `terraform init` is run. They are not
created by the environment Terraform roots.

## Environments

Create one backend pair per environment:

| Environment | State bucket | Lock table |
|---|---|---|
| SIT | `cdcu-terraform-state-sit` | `cdcu-terraform-locks-sit` |
| UAT | `cdcu-terraform-state-uat` | `cdcu-terraform-locks-uat` |
| Prod | `cdcu-terraform-state-prod` | `cdcu-terraform-locks-prod` |

If BPI-MS requires account-specific suffixes for globally unique S3 bucket names,
update the matching `backend.tf` file in the affected environment before running
`terraform init`.

## Prerequisites

- AWS CLI v2 installed.
- AWS credentials or role session configured for the target BPI-MS account.
- Permissions to create or manage the approved Terraform backend S3 bucket and
  DynamoDB lock table.
- Target region: `ap-southeast-1`.

## Bash Bootstrap

From the repository root:

```bash
cd bootstrap
chmod +x bootstrap.sh
./bootstrap.sh sit
./bootstrap.sh uat
./bootstrap.sh prod
```

## PowerShell Bootstrap

Run the following commands per environment. Replace `sit` with `uat` or `prod`
as needed.

Create the S3 state bucket:

```powershell
aws s3api create-bucket `
  --bucket cdcu-terraform-state-sit `
  --region ap-southeast-1 `
  --create-bucket-configuration LocationConstraint=ap-southeast-1
```

Enable bucket versioning:

```powershell
aws s3api put-bucket-versioning `
  --bucket cdcu-terraform-state-sit `
  --versioning-configuration Status=Enabled
```

Block public access:

```powershell
aws s3api put-public-access-block `
  --bucket cdcu-terraform-state-sit `
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

Create the DynamoDB lock table:

```powershell
aws dynamodb create-table `
  --table-name cdcu-terraform-locks-sit `
  --attribute-definitions AttributeName=LockID,AttributeType=S `
  --key-schema AttributeName=LockID,KeyType=HASH `
  --billing-mode PAY_PER_REQUEST `
  --region ap-southeast-1
```

Wait for the lock table:

```powershell
aws dynamodb wait table-exists `
  --table-name cdcu-terraform-locks-sit `
  --region ap-southeast-1
```

## Verification

Confirm the backend resources exist before `terraform init`:

```powershell
aws s3api head-bucket --bucket cdcu-terraform-state-sit
aws dynamodb describe-table `
  --table-name cdcu-terraform-locks-sit `
  --region ap-southeast-1 `
  --query "Table.TableStatus"
```

The DynamoDB status should be `ACTIVE`.

## Next Step

After bootstrap, continue with the environment deployment guide:

```powershell
cd environments/sit
terraform init
terraform validate
terraform plan -var-file="terraform.tfvars" -out=tfplan
```

The `dynamodb_table` backend argument may show a deprecation warning in newer
Terraform versions. This is a warning only and does not block the current
deployment flow.
