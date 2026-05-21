# CDCU Sandbox Setup Guide

This guide captures the original CDCU sit sandbox setup flow used during early
testing. After the SIT/UAT/Prod environment split, use `environments/sit` for new
sandbox-style validation unless you are intentionally reproducing the older sit
test path.

---

## Prerequisites Checklist

Before running any command, confirm the following on the sandbox account:

- [ ] AWS CLI v2 installed and configured locally
- [ ] Terraform >= 1.6.0 installed locally
- [ ] Sandbox AWS account ID obtained
- [ ] IAM deployment role exists or has been created
- [ ] VPC, subnet, and security group IDs obtained from sandbox admin
- [ ] GitHub repo access confirmed (`angelostratpoint/terraform-etl-analytics`)

---

## Step 1 — Obtain Sandbox Account Baseline Values

Request the following from the Stratpoint sandbox account admin before proceeding:

| Value | Description | Where to Get |
|---|---|---|
| AWS Account ID | 12-digit sandbox account ID | AWS Console → top right account menu |
| Deployment Role ARN | IAM role Terraform assumes | `aws iam list-roles` or sandbox admin |
| VPC ID | VPC for Glue and SageMaker placement | `aws ec2 describe-vpcs --region ap-southeast-1` |
| Subnet ID | Subnet for Glue connection (single AZ) | `aws ec2 describe-subnets --region ap-southeast-1` |
| Availability Zone | Must match the subnet | Same describe-subnets output |
| Security Group ID | For Glue JDBC and SageMaker VPC | `aws ec2 describe-security-groups --region ap-southeast-1` |

---

## Step 2 — Bootstrap Remote State

The S3 bucket and DynamoDB table for Terraform state must exist before `terraform init`.
Run this once on the sandbox account:

```powershell
# Windows PowerShell — run from repo root
aws s3api create-bucket `
  --bucket cdcu-terraform-state-sit `
  --region ap-southeast-1 `
  --create-bucket-configuration LocationConstraint=ap-southeast-1

aws s3api put-bucket-versioning `
  --bucket cdcu-terraform-state-sit `
  --versioning-configuration Status=Enabled

aws s3api put-public-access-block `
  --bucket cdcu-terraform-state-sit `
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

aws dynamodb create-table `
  --table-name cdcu-terraform-locks-sit `
  --attribute-definitions AttributeName=LockID,AttributeType=S `
  --key-schema AttributeName=LockID,KeyType=HASH `
  --billing-mode PAY_PER_REQUEST `
  --region ap-southeast-1

aws dynamodb wait table-exists `
  --table-name cdcu-terraform-locks-sit `
  --region ap-southeast-1
```

Verify both exist:
```powershell
aws s3api head-bucket --bucket cdcu-terraform-state-sit
aws dynamodb describe-table --table-name cdcu-terraform-locks-sit --region ap-southeast-1 --query "Table.TableStatus"
```

---

## Step 3 — Create Secrets Manager Secrets

The Glue module looks up these two secrets at `terraform plan` time. They must exist
in the sandbox account before plan will succeed. Values are placeholders for now —
BPI MS will populate real credentials when the pipeline connects to their RDS.

```powershell
aws secretsmanager create-secret `
  --name "cdcu/sit/microsite-mysql-connection" `
  --description "CDCU sit Microsite MySQL connection credentials" `
  --secret-string '{\"host\":\"placeholder.rds.amazonaws.com\",\"port\":\"3306\",\"dbname\":\"cdcu\",\"username\":\"cdcu_user\",\"password\":\"placeholder\"}' `
  --region ap-southeast-1

aws secretsmanager create-secret `
  --name "cdcu/sit/legacy-mysql-connection" `
  --description "CDCU sit Legacy MySQL connection credentials" `
  --secret-string '{\"host\":\"placeholder.rds.amazonaws.com\",\"port\":\"3306\",\"dbname\":\"cdcu\",\"username\":\"cdcu_user\",\"password\":\"placeholder\"}' `
  --region ap-southeast-1
```

