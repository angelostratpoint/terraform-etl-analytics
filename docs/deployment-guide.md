# CDCU Terraform Deployment Guide

This repository provisions the CDCU Terraform-managed service layer for BPI-MS.
It is organized into separate environment roots for SIT, UAT, and production.

Terraform provisions CDCU-managed resources such as S3, Glue, Athena,
SageMaker, QuickSight configuration, and the additional `ST-CDCU` IAM resources
defined for the project. Terraform does not own the BPI-MS enterprise VPC or
route table baseline. The provided `vpc-assessment.yaml` CloudFormation template
can be used by BPI-MS to create the CDCU private subnet, runtime security group,
and required interface endpoints in the approved OSP VPC. Terraform consumes the
approved VPC, subnet, and security group outputs as inputs.

## Repository Environments

| Environment | Terraform root |
|---|---|
| SIT | `environments/sit` |
| UAT | `environments/uat` |
| Prod | `environments/prod` |

Run Terraform from the target environment folder only. The repository root is
not a Terraform root module.

## Naming Convention

The Terraform implementation uses these CDCU naming patterns:

| Resource area | Pattern | Example |
|---|---|---|
| AWS service resources | `cdcu-{env}-*` with approved suffixes when required | `cdcu-sit-data-lake-apse1` |
| Secrets Manager paths | `cdcu/{env}/*` | `cdcu/sit/merged-mysql-connection` |
| Glue catalog database | `cdcu_{env}_catalog` | `cdcu_sit_catalog` |
| IAM roles, groups, policies | `ST-CDCU-{env}-*` | `ST-CDCU-sit-GlueExecutionRole` |
| Terraform backend bucket | BPI-MS approved unique name | `cdcu-terraform-state-sit-apse1` |
| Terraform lock table | `cdcu-terraform-locks-{env}` | `cdcu-terraform-locks-sit` |

## Required BPI-MS Inputs

Before deployment, BPI-MS must provide or approve the following values for the
target environment:

| Input | Purpose |
|---|---|
| `terraform_role_arn` | IAM role Terraform assumes during deployment |
| `vpc_id` | Approved BPI-MS VPC for CDCU runtime placement |
| `subnet_id` | `CDCUPrivateSubnetId` output from `vpc-assessment.yaml` |
| `subnet_ids` | Approved private subnet list; for SIT use the `CDCUPrivateSubnetId` output |
| `availability_zone` | Availability zone matching the primary subnet |
| `existing_security_group_id` | `CDCURuntimeSecurityGroupId` output from `vpc-assessment.yaml` |
| `terraform_lock_table_name` | DynamoDB table used by Terraform state locking |
| `data_lake_bucket_name` | Approved data lake bucket name, such as `cdcu-sit-data-lake-apse1` |
| `athena_results_bucket_name` | Approved Athena results bucket name, such as `cdcu-sit-athena-results-apse1` |
| `existing_kms_key_arn` | BPI-MS KMS key ARN when KMS is enabled |
| `merged_jdbc_url` | Merged MySQL RDS JDBC URL used by the CDCU Glue source connection |
| `merged_mysql_secret_name` | Merged Secrets Manager secret name, such as `cdcu/sit/merged-mysql-connection` |
| `git_repository_url` | Git repository URL for SageMaker code repository |
| `quicksight_admin_principal_arn` | Approved QuickSight principal when QuickSight is enabled |

The approved subnet and security group must support private Glue/SageMaker
runtime connectivity to the source MySQL RDS environment, S3, and required AWS
managed-service endpoints. Keep the network resource ownership with BPI-MS;
Terraform only consumes the approved IDs.

## Network Prerequisite

Before Terraform runs, BPI-MS should deploy or verify the network prerequisites.
The provided `vpc-assessment.yaml` template is intended for BPI-MS-controlled
network prerequisite provisioning inside the approved OSP VPC baseline. BPI-MS
should supply the approved VPC, subnet CIDR, route table, availability zone, and
RDS security group parameters at stack deployment time.

The template creates:

