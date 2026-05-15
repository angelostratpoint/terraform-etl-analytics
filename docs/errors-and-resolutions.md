# CDCU Terraform — Errors and Resolutions

This document captures all errors encountered during the initial pre-production Terraform setup and their resolutions. Use this as a reference when setting up the BPI MS environment.

---

## Error 1: Git Repository Not Initialized

**Command:** `git status`

**Error:**
```
fatal: not a git repository (or any of the parent directories): .git
```

**Cause:** The local project folder was never initialized as a Git repository.

**Resolution:**
```bash
git init
git remote add origin https://github.com/angelostratpoint/terraform-etl-analytics.git
git remote -v
```

---

## Error 2: Git Author Identity Unknown

**Command:** `git commit -m "..."`

**Error:**
```
Author identity unknown
fatal: unable to auto-detect email address
```

**Cause:** Git global user identity was not configured on the machine.

**Resolution:**
```bash
git config --global user.email "your-email@stratpoint.com"
git config --global user.name "your-github-username"
```

---

## Error 3: S3 Backend Bucket Does Not Exist

**Command:** `terraform init`

**Error:**
```
Error: Failed to get existing workspaces: S3 bucket "cdcu-terraform-state-pre-prod" does not exist.
```

**Cause:** The Terraform remote state S3 bucket and DynamoDB lock table must be created before `terraform init` is run. The `bootstrap.sh` script handles this on Linux/macOS but must be run manually on Windows.

**Resolution:** Run the bootstrap steps manually via AWS CLI on Windows PowerShell. See `docs/bootstrap-guide.md` for the full steps.

---

## Error 4: S3 Bucket Encryption JSON Parsing Error on Windows

**Command:** `aws s3api put-bucket-encryption --server-side-encryption-configuration "{...}"`

**Error:**
```
aws: [ERROR]: Unknown options: Rules\:[{\ApplyServerSideEncryptionByDefault\:...
```

**Cause:** PowerShell escapes double quotes differently from bash, causing the JSON to be malformed when passed inline.

**Resolution:** S3 buckets in `ap-southeast-1` have AES256 encryption enabled by default since 2023. The encryption step can be skipped entirely on Windows:

```
# No action needed — AES256 is the default encryption for all new S3 buckets in ap-southeast-1
```

If encryption must be set explicitly, use a PowerShell variable:
```powershell
$encryption = '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'
aws s3api put-bucket-encryption --bucket cdcu-terraform-state-pre-prod --server-side-encryption-configuration $encryption
```

> Note: PowerShell may still strip the double quotes from the variable. If the error persists, skip this step as the default encryption is sufficient.

---

## Error 5: Unsupported Argument `kms_key` in Athena Module

**Command:** `terraform validate`

**Error:**
```
Error: Unsupported argument
  on ..\..\modules\athena\main.tf line 15, in resource "aws_athena_workgroup" "cdcu":
  15: kms_key = var.enable_kms ? var.kms_key_arn : null
An argument named "kms_key" is not expected here.
```

**Cause:** The `encryption_configuration` block inside `aws_athena_workgroup` uses `kms_key_arn` not `kms_key`.

**File:** `modules/athena/main.tf`

**Resolution:** Rename the argument:
```hcl
# Before
kms_key = var.enable_kms ? var.kms_key_arn : null

# After
kms_key_arn = var.enable_kms ? var.kms_key_arn : null
```

---

## Error 6: Unsupported Block Type `permission` in QuickSight Dataset

**Command:** `terraform validate`

**Error:**
```
Error: Unsupported block type
  on ..\..\modules\quicksight\main.tf line 136, in resource "aws_quicksight_data_set" "matching_results":
  136: dynamic "permission" {
Blocks of type "permission" are not expected here.
```

**Cause:** The `aws_quicksight_data_set` resource does not support a `permission` block. The dynamic permission blocks were incorrectly added to both `aws_quicksight_data_source` and `aws_quicksight_data_set`.

**File:** `modules/quicksight/main.tf`

**Resolution:** Remove the `dynamic "permission"` blocks from both `aws_quicksight_data_source` and `aws_quicksight_data_set` resources. QuickSight permissions are managed separately via `aws_quicksight_data_source_permissions` and `aws_quicksight_data_set_permissions` resources if needed.

---

## Error 7: Cannot Assume IAM Role — User ARN Used Instead of Role ARN

**Command:** `terraform plan`

**Error:**
```
Error: Cannot assume IAM Role
IAM Role (arn:aws:iam::<account-id>:user/<terraform-operator>) cannot be assumed.
Error: operation error STS: AssumeRole, AccessDenied: User is not authorized to perform sts:AssumeRole on resource: arn:aws:iam::<account-id>:user/<terraform-operator>
```

**Cause:** The `terraform_role_arn` variable in `terraform.tfvars` was set to an IAM **user** ARN. The `assume_role` block in `providers.tf` requires an IAM **role** ARN. You cannot assume a user.

**Resolution — Option A (Recommended for BPI MS):** Create a dedicated IAM deployment role and use its ARN:
```hcl
terraform_role_arn = "arn:aws:iam::<account_id>:role/cdcu-pre-prod-terraform-deployment-role"
```

**Resolution — Option B (Testing only — do not commit):** Remove the `assume_role` block from `environments/pre-prod/providers.tf` so Terraform uses the current AWS CLI credentials directly:
```hcl
provider "aws" {
  region = "ap-southeast-1"

  default_tags {
    tags = {
      Project     = "CDCU"
      Environment = "pre-prod"
      ManagedBy   = "Terraform"
      Owner       = "Stratpoint"
      CostCenter  = "CDCU-PRE-PROD"
    }
  }
}
```