Verify both exist:
```powershell
aws secretsmanager list-secrets `
  --region ap-southeast-1 `
  --query "SecretList[?starts_with(Name, 'cdcu/sit')].Name"
```

Expected output:
```json
[
    "cdcu/sit/microsite-mysql-connection",
    "cdcu/sit/legacy-mysql-connection"
]
```

---

## Step 4 — Fill in terraform.tfvars

Open `environments/sit/terraform.tfvars` and replace all `<FILL_IN: ...>` values
with the actual sandbox values obtained in Step 1.

Required fields to fill:
- `terraform_role_arn`
- `vpc_id`
- `subnet_id` and `subnet_ids`
- `existing_security_group_id`

Leave `microsite_jdbc_url` and `legacy_jdbc_url` as placeholders until BPI MS
provides the real RDS endpoints.

Leave `enable_quicksight = false` until QuickSight is confirmed in Step 6.

---

## Step 5 — Initialize and Deploy

```powershell
cd environments/sit

# Initialize — downloads providers and connects to remote state
terraform init

# Format check
terraform fmt -check -recursive ../../

# Validate
terraform validate

# Plan — review what will be created
terraform plan -var-file="terraform.tfvars" -out=tfplan

# Apply
terraform apply tfplan
```

---

## Step 6 — QuickSight Setup (Optional for Sandbox)

QuickSight requires a paid subscription. To enable it on the sandbox:

1. Go to AWS Console → QuickSight → Sign up for QuickSight
2. Choose Standard or Enterprise edition
3. Select `ap-southeast-1` as the region
4. Complete subscription

Then get the admin user ARN:
```powershell
aws quicksight list-users `
  --aws-account-id {sandbox-account-id} `
  --namespace default `
  --region ap-southeast-1 `
  --query "UserList[].Arn"
```

Update `terraform.tfvars`:
```hcl
enable_quicksight              = true
quicksight_admin_principal_arn = "arn:aws:quicksight:ap-southeast-1:{account_id}:user/default/{username}"
```

Then re-run plan and apply.

---

## Step 7 — Upload Dummy Data and Test Pipeline

Once infrastructure is provisioned, upload the dummy data to test the pipeline:

```powershell
cd environments/sit

aws s3 cp dummy_microsite.csv s3://cdcu-sit-data-lake/raw/microsite/dummy_microsite.csv --region ap-southeast-1
aws s3 cp dummy_legacy.csv s3://cdcu-sit-data-lake/raw/legacy/dummy_legacy.csv --region ap-southeast-1
```

Run the raw crawlers to register tables in the Glue catalog:
```powershell
aws glue start-crawler --name cdcu-sit-microsite-raw-crawler --region ap-southeast-1
aws glue start-crawler --name cdcu-sit-legacy-raw-crawler --region ap-southeast-1
```

Wait for crawlers to complete:
```powershell
aws glue get-crawler --name cdcu-sit-microsite-raw-crawler --region ap-southeast-1 --query "Crawler.State"
aws glue get-crawler --name cdcu-sit-legacy-raw-crawler --region ap-southeast-1 --query "Crawler.State"
```

Verify tables in Athena:
```sql
SELECT * FROM cdcu_sit_catalog.microsite LIMIT 10;
SELECT * FROM cdcu_sit_catalog.legacy LIMIT 10;
```

---

## Step 8 — Network Verification for Glue

Before running Glue jobs, confirm the sandbox VPC has the S3 Gateway endpoint
associated with the route table used by the Glue subnet. This was Error 20 in
the previous test account.

```powershell
# Get the subnet's route table
aws ec2 describe-route-tables `
  --filters "Name=association.subnet-id,Values={subnet_id}" `
  --region ap-southeast-1 `
  --query "RouteTables[0].RouteTableId"