| Resource | Purpose |
|---|---|
| `cdcu-sit-private-subnet-1a` | Private runtime subnet for CDCU managed services |
| `cdcu-sit-runtime-sg` | Runtime security group for Glue and SageMaker |
| Self-referencing SG ingress | Required for managed-service runtime ENI communication |
| Interface endpoints | Secrets Manager, Glue, CloudWatch Logs, KMS, SageMaker API, SageMaker Runtime, and STS |

The template intentionally does not create an S3 Gateway endpoint because the
BPI-MS private route table already has the S3 prefix-list route. The runtime
security group allows outbound HTTPS to the existing S3 prefix list
`pl-6fa54006`.

After the CloudFormation stack completes, copy these outputs into
`terraform.tfvars`:

```hcl
vpc_id                     = "<CDCUVpcId output>"
subnet_id                  = "<CDCUPrivateSubnetId output>"
subnet_ids                 = ["<CDCUPrivateSubnetId output>"]
availability_zone          = "<CDCUAvailabilityZone output>"
existing_security_group_id = "<CDCURuntimeSecurityGroupId output>"
```

## Backend Prerequisite

Before running `terraform init`, create the remote state backend for the target
environment. See `docs/bootstrap-guide.md`.

Expected backend resources:

| Environment | State bucket | Lock table |
|---|---|---|
| SIT | `cdcu-terraform-state-sit-apse1` | `cdcu-terraform-locks-sit` |
| UAT | `cdcu-terraform-state-uat` | `cdcu-terraform-locks-uat` |
| Prod | `cdcu-terraform-state-prod` | `cdcu-terraform-locks-prod` |

## AWS Credentials

Terraform must be run by an approved BPI-MS IAM user, IAM role session, or AWS
SSO role that has permission to:

- access the Terraform S3 backend bucket,
- access the Terraform DynamoDB lock table,
- assume `terraform_role_arn`, and
- provision the approved CDCU resources.

Configure the AWS CLI before running Terraform.

For access key based credentials:

```powershell
aws configure --profile bpi-ms-sit
```

Provide the BPI-MS approved values:

```text
AWS Access Key ID
AWS Secret Access Key
Default region name: ap-southeast-1
Default output format: json
```

For AWS SSO based access:

```powershell
aws configure sso --profile bpi-ms-sit
aws sso login --profile bpi-ms-sit
```

Set the active profile for the terminal session:

```powershell
$env:AWS_PROFILE = "bpi-ms-sit"
$env:AWS_REGION  = "ap-southeast-1"
```

Confirm the caller identity before running Terraform:

```powershell
aws sts get-caller-identity
```

The returned account must be the approved BPI-MS AWS account for the target
environment. Do not proceed if the account is not correct.

## Secrets

Glue uses one merged BPI-MS MySQL source secret:

```text
cdcu/{environment}/merged-mysql-connection
```

The active Glue source connection is `cdcu-{environment}-merged-mysql`.
Terraform no longer provisions separate Microsite and Legacy Glue source
connections because BPI-MS consolidated the source into one RDS database.

Terraform references the approved secret names. Secret values, passwords, and
rotation material must not be committed to Git and must not be stored in
Terraform variables or Terraform state. BPI-MS or an approved operator should
populate and rotate the secret values through the approved secure process.

The merged JDBC URL must point to the real RDS endpoint:

```hcl
merged_jdbc_url              = "jdbc:mysql://<rds-endpoint>:3306/<database>?useSSL=false&allowPublicKeyRetrieval=true"
merged_mysql_secret_name     = "cdcu/<environment>/merged-mysql-connection"
mysql_jdbc_driver_class_name = "com.mysql.cj.jdbc.Driver"
mysql_jdbc_driver_jar_uri    = ""
```

The variables reject `localhost` values to avoid deploying test placeholders.
`mysql_jdbc_driver_class_name` is set to the current MySQL Connector/J class
name to avoid the deprecated `com.mysql.jdbc.Driver` warning in Glue logs. Use
`mysql_jdbc_driver_jar_uri` only if BPI-MS provides an approved custom JDBC
driver JAR in S3.