> Option B was used for the local testing run. In the BPI MS environment, Option A must be used with the proper deployment role ARN provided by BPI MS.

---

## Warning: Deprecated `dynamodb_table` Parameter

**Command:** `terraform init` / `terraform plan`

**Warning:**
```
Warning: Deprecated Parameter
  on backend.tf line 6, in terraform:
  6: dynamodb_table = "cdcu-terraform-locks-pre-prod"
The parameter "dynamodb_table" is deprecated. Use parameter "use_lockfile" instead.
```

**Cause:** Terraform `>= 1.10` deprecated the `dynamodb_table` backend parameter in favor of `use_lockfile`.

**Impact:** Warning only — does not affect functionality. State locking still works correctly.

**Future Resolution:** Update `backend.tf` in both environments when migrating to the new locking mechanism:
```hcl
# Replace:
dynamodb_table = "cdcu-terraform-locks-pre-prod"

# With:
use_lockfile = true
```

> Do not apply this change until the DynamoDB table is no longer needed and the team has confirmed the new lock file approach is acceptable.

---

## Error 8: IAM Group Policy Limit Exceeded

**Command:** `terraform apply tfplan`

**Error:**
```
Error: attaching IAM Policy to IAM Group (ST-CDCU-pre-prod-CloudEngineering):
LimitExceeded: Cannot exceed quota for PoliciesPerGroup: 10
```

**Cause:** AWS enforces a hard limit of 10 managed policies per IAM group. The `ST-CDCU-pre-prod-CloudEngineering` group had 12 policies attached — exceeding the limit by 2. The two failing attachments were `GlueCloudWatchLogs` and `SageMakerCloudWatchLogs`.

**File:** `modules/iam/main.tf`

**Resolution:** Merged the separate `GlueCloudWatchLogs` and `SageMakerCloudWatchLogs` policies into a single combined policy `CECloudWatchLogsAccess` covering both `/aws/glue/*` and `/aws/sagemaker/*` log groups. This reduced the group attachment count from 12 to 10.

> Note: The AWS default quota for `PoliciesPerGroup` is 10 and cannot be increased via Service Quotas. Always count group policy attachments when designing IAM modules.

---

## Error 9: IAM Group Policy Limit Exceeded — Combined Policy Still Blocked

**Command:** `terraform apply tfplan`

**Error:**
```
Error: attaching IAM Policy (arn:aws:iam::<account-id>:policy/ST-CDCU-pre-prod-CECloudWatchLogsAccess) to IAM Group (ST-CDCU-pre-prod-CloudEngineering):
LimitExceeded: Cannot exceed quota for PoliciesPerGroup: 10
```

**Cause:** Even after merging the two CloudWatch policies into one combined policy (Error 8 fix), the `ST-CDCU-pre-prod-CloudEngineering` group still had 10 policies already attached from the previous partial apply. The new combined policy could not be added because all 10 slots were already occupied.

The 10 attached policies were:
1. `ST-CDCU-pre-prod-DynamoDBStateLock`
2. `ST-CDCU-pre-prod-GlueSecretsRead`
3. `ST-CDCU-pre-prod-GlueCrawlerAndETL`
4. `ST-CDCU-pre-prod-SageMakerS3Access`
5. `ST-CDCU-pre-prod-AthenaAccess`
6. `ST-CDCU-pre-prod-DenySensitiveServices`
7. `ST-CDCU-pre-prod-SageMakerAccess`
8. `ST-CDCU-pre-prod-EventBridgeAccess`
9. `ST-CDCU-pre-prod-GlueS3Access`
10. `ST-CDCU-pre-prod-AmazonQDeveloperAccess`

**File:** `modules/iam/main.tf`

**Resolution:** Removed `ST-CDCU-pre-prod-AmazonQDeveloperAccess` from the `CloudEngineering` group attachment — it is not required for pipeline operations and can be granted individually to users who need it.

Step 1 — Detach the policy manually via AWS CLI:
```powershell
aws iam detach-group-policy `
  --group-name ST-CDCU-pre-prod-CloudEngineering `
  --policy-arn arn:aws:iam::<account-id>:policy/ST-CDCU-pre-prod-AmazonQDeveloperAccess
```

Step 2 — Remove the `ce_amazon_q` group attachment from `modules/iam/main.tf` so Terraform does not re-add it.

Step 3 — Re-run plan and apply:
```powershell
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

The `CloudEngineering` group final policy list after fix:
1. `ST-CDCU-pre-prod-DynamoDBStateLock`
2. `ST-CDCU-pre-prod-GlueSecretsRead`
3. `ST-CDCU-pre-prod-GlueCrawlerAndETL`
4. `ST-CDCU-pre-prod-SageMakerS3Access`
5. `ST-CDCU-pre-prod-AthenaAccess`
6. `ST-CDCU-pre-prod-DenySensitiveServices`
7. `ST-CDCU-pre-prod-SageMakerAccess`
8. `ST-CDCU-pre-prod-EventBridgeAccess`
9. `ST-CDCU-pre-prod-GlueS3Access`
10. `ST-CDCU-pre-prod-CECloudWatchLogsAccess` ← new combined CloudWatch policy

> For BPI MS environment: Always audit the total number of group policy attachments before applying. AWS hard limit is 10 per group and cannot be increased.

---

## Error 10: Secrets Manager Secret Not Found — Glue MySQL Connection

**Command:** `terraform apply tfplan`

**Error:**
```
Error: reading Secrets Manager Secret (cdcu/pre-prod/microsite-mysql-connection): couldn't find resource
Error: reading Secrets Manager Secret (cdcu/pre-prod/legacy-mysql-connection): couldn't find resource
Error: creating Glue Connection (cdcu-pre-prod-microsite-mysql):
InvalidInputException: Validation for connection properties failed
Error: creating Glue Connection (cdcu-pre-prod-legacy-mysql):
InvalidInputException: Validation for connection properties failed
```

**Cause:** The Glue module looks up two Secrets Manager secrets at apply time:
- `cdcu/pre-prod/microsite-mysql-connection`
- `cdcu/pre-prod/legacy-mysql-connection`

These secrets do not exist in the AWS account because they are pre-requisites that must be created manually by BPI MS before Terraform runs. Per the project agreement, Terraform only references secret names — it does not create or populate secret values. Since the secrets were not present, the Glue JDBC connections also failed validation.

**Impact for testing:** Expected failure in the test environment. The Glue connections and extraction jobs require real MySQL source database credentials which are not available in the test account.

**Resolution for testing environment:** Create dummy secrets via AWS CLI to unblock the apply:

```powershell
aws secretsmanager create-secret `
  --name "cdcu/pre-prod/microsite-mysql-connection" `
  --secret-string '{"username":"test","password":"test","host":"localhost","port":3306,"dbname":"test"}' `
  --region ap-southeast-1

aws secretsmanager create-secret `
  --name "cdcu/pre-prod/legacy-mysql-connection" `
  --secret-string '{"username":"test","password":"test","host":"localhost","port":3306,"dbname":"test"}' `
  --region ap-southeast-1