# If null, get the VPC main route table
aws ec2 describe-route-tables `
  --filters "Name=vpc-id,Values={vpc_id}" "Name=association.main,Values=true" `
  --region ap-southeast-1 `
  --query "RouteTables[0].RouteTableId"

# Check if S3 endpoint exists and is associated
aws ec2 describe-vpc-endpoints `
  --filters "Name=vpc-id,Values={vpc_id}" "Name=service-name,Values=com.amazonaws.ap-southeast-1.s3" `
  --region ap-southeast-1 `
  --query "VpcEndpoints[0].{Id:VpcEndpointId,RouteTables:RouteTableIds}"
```

If the S3 endpoint has no route tables associated, associate it:
```powershell
aws ec2 modify-vpc-endpoint `
  --vpc-endpoint-id {vpce-id} `
  --add-route-table-ids {route-table-id} `
  --region ap-southeast-1
```

---

## Step 9 — Post-Deployment Verification

Run these to confirm everything is provisioned correctly:

```powershell
# Terraform outputs
terraform output

# S3 buckets
aws s3 ls --region ap-southeast-1 | findstr cdcu

# Glue jobs
aws glue list-jobs --region ap-southeast-1

# Glue crawlers
aws glue list-crawlers --region ap-southeast-1

# Athena workgroup
aws athena get-work-group --work-group cdcu-sit-workgroup --region ap-southeast-1 --query "WorkGroup.State"

# SageMaker domain
aws sagemaker list-domains --region ap-southeast-1 --query "Domains[?DomainName=='cdcu-sit-studio']"

# IAM roles
aws iam list-roles --query "Roles[?starts_with(RoleName, 'ST-CDCU')].RoleName"

# All CDCU tagged resources
aws resourcegroupstaggingapi get-resources `
  --tag-filters Key=Project,Values=CDCU `
  --region ap-southeast-1 `
  --query "ResourceTagMappingList[].ResourceARN"
```

---

## Step 10 — Cost Control

To avoid unexpected charges on the sandbox:

- Stop SageMaker JupyterLab apps when not in use — they bill hourly
- Glue jobs only charge when running — no idle cost
- S3, Athena, IAM have minimal or no idle cost
- Run `terraform destroy` when sandbox testing is complete

To delete a running JupyterLab app:
```powershell
aws sagemaker delete-app `
  --domain-id {domain_id} `
  --user-profile-name {user_profile_name}-jupyterlab `
  --app-type JupyterLab `
  --app-name default `
  --region ap-southeast-1
```

---

## Differences Between Sandbox and BPI MS Environment

| Item | Sandbox | BPI MS |
|---|---|---|
| RDS / MySQL source | Placeholder JDBC URLs | Real RDS endpoints from BPI MS |
| Secrets Manager values | Placeholder credentials | Real credentials populated by BPI MS |
| KMS encryption | Disabled (`enable_kms = false`) | Enabled in prod (`enable_kms = true`) |
| QuickSight | Optional for testing | Required for prod dashboards |
| VPC/subnet/SG | Stratpoint sandbox network | BPI MS managed network |
| Deployment role | Sandbox role | BPI MS approved deployment role |
| S3 VPC endpoint | Verify manually | BPI MS must associate with route table |
| `sagemaker_studio_app_network_access_type` | `PublicInternetOnly` (if no VPC endpoints) | `VpcOnly` |

---

## Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `NoSuchBucket` on terraform init | Bootstrap not run | Run Step 2 |
| `ResourceNotFoundException: Secret not found` | Secrets not created | Run Step 3 |
| `existing_security_group_id is required` | tfvars not filled | Fill Step 4 |
| `microsite_jdbc_url must be a non-local MySQL JDBC URL` | localhost in JDBC URL | Use placeholder.rds.amazonaws.com |
| Glue job fails — S3 VPC endpoint | No S3 route | Run Step 8 |
| SageMaker Studio app won't start | VpcOnly + no VPC endpoints | Change to PublicInternetOnly |
| QuickSight group ARNs all null | QuickSight not subscribed | Run Step 6 or keep disabled |

For additional errors, refer to `docs/errors-and-resolutions.md`.