## Lake Formation

If Lake Formation is enabled in the BPI-MS account, IAM permissions alone are
not sufficient. BPI-MS must apply CDCU-scoped Lake Formation permissions for the
runtime and query principals.

Minimum grants to review:

| Principal | Minimum grants |
|---|---|
| `ST-CDCU-{env}-GlueExecutionRole` | Database/table permissions for Glue crawler and job updates |
| Approved Athena query principal | Database `DESCRIBE`, table `DESCRIBE`, and `SELECT` |
| Approved QuickSight principal | Database `DESCRIBE`, table `DESCRIBE`, and `SELECT` |

BPI-MS remains owner of Lake Formation account settings, administrators, and
enterprise data governance rules.

## Deployment Steps

From the repository root, choose the target environment. The examples below use
SIT. Replace `sit` with `uat` or `prod` for the other environments.

```powershell
cd environments/sit
Copy-Item terraform.tfvars.example terraform.tfvars
```

Open `terraform.tfvars` and replace the placeholder values with BPI-MS approved
values.

Required values to review:

| Variable | What to set |
|---|---|
| `environment` | `sit`, `uat`, or `prod` |
| `terraform_role_arn` | BPI-MS approved deployment role ARN |
| `vpc_id` | Approved BPI-MS VPC ID |
| `subnet_id` | `CDCUPrivateSubnetId` from `vpc-assessment.yaml` |
| `subnet_ids` | `CDCUPrivateSubnetId` from `vpc-assessment.yaml`, unless BPI-MS approves more subnets |
| `availability_zone` | Availability Zone of the primary subnet |
| `data_lake_bucket_name` | Approved data lake bucket name |
| `athena_results_bucket_name` | Approved Athena results bucket name |
| `github_org` | Approved GitHub organization or repository owner |
| `github_repo` | Approved repository name |
| `sso_principal_arns` | BPI-MS approved SSO role/user principal ARNs, if applicable |
| `enable_kms` | `true` only when BPI-MS provides an approved KMS key |
| `existing_kms_key_arn` | Required when `enable_kms = true` |
| `sns_topic_arn` | Approved SNS topic ARN, or empty string if unused |
| `glue_worker_count` | Approved Glue worker count |
| `glue_worker_type` | Approved Glue worker type |
| `merged_jdbc_url` | Real merged MySQL RDS JDBC URL |
| `merged_mysql_secret_name` | Real merged Secrets Manager secret name |
| `git_repository_url` | Approved repository URL for SageMaker code repository |
| `enable_sagemaker_unified_studio` | Whether to provision SageMaker Studio resources |
| `sagemaker_studio_user_profile_names` | Approved SageMaker Studio user profile names |
| `sagemaker_studio_space_instance_type` | Approved JupyterLab instance type |
| `sagemaker_studio_space_volume_size_gb` | Approved JupyterLab EBS volume size |
| `sagemaker_studio_app_network_access_type` | Usually `VpcOnly` |
| `enable_sagemaker_notebook_instance` | Whether to provision the classic SageMaker Notebook Instance |
| `sagemaker_notebook_instance_name` | Approved classic SageMaker Notebook Instance name |
| `sagemaker_notebook_instance_type` | Approved classic notebook instance type, default `ml.t3.medium` |
| `sagemaker_notebook_volume_size_gb` | Approved classic notebook EBS volume size, default `5` |
| `terraform_lock_table_name` | Environment lock table, such as `cdcu-terraform-locks-sit` |
| `existing_quicksight_access_role_arn` | Approved QuickSight role ARN, or empty string |
| `existing_security_group_id` | Approved CDCU runtime security group ID |

The most important BPI-MS infrastructure inputs are:

```hcl
terraform_role_arn = "arn:aws:iam::<account-id>:role/<approved-terraform-role>"

vpc_id    = "<CDCUVpcId output or approved BPI-MS VPC ID>"
subnet_id = "<CDCUPrivateSubnetId output>"
subnet_ids = [
  "<CDCUPrivateSubnetId output>",
]
availability_zone          = "<CDCUAvailabilityZone output>"
existing_security_group_id = "<CDCURuntimeSecurityGroupId output>"

data_lake_bucket_name      = "cdcu-sit-data-lake-apse1"
athena_results_bucket_name = "cdcu-sit-athena-results-apse1"

enable_sagemaker_notebook_instance = true
sagemaker_notebook_instance_type   = "ml.t3.medium"
sagemaker_notebook_volume_size_gb  = 5

terraform_lock_table_name = "cdcu-terraform-locks-sit"
```

After `terraform.tfvars` is updated, run:

```powershell
terraform init
terraform fmt -check -recursive ../../
terraform validate
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

For UAT and production, run the same flow from `environments/uat` and
`environments/prod`.

## Deployment Flow Summary

Use this sequence per environment:

```powershell
# 1. Authenticate to the target BPI-MS AWS account
$env:AWS_PROFILE = "bpi-ms-sit"
$env:AWS_REGION  = "ap-southeast-1"
aws sts get-caller-identity

# 2. Deploy or verify vpc-assessment.yaml in CloudFormation
#    Then copy CDCUPrivateSubnetId and CDCURuntimeSecurityGroupId into terraform.tfvars.

# 3. Go to the target Terraform root
cd environments/sit

# 4. Create and update terraform.tfvars
Copy-Item terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars

# 5. Initialize the backend
terraform init

# 6. Validate and review the plan
terraform fmt -check -recursive ../../
terraform validate
terraform plan -var-file="terraform.tfvars" -out=tfplan

# 7. Apply only after the plan is reviewed and approved
terraform apply tfplan
```

## Post-Deployment Checks

Run these from the environment folder after `terraform apply` completes:

```powershell
terraform output

aws s3 ls s3://cdcu-sit-data-lake-apse1 --region ap-southeast-1

aws glue get-database `
  --name cdcu_sit_catalog `
  --region ap-southeast-1

aws athena get-work-group `
  --work-group cdcu-sit-workgroup `
  --region ap-southeast-1
```

Replace `sit` with `uat` or `prod` when validating another environment.

## Runtime Validation

Infrastructure deployment and runtime application validation are separate
activities. Terraform can deploy the service layer before the final ETL and
matching scripts are complete.

The main runtime validations are:

1. Real MySQL RDS extraction through Glue.
2. Glue ETL script validation.
3. SageMaker matching script validation.
4. Athena and QuickSight validation.

DE-owned scripts are uploaded from the repository when matching files exist:

| Local path | S3 prefix |
|---|---|
| `artifacts/glue/extraction/*.py` | `{env}/glue-scripts/extraction/` |
| `artifacts/glue/standardization/*.py` | `{env}/glue-scripts/standardization/` |
| `artifacts/sagemaker/matching/*.py` | `{env}/sagemaker-scripts/matching/` |
| `artifacts/sagemaker/processing/*.py` | `{env}/sagemaker-scripts/processing/` |
| `artifacts/sql/athena/*.sql` | `{env}/sql/` |

Empty script folders produce zero uploaded objects. That is expected until the
approved runtime scripts are added.

## Fresh Machine Setup

The following local files and credentials are not committed:

| Item | Action |
|---|---|
| `terraform.tfvars` | Copy from `terraform.tfvars.example` and fill approved values |
| `.terraform/` | Run `terraform init` |
| AWS credentials | Authenticate with the approved BPI-MS profile or role |
| Terraform CLI | Install Terraform 1.6.0 or newer |

Example:

```powershell
git clone <approved-bpi-ms-repository-url>
cd terraform-etl-analytics
git checkout bpi-ms-terraform

cd environments/sit
Copy-Item terraform.tfvars.example terraform.tfvars

terraform init
terraform validate
terraform plan -var-file="terraform.tfvars" -out=tfplan
```

## Rollback

Prefer reverting the Terraform change and applying a new plan. Avoid full
environment destroy in production. For emergency SIT or UAT cleanup only, use a
targeted destroy after review:

```powershell
terraform destroy -target=module.glue -var-file="terraform.tfvars"
```