```

Expected output after successful creation:
```json
{
  "ARN": "arn:aws:secretsmanager:ap-southeast-1:<account-id>:secret:cdcu/pre-prod/microsite-mysql-connection-xjffir",
  "Name": "cdcu/pre-prod/microsite-mysql-connection",
  "VersionId": "9784ae1d-f891-4ffc-b802-98243d7bfd29"
}
```

Once secrets exist, Terraform can read them and the plan reduces to only 4 resources:
- `aws_glue_connection.microsite_mysql`
- `aws_glue_connection.legacy_mysql`
- `aws_glue_job.microsite_raw_extraction`
- `aws_glue_job.legacy_raw_extraction`

Re-run plan and apply:
```powershell
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

---

## Error 11: Glue Connection Validation Failed — Missing JDBC_CONNECTION_URL

**Command:** `terraform apply tfplan`

**Error:**
```
Error: creating Glue Connection (cdcu-pre-prod-microsite-mysql):
InvalidInputException: Validation for connection properties failed
Error: creating Glue Connection (cdcu-pre-prod-legacy-mysql):
InvalidInputException: Validation for connection properties failed
```

**Cause:** AWS Glue JDBC connections require `JDBC_CONNECTION_URL` as a mandatory connection property even when using `SECRET_ID` for credentials. The original connection definition only had `SECRET_ID` which is insufficient for Glue to validate the connection type.

**File:** `modules/glue/main.tf`

**Resolution:** Add `JDBC_CONNECTION_URL` to both connection property blocks:

```hcl
# Before
connection_properties = {
  SECRET_ID = "cdcu/${var.environment}/microsite-mysql-connection"
}

# After
connection_properties = {
  JDBC_CONNECTION_URL = "jdbc:mysql://<rds-endpoint>:3306/<dbname>"
  SECRET_ID           = "cdcu/${var.environment}/microsite-mysql-connection"
}
```

> For testing, `localhost:3306/test` was used as a placeholder URL. In the BPI MS environment, replace with the actual RDS endpoint and database name. Credentials are always sourced from Secrets Manager at runtime — not from the URL.

---

## Error 12: SageMaker Studio Permission Warning — Missing Studio API Actions

**Location:** SageMaker Studio console when opening `cdcu-pre-prod-studio`

**Error:**
```
Permission issue detected. You may not be able to open any applications.
To ensure full functionality, please coordinate with your administrator to update
the permissions of your execution role to include:
sagemaker:listSpaces, sagemaker:listApps, sagemaker:describeApp
```

**Cause:** The `ST-CDCU-pre-prod-SageMakerAccess` policy was missing SageMaker Studio-specific API actions required for the Studio UI to function. The original policy only covered processing jobs, training jobs, models, endpoints, and pipelines — but not the Studio domain/space/app management actions.

**File:** `modules/iam/main.tf`

**Resolution:** Added the following actions to the `sagemaker_access` policy:
```
sagemaker:ListSpaces, sagemaker:DescribeSpace
sagemaker:ListApps, sagemaker:DescribeApp
sagemaker:CreateApp, sagemaker:DeleteApp
sagemaker:ListDomains, sagemaker:DescribeDomain
sagemaker:ListUserProfiles, sagemaker:DescribeUserProfile
```

The policy was updated immediately via AWS CLI without waiting for `terraform apply`:
```powershell
aws iam create-policy-version `
  --policy-arn arn:aws:iam::<account-id>:policy/ST-CDCU-pre-prod-SageMakerAccess `
  --set-as-default `
  --policy-document '{...updated policy JSON...}'
```

The `modules/iam/main.tf` file was also updated to include these permissions so future `terraform apply` runs will maintain the correct policy.

> For BPI MS environment: Ensure the SageMaker execution role includes all Studio API actions before provisioning the domain to avoid this warning.

---

## Error 12b: SageMaker Studio Permission Warning — Missing `CreatePresignedDomainUrl`

**Location:** SageMaker Studio console when opening `cdcu-pre-prod-studio`

**Error:**
```
Permission issue detected. You may not be able to open any applications.
To ensure full functionality, please coordinate with your administrator to update
the permissions of your execution role to include:
sagemaker:createPresignedDomainUrl
```

**Cause:** Even after the Error 12 fix, `sagemaker:CreatePresignedDomainUrl` was still missing from the `SageMakerAccess` policy. This action is required to generate the signed URL that opens the Studio UI — without it, the browser cannot redirect the user into the Studio environment.

**File:** `modules/iam/main.tf`

**Resolution:** Added `sagemaker:CreatePresignedDomainUrl` to the `SageMakerAccess` statement in `modules/iam/main.tf`:

```hcl
# Before
"sagemaker:ListUserProfiles", "sagemaker:DescribeUserProfile"

# After
"sagemaker:ListUserProfiles", "sagemaker:DescribeUserProfile",
"sagemaker:CreatePresignedDomainUrl"
```

Then re-run plan and apply:
```powershell
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

> For BPI MS environment: `sagemaker:CreatePresignedDomainUrl` must be included in the execution role policy from the start. Without it, users can see the Studio domain but cannot open any applications.

---

## Error 12c: SageMaker Studio Instance Fails to Launch — Missing `AddTags`

**Location:** SageMaker Studio console — instance fails to start when launching a space (e.g. `quickstart-cpu-smald9`)

**Error:**
```
User: arn:aws:sts::<account-id>:assumed-role/ST-CDCU-pre-prod-SageMakerExecutionRole/SageMaker
is not authorized to perform: sagemaker:AddTags on resource:
arn:aws:sagemaker:ap-southeast-1:<account-id>:space/d-hmatlfotlt4l/quickstart-cpu-smald9
because no identity-based policy allows the sagemaker:AddTags action
```

**Cause:** When SageMaker Studio launches a space or application, it automatically calls `sagemaker:AddTags` to tag the space resource with metadata. The `ST-CDCU-pre-prod-SageMakerExecutionRole` did not have this permission, causing the launch to fail immediately after the user clicks to start an instance.

**File:** `modules/iam/main.tf`

**Resolution:** Added `sagemaker:AddTags`, `sagemaker:ListTags`, and `sagemaker:DeleteTags` to the `SageMakerAccess` policy statement:

```hcl
# Before
"sagemaker:CreatePresignedDomainUrl"

# After
"sagemaker:CreatePresignedDomainUrl",
"sagemaker:AddTags", "sagemaker:ListTags", "sagemaker:DeleteTags"
```

Then re-run plan and apply:
```powershell
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

> `ListTags` and `DeleteTags` are included alongside `AddTags` as Studio uses all three during the space lifecycle (create, inspect, and clean up tags on spaces and apps).

> For BPI MS environment: Include all three tag actions in the SageMaker execution role from the start to avoid instance launch failures.

---

## Error 13: IAM Group Policy Limit — Stale State After Partial Apply

**Command:** `terraform apply tfplan`

**Error:**
```
Error: attaching IAM Policy (arn:aws:iam::<account-id>:policy/ST-CDCU-pre-prod-SageMakerCloudWatchLogs) to IAM Group (ST-CDCU-pre-prod-CloudEngineering):
operation error IAM: AttachGroupPolicy, https response error StatusCode: 409,
LimitExceeded: Cannot exceed quota for PoliciesPerGroup: 10

Error: attaching IAM Policy (arn:aws:iam::<account-id>:policy/ST-CDCU-pre-prod-AmazonQDeveloperAccess) to IAM Group (ST-CDCU-pre-prod-CloudEngineering):
operation error IAM: AttachGroupPolicy, https response error StatusCode: 409,
LimitExceeded: Cannot exceed quota for PoliciesPerGroup: 10
```

**Cause:** After `terraform destroy` and re-apply, the IAM module code still had the original 12 group attachments for `CloudEngineering`. The Error 8/9 fixes documented above were applied manually in AWS but were never fully reflected in `modules/iam/main.tf`. Specifically:

- The combined `CECloudWatchLogsAccess` policy existed in AWS state (from a previous partial apply) but was not in the Terraform code — so Terraform planned to destroy it.
- The separate `ce_glue_cloudwatch` and `ce_sagemaker_cloudwatch` attachments were still in the code — so Terraform planned to re-add them.
- `ce_amazon_q` was still in the code — so Terraform planned to re-add it.

This caused the plan to first destroy `ce_cloudwatch_combined`, then attempt to add `ce_glue_cloudwatch` (succeeds, fills slot 10), then fail on `ce_sagemaker_cloudwatch` and `ce_amazon_q` because all 10 slots were occupied.

**File:** `modules/iam/main.tf`

**Resolution:** Properly reconciled the code with the intended final state:

Step 1 — Replace the 12 separate CE group attachments in `modules/iam/main.tf` with exactly 10, using a new `ce_cloudwatch_combined` resource and removing `ce_glue_cloudwatch`, `ce_sagemaker_cloudwatch`, and `ce_amazon_q` from the group:

```hcl
# Add combined CloudWatch policy resource
resource "aws_iam_policy" "ce_cloudwatch_combined" {
  name = "ST-CDCU-${local.env}-CECloudWatchLogsAccess"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "CloudWatchLogsAllCDCU"
      Effect = "Allow"
      Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents",
                "logs:DescribeLogGroups", "logs:DescribeLogStreams", "logs:GetLogEvents"]
      Resource = [
        "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/glue/*",
        "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/sagemaker/*"
      ]
    }]
  })
  tags = var.tags
}

# Group attachment using combined policy — replaces ce_glue_cloudwatch + ce_sagemaker_cloudwatch
resource "aws_iam_group_policy_attachment" "ce_cloudwatch_combined" {
  group      = aws_iam_group.cloud_engineering.name
  policy_arn = aws_iam_policy.ce_cloudwatch_combined.arn
}

# Remove ce_glue_cloudwatch, ce_sagemaker_cloudwatch, and ce_amazon_q group attachments
```

The final 10 CE group attachments after fix:
1. `ST-CDCU-pre-prod-GlueS3Access`
2. `ST-CDCU-pre-prod-GlueCrawlerAndETL`
3. `ST-CDCU-pre-prod-GlueSecretsRead`
4. `ST-CDCU-pre-prod-CECloudWatchLogsAccess` ← combined Glue + SageMaker
5. `ST-CDCU-pre-prod-SageMakerAccess`
6. `ST-CDCU-pre-prod-SageMakerS3Access`
7. `ST-CDCU-pre-prod-AthenaAccess`
8. `ST-CDCU-pre-prod-DynamoDBStateLock`
9. `ST-CDCU-pre-prod-EventBridgeAccess`
10. `ST-CDCU-pre-prod-DenySensitiveServices`

> `AmazonQDeveloperAccess` policy is retained in the module (still used by the policy resource) but is no longer attached to the group. Grant it individually to users who need Amazon Q Developer access.

---

## Error 14: SageMaker Notebook Instance Not Provisioned — Wrong Instance Type and Count

**Location:** AWS Console → SageMaker → Notebook instances

**Issue:**
No notebook instance was provisioned despite 3.3.3 requiring one. The SageMaker Studio domain (`cdcu-pre-prod-studio`) was present and showing "Ready", but the agreed `ml.t3.medium` notebook instance was missing entirely.

**Cause:** Two incorrect values in `terraform.tfvars`:
- `sagemaker_notebook_instance_count` was set to `0` — so Terraform never created any notebook instance.
- `sagemaker_notebook_instance_type` was set to `ml.c4.2xlarge` — which does not match the agreed default spec in 3.3.3.

Note: The Studio domain and the notebook instance are two separate resources. The Studio domain (`aws_sagemaker_domain`) is the Unified Studio environment. The notebook instance (`aws_sagemaker_notebook_instance`) is the always-on compute resource per the agreed spec. Having the domain provisioned does not satisfy the notebook instance requirement.

**Agreed spec per 3.3.3:**
- Instance: `ml.t3.medium`
- Compute Type: Standard
- vCPU: 2
- Memory: 4 GiB
- Storage: EBS only

**File:** `environments/pre-prod/terraform.tfvars`

**Resolution:** Updated `terraform.tfvars` and `terraform.tfvars.example` to match the agreed spec:

```hcl
# Before
sagemaker_notebook_instance_count = 0
sagemaker_notebook_instance_type  = "ml.c4.2xlarge"

# After
sagemaker_notebook_instance_count = 1
sagemaker_notebook_instance_type  = "ml.t3.medium"
```

Then re-run plan and apply:
```powershell
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

The notebook instance `cdcu-pre-prod-notebook-01` will be created and visible under SageMaker → Notebook instances in the AWS console.

> For BPI MS environment: Confirm the notebook instance count and type against the agreed 3.3.3 spec before applying. The notebook instance incurs cost while running — coordinate with BPI MS on start/stop schedules.

---

## Error 15: SageMaker Notebook Instance Stuck in Pending — No Internet Access

**Command:** `terraform apply tfplan`

**Error:**
```
Error: waiting for SageMaker AI Notebook Instance (cdcu-pre-prod-notebook-01) create: context canceled

  with module.sagemaker.aws_sagemaker_notebook_instance.on_demand["0"],
  on ..\..\modules\sagemaker\main.tf line 50, in resource "aws_sagemaker_notebook_instance" "on_demand":
  50: resource "aws_sagemaker_notebook_instance" "on_demand" {
```

**Cause:** The notebook instance was provisioned with `direct_internet_access = "Disabled"` (the original default in `modules/sagemaker/variables.tf`). The VPC does not have a NAT Gateway or SageMaker VPC endpoints, so the instance had no way to reach SageMaker service endpoints during startup. It remained stuck in `Pending` for over 13 minutes until the apply was manually interrupted.

Note: The plan was generated and saved (`-out=tfplan`) before the `variables.tf` default was corrected to `Enabled`. The saved plan still carried the old `Disabled` value, which is why the fix did not take effect on that apply run.

**File:** `modules/sagemaker/variables.tf`

**Resolution:**

Step 1 — Update the default in `modules/sagemaker/variables.tf`:
```hcl
# Before
default = "Disabled"

# After
default = "Enabled"
```

Step 2 — Wait for the notebook instance to reach a stable state in AWS console (SageMaker → Notebook instances). If status is `Pending`, wait for it to become `InService` or `Failed`. If `InService`, stop it via the console first.

Step 3 — Generate a fresh plan (do NOT reuse the old tfplan) and apply:
```powershell
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

The new plan will show an in-place update:
```hcl
~ direct_internet_access = "Disabled" -> "Enabled"
```

The notebook instance will restart with internet access enabled and reach `InService` within the normal 5–10 minute window.

> For BPI MS environment: If the production VPC has a NAT Gateway or the following SageMaker VPC endpoints configured, `Disabled` is the correct and more secure setting:
> - `com.amazonaws.ap-southeast-1.sagemaker.api`
> - `com.amazonaws.ap-southeast-1.sagemaker.runtime`
> - `com.amazonaws.ap-southeast-1.sagemaker.notebook`
>
> The pre-prod VPC currently has only 4 endpoints (S3, Secrets Manager, Glue, CloudWatch Logs) — SageMaker endpoints are missing, which is why `Enabled` is required. Coordinate with BPI MS to add the SageMaker VPC endpoints before setting `Disabled` in production.

---

## Error 16: SageMaker Notebook Instance Failed — GitHub Credentials Not Configured

**Command:** `terraform apply tfplan`

**Error:**
```
Error: waiting for SageMaker AI Notebook Instance (cdcu-pre-prod-notebook-01) create:
unexpected state 'Failed', wanted target 'InService'.
last error: fatal: could not read Username for
'https://github.com/angelostratpoint/terraform-etl-analytics.git': terminal prompts disabled
```

**Cause:** The notebook instance had `default_code_repository` set to `cdcu-pre-prod-scripts`, which points to the GitHub repository via HTTPS. On startup, SageMaker attempts to clone the repository. Since no GitHub credentials (personal access token) were provided via `git_secret_arn`, the clone fails with a terminal prompts disabled error and the instance transitions to `Failed`.

**File:** `modules/sagemaker/main.tf`

**Resolution:** Removed `default_code_repository` from the `aws_sagemaker_notebook_instance` resource. The code repository resource (`aws_sagemaker_code_repository`) is retained for reference but is no longer attached to the notebook instance at launch:

```hcl
# Before
resource "aws_sagemaker_notebook_instance" "on_demand" {
  ...
  default_code_repository = aws_sagemaker_code_repository.cdcu_scripts.code_repository_name
}

# After
resource "aws_sagemaker_notebook_instance" "on_demand" {
  ...
  # default_code_repository removed — requires GitHub credentials via git_secret_arn
}
```

Then re-run plan and apply:
```powershell
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

> For BPI MS environment: To attach the code repository, create a Secrets Manager secret containing a GitHub personal access token and pass its ARN as `git_secret_arn` in `terraform.tfvars`. The secret must follow the format:
> ```json
> { "username": "<github-username>", "password": "<personal-access-token>" }
> ```

---

## Error 17: Wrong Resource Used for 3.3.3 — Classic Notebook Instead of Studio Space

**Location:** AWS Console → SageMaker AI → Notebook instances

**Issue:**
The classic notebook instance (`cdcu-pre-prod-notebook-01`) was provisioned under **SageMaker AI → Notebook instances**, but 3.3.3 specifies **"Amazon SageMaker Unified Studio Provisioning"**. The correct deliverable is a JupyterLab space inside the Studio domain, not a standalone classic notebook instance.

**Cause:** Misinterpretation of 3.3.3. The `ml.t3.medium` spec in the requirements refers to the instance type for a **Studio JupyterLab space**, not a classic notebook instance. The Studio domain (`cdcu-pre-prod-studio`) was already provisioned but had no space attached to it.

**File:** `modules/sagemaker/main.tf`, `modules/sagemaker/variables.tf`, `environments/pre-prod/terraform.tfvars`

**Resolution:**

Step 1 — Replace `aws_sagemaker_notebook_instance` with `aws_sagemaker_space` in `modules/sagemaker/main.tf`:
```hcl
resource "aws_sagemaker_space" "jupyterlab" {
  for_each  = var.enable_unified_studio ? toset(var.studio_user_profile_names) : toset([])
  domain_id  = aws_sagemaker_domain.studio[0].id
  space_name = "${each.value}-jupyterlab"
  ownership_settings {
    owner_user_profile_name = each.value
  }
  space_sharing_settings {
    sharing_type = "Private"
  }
  space_settings {
    app_type = "JupyterLab"
    jupyter_lab_app_settings {
      default_resource_spec {
        instance_type = var.studio_space_instance_type
      }
    }
    space_storage_settings {
      ebs_storage_settings {
        ebs_volume_size_in_gb = var.studio_space_volume_size_gb
      }
    }
  }
}
```

Step 2 — Replace notebook variables with space variables in `modules/sagemaker/variables.tf`:
```hcl
# Remove: notebook_instance_count, notebook_instance_type,
#         notebook_volume_size_gb, notebook_direct_internet_access

# Add:
variable "studio_space_instance_type" {
  default = "ml.t3.medium"
}
variable "studio_space_volume_size_gb" {
  default = 5
}
```

Step 3 — Update `terraform.tfvars`:
```hcl
# Remove:
sagemaker_notebook_instance_count = 1
sagemaker_notebook_instance_type  = "ml.t3.medium"

# Add:
sagemaker_studio_space_instance_type  = "ml.t3.medium"
sagemaker_studio_space_volume_size_gb = 5
```

The space will appear under **SageMaker AI → Unified Studio → Domains → cdcu-pre-prod-studio → Space management**.

> For BPI MS environment: The JupyterLab space is the correct 3.3.3 deliverable. The classic notebook instance approach (Errors 14–16) was a misinterpretation and has been removed from the codebase.

---

## Error 18: `aws_sagemaker_space` — Wrong Arguments in `ownership_settings`

**Command:** `terraform plan`

**Error:**
```
Error: Missing required argument
  on ..\..\modules\sagemaker\main.tf line 55, in resource "aws_sagemaker_space" "jupyterlab":
  55:   ownership_settings {
The argument "owner_user_profile_name" is required, but no definition was found.

Error: Unsupported argument
  on ..\..\modules\sagemaker\main.tf line 56, in resource "aws_sagemaker_space" "jupyterlab":
  56:     ownership_type = "Private"
An argument named "ownership_type" is not expected here.

Error: Unsupported argument
  on ..\..\modules\sagemaker\main.tf line 57, in resource "aws_sagemaker_space" "jupyterlab":
  57:     user_profile_name = each.value
An argument named "user_profile_name" is not expected here.
```

**Cause:** The `ownership_settings` block in `aws_sagemaker_space` only accepts `owner_user_profile_name`. The initial implementation incorrectly used `ownership_type` and `user_profile_name` which are not valid arguments for this block.

**File:** `modules/sagemaker/main.tf`

**Resolution:** Fix the `ownership_settings` block to use the correct argument:
```hcl
# Before
ownership_settings {
  ownership_type    = "Private"
  user_profile_name = each.value
}

# After
ownership_settings {
  owner_user_profile_name = each.value
}
```

---

## Error 19: Glue Job Failed — Missing EC2 VPC Placement Permissions

**Command:** `aws glue start-job-run --job-name cdcu-pre-prod-microsite-raw-extraction`

**Error:**
```
Failed to call ec2:DescribeSubnets: You are not authorized to perform this operation.
User: arn:aws:sts::<account-id>:assumed-role/ST-CDCU-pre-prod-GlueExecutionRole/GlueJobRunnerSession
is not authorized to perform: ec2:DescribeSubnets because no identity-based policy allows the
ec2:DescribeSubnets action
VPC Id not found for subnet subnet-0d3103b0eba8bb171 and availability zone ap-southeast-1a
```

**Cause:** When a Glue job runs inside a VPC (which is required for JDBC connections to RDS), Glue needs EC2 permissions to locate the subnet, security group, and VPC, and to create/delete the network interface for the job runner. The `ST-CDCU-pre-prod-GlueCrawlerAndETL` policy only had Glue service actions — the required EC2 VPC placement actions were missing.

**File:** `modules/iam/main.tf`

**Resolution:** Added a `GlueVPCPlacement` statement to the `glue_etl` policy:

```hcl
{
  Sid    = "GlueVPCPlacement"
  Effect = "Allow"
  Action = [
    "ec2:DescribeSubnets",
    "ec2:DescribeSecurityGroups",
    "ec2:DescribeVpcs",
    "ec2:DescribeVpcEndpoints",
    "ec2:DescribeRouteTables",
    "ec2:CreateNetworkInterface",
    "ec2:DeleteNetworkInterface",
    "ec2:DescribeNetworkInterfaces"
  ]
  Resource = "*"
}
```

Then re-run plan and apply:
```powershell
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

> For BPI MS environment: These EC2 permissions are required for any Glue job that runs inside a VPC. They must be included in the Glue execution role from the start whenever JDBC connections to RDS are used.

---

## Error 20: Glue Job Failed — S3 VPC Endpoint Not Associated with Route Table

**Command:** `aws glue start-job-run --job-name cdcu-pre-prod-microsite-raw-extraction`

**Error:**
```
VPC S3 endpoint validation failed for SubnetId: subnet-0d3103b0eba8bb171.
VPC: vpc-00b620cb44f4a3935.
Reason: Could not find S3 endpoint or NAT gateway for subnetId:
subnet-0d3103b0eba8bb171 in Vpc vpc-00b620cb44f4a3935
```

**Cause:** After fixing the EC2 VPC placement permissions (Error 19), Glue successfully placed itself inside the VPC but could not reach S3 to write job output. The VPC has an S3 Gateway endpoint (`vpce-056b1e0fc60b51bb1`) but it had **no route tables associated** with it:

```powershell
aws ec2 describe-vpc-endpoints `
  --filters "Name=vpc-endpoint-id,Values=vpce-056b1e0fc60b51bb1" `
  --region ap-southeast-1 `
  --query "VpcEndpoints[0].RouteTableIds"
# Returns: []
```

The subnet `subnet-0d3103b0eba8bb171` has no explicit route table association so it uses the VPC main route table (`rtb-02a84c37f5e593af6`). Since the S3 endpoint was not associated with any route table, traffic to S3 had no valid route and Glue validation failed.

**Scope:** Network configuration — outside Terraform scope. VPC and route tables are manually managed by BPI MS.

**Resolution:**

Step 1 — Confirm the subnet uses the VPC main route table:
```powershell
# Explicit association check (returns null if using main route table)
aws ec2 describe-route-tables `
  --filters "Name=association.subnet-id,Values=subnet-0d3103b0eba8bb171" `
  --region ap-southeast-1 `
  --query "RouteTables[0].RouteTableId"
# Returns: null

# Get the main route table
aws ec2 describe-route-tables `
  --filters "Name=vpc-id,Values=vpc-00b620cb44f4a3935" "Name=association.main,Values=true" `
  --region ap-southeast-1 `
  --query "RouteTables[0].RouteTableId"
# Returns: rtb-02a84c37f5e593af6
```

Step 2 — Associate the S3 Gateway endpoint with the main route table:
```powershell
aws ec2 modify-vpc-endpoint `
  --vpc-endpoint-id vpce-056b1e0fc60b51bb1 `
  --add-route-table-ids rtb-02a84c37f5e593af6 `
  --region ap-southeast-1
```

Step 3 — Retry the Glue job:
```powershell
aws glue start-job-run `
  --job-name "cdcu-pre-prod-microsite-raw-extraction" `
  --region ap-southeast-1
```

> For BPI MS environment: Before provisioning Glue jobs, ensure the S3 Gateway endpoint is associated with the route table used by the Glue subnet. If the subnet has no explicit route table association, associate the endpoint with the VPC main route table. This is a one-time network setup step that must be done before any Glue job runs.

---

## Error 21: Glue Crawler Failed — Missing CloudWatch Logs Permission for `/aws-glue/crawlers`

**Command:** `aws glue start-crawler --name cdcu-pre-prod-processed-matching-crawler`

**Error:**
```
Service Principal: glue.amazonaws.com is not authorized to perform: logs:PutLogEvents
on resource: arn:aws:logs:ap-southeast-1:<account-id>:log-group:/aws-glue/crawlers:log-stream:
cdcu-pre-prod-processed-matching-crawler because no identity-based policy allows the
logs:PutLogEvents action
```

**Cause:** The `ST-CDCU-pre-prod-GlueCloudWatchLogs` policy only covered the `/aws/glue/*` log group path. Glue crawlers write logs to a different path `/aws-glue/crawlers` (note: no `/aws` prefix). The policy resource ARN did not include this path so the crawler could not write its logs and failed immediately.

**File:** `modules/iam/main.tf`

**Resolution:** Added `/aws-glue/*` to the CloudWatch Logs resource list in the `glue_cloudwatch` policy:

```hcl
# Before
Resource = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/glue/*"

# After
Resource = [
  "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/glue/*",
  "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws-glue/*"
]
```

Then re-run plan and apply:
```powershell
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

Then re-run the crawler:
```powershell
aws glue start-crawler `
  --name "cdcu-pre-prod-processed-matching-crawler" `
  --region ap-southeast-1
```

> Note: Glue uses two different log group paths:
> - `/aws/glue/*` — for Glue ETL jobs
> - `/aws-glue/*` — for Glue crawlers
>
> Both must be included in the CloudWatch Logs policy for the Glue execution role.

---

## Error 22: Glue Crawler Failed — Missing `glue:BatchGetPartition` on Catalog

**Command:** `aws glue start-crawler --name cdcu-pre-prod-processed-matching-crawler`

**Error:**
```
Service Principal: glue.amazonaws.com is not authorized to perform: glue:BatchGetPartition
on resource: arn:aws:glue:ap-southeast-1:<account-id>:catalog
because no identity-based policy allows the glue:BatchGetPartition action
(Database name: cdcu_pre-prod_catalog, Table name: matching)
```

**Cause:** When a Glue crawler runs against an S3 path that already has a table registered in the catalog, it calls `glue:BatchGetPartition` to check existing partitions before updating. This action was missing from the `GlueCrawlerAndETL` policy — only `glue:GetPartition` and `glue:GetPartitions` were included, not the batch variant.

**File:** `modules/iam/main.tf`

**Resolution:** Added `glue:BatchGetPartition` to the `GlueCrawlerAndETL` policy statement alongside the existing batch partition actions:

```hcl
# Before
"glue:GetPartition", "glue:GetPartitions", "glue:BatchCreatePartition", "glue:BatchDeletePartition"

# After
"glue:GetPartition", "glue:GetPartitions", "glue:BatchCreatePartition",
"glue:BatchDeletePartition", "glue:BatchGetPartition"
```

Then re-run plan and apply:
```powershell
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

Then re-run the crawler:
```powershell
aws glue start-crawler `
  --name "cdcu-pre-prod-processed-matching-crawler" `
  --region ap-southeast-1
```

> For BPI MS environment: Always include all three batch partition actions (`BatchGetPartition`, `BatchCreatePartition`, `BatchDeletePartition`) in the Glue execution role from the start. Crawlers use all three when updating existing catalog tables.

---

## Error 23: Athena Query Failed — Hyphen in Glue Catalog Database Name

**Command:** `aws athena start-query-execution`

**Error:**
```
InvalidRequestException: line 1:23: mismatched input '-'.
AthenaErrorCode: MALFORMED_QUERY

SCHEMA_NOT_FOUND: line 1:15: Schema 'cdcu_pre_prod_catalog' does not exist
```

**Cause:** The Glue catalog database was named `cdcu_pre-prod_catalog` — the hyphen from the `pre-prod` environment name was passed directly into the database name. Athena's SQL parser treats hyphens as minus operators, so `cdcu_pre-prod_catalog` is parsed as `cdcu_pre` minus `prod_catalog`, causing a syntax error. Even wrapping the name in double quotes did not resolve it in all contexts.

**File:** `modules/glue/main.tf`

**Resolution:** Replace hyphens with underscores in the catalog database name using Terraform's `replace()` function:

```hcl
# Before
name = "cdcu_${var.environment}_catalog"
# Produces: cdcu_pre-prod_catalog

# After
name = "cdcu_${replace(var.environment, "-", "_")}_catalog"
# Produces: cdcu_pre_prod_catalog
```

This renames the database from `cdcu_pre-prod_catalog` to `cdcu_pre_prod_catalog`. After applying, re-run the crawler to register tables under the new database name, then query:

```sql
SELECT * FROM "cdcu_pre_prod_catalog"."matching" LIMIT 10
```

> For BPI MS environment: Always use underscores in Glue catalog database names. Hyphens are not valid in Athena SQL identifiers even when the environment name contains them.

---

## Notes for BPI MS Environment

- Errors 1 and 2 are one-time machine setup issues and will not recur on a properly configured CI/CD runner.
- Error 3 must be resolved by running the bootstrap steps before any `terraform init` in the BPI MS account.
- Errors 5 and 6 are code fixes already applied to the repository — they will not recur.
- Error 7 requires BPI MS to provide the deployment role ARN before running Terraform in their account.
- Errors 8, 9, and 13 all stem from the same root cause: the AWS hard limit of 10 policies per IAM group. Always count CE group attachments before any apply.
- Errors 14, 15, and 16 are superseded by Error 17 — the classic notebook instance approach was incorrect. The correct 3.3.3 deliverable is a Studio JupyterLab space via `aws_sagemaker_space`.
- Error 18 is a code fix already applied — `ownership_settings` in `aws_sagemaker_space` only accepts `owner_user_profile_name`.
- Errors 19, 21, and 22 — Glue execution role requires EC2 VPC placement permissions, both `/aws/glue/*` and `/aws-glue/*` CloudWatch log group paths, and all batch partition actions (`BatchGetPartition`, `BatchCreatePartition`, `BatchDeletePartition`). Include all from the start.
- Error 23 — Glue catalog database names must use underscores only. Hyphens from environment names must be replaced using `replace(var.environment, "-", "_")` in `modules/glue/main.tf`.
- Error 20 — S3 Gateway endpoint must be associated with the route table used by the Glue subnet before any Glue job runs. This is a BPI MS network prerequisite outside Terraform scope.
