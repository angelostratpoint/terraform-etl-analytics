# CDCU Terraform Infrastructure Repository

**BPI-MS Customer Data Clean-Up (CDCU) - AWS application infrastructure**

This repository provisions the Terraform-owned service layer for the CDCU data pipeline:

```text
MySQL RDS sources -> AWS Glue -> S3 -> SageMaker -> Athena -> QuickSight
```

BPI MS / Stratpoint prepares the AWS account baseline before Terraform runs. This includes the deployment role, security baseline, VPC route table, KMS baseline, source database access, and approved network paths. The provided `vpc-assessment.yaml` CloudFormation template can create the CDCU private subnet, runtime security group, and required interface endpoints inside the approved BPI-MS OSP VPC. Terraform then consumes the CloudFormation outputs and provisions the approved CDCU application services plus the additional `ST-CDCU` IAM roles and groups requested for this project.

## Current BPI-MS Alignment Status

The May 2026 BPI-MS review confirmed the target operating model below:

- Target environments are formally separated as `sit/`, `uat/`, and `prod/`.
- BPI-MS will review/approve IAM policy resources by group: Cloud Engineering, Data Engineering, and QA.
- BPI-MS owns VPC, route table, security group, endpoint, and RDS/MySQL governance. The optional `vpc-assessment.yaml` template is provided for BPI-MS-controlled network prerequisite provisioning.
- Terraform should provision CDCU Secrets Manager secret containers using the approved names, but must not store or commit secret values.
- Lake Formation is required when enabled by BPI-MS. The access template contains CDCU-scoped grants when the approved runtime principals are supplied; account-level Lake Formation governance remains with BPI-MS.
- CodePipeline access for Cloud Engineering is later scope and is not required for the current Phase 1 package.

## Terraform Scope

Terraform owns:

| Activity | Terraform coverage |
|---|---|
| Additional IAM/RBAC | `ST-CDCU` service roles, human groups, additive policies, and shared deny policies |
| 3.3.1 AWS S3 Bucket Creation | Data lake and Athena results buckets |
| 3.3.2 AWS Glue Provisioning and Folder Structuring | Glue catalog database, connections, jobs, S3 script paths |
| 3.3.3 Amazon SageMaker Unified Studio Provisioning | Studio domain, user profiles, JupyterLab spaces, classic notebook instance, code repository |
| 3.3.4 Amazon Athena Provisioning | Workgroup and query configuration |
| 3.3.5 AWS Crawler Provisioning | Glue crawlers for raw, standardized, processed, and error prefixes |
| 3.3.6 AWS QuickSight Provisioning | QuickSight groups, Athena data source, and dataset when enabled |

Terraform does not own:

- AWS account/IAM/security baseline
- Existing BPI MS IAM roles, baseline RBAC policies, or GitHub OIDC deployment role creation
- VPCs, subnets, route tables, or security group creation
- KMS key creation or key policy ownership
- RDS/source database provisioning
- Secret values
- Data Engineering script logic

## Repository Structure

```text
terraform-etl-analytics/
|-- .github/workflows/          # Terraform plan/apply pipelines
|-- artifacts/                  # DE-owned scripts uploaded to S3 by Terraform
|   |-- glue/
|   |   |-- extraction/         # Glue extraction scripts (*.py)
|   |   `-- standardization/    # Glue standardization scripts (*.py)
|   |-- sagemaker/
|   |   |-- matching/           # SageMaker matching scripts (*.py)
|   |   `-- processing/         # SageMaker processing scripts (*.py)
|   `-- sql/
|       `-- athena/             # Athena SQL files (*.sql)
|-- bootstrap/                  # Optional remote state bootstrap helper
|-- vpc-assessment.yaml         # BPI-MS CloudFormation network prerequisites
|-- environments/
|   |-- sit/                    # System Integration Testing root module
|   |-- uat/                    # User Acceptance Testing root module
|   `-- prod/                   # Production root module
|-- modules/
|   |-- artifacts/              # Uploads artifacts/* files to S3
|   |-- athena/
|   |-- glue/
|   |-- iam/                    # Additional ST-CDCU IAM roles, groups, and policies
|   |-- quicksight/
|   |-- s3/
|   `-- sagemaker/
`-- docs/
    |-- bootstrap-guide.md      # Remote state backend setup
    |-- deployment-guide.md     # Environment deployment steps
    |-- prod-deployment-mop-runbook.md # Production MOP and operational runbook
    |-- terraform-vpc-production-readiness.md
    |-- iam-service-role-reference.md
    `-- runtime-connectivity-validation.md
```

Enterprise KMS, security groups, Secrets Manager secret values, Lake Formation account governance, and CloudWatch account governance remain outside the Terraform workload scope. Active environment roots instantiate only the CDCU service-layer modules listed above.

## Deployment Guides

Use the retained BPI-MS handoff guides for setup and deployment:

| Guide | Purpose |
|---|---|
| `docs/bootstrap-guide.md` | Creates or verifies the Terraform S3 state bucket and DynamoDB lock table |
| `docs/deployment-guide.md` | Describes required BPI-MS inputs and the SIT/UAT/Prod Terraform run flow |
| `docs/terraform-vpc-production-readiness.md` | Detailed Terraform architecture, `vpc-assessment.yaml`, ownership boundaries, and production-readiness checklist |
| `docs/iam-service-role-reference.md` | Current human group, service role, PassRole, Lake Formation, and IAM validation reference |
| `docs/runtime-connectivity-validation.md` | Runtime connectivity and service smoke tests |
| `docs/prod-deployment-mop-runbook.md` | Production Method of Procedure, operational runbook, validation commands, rollback guidance, and sign-off checklist |

For production technical review, start with `docs/terraform-vpc-production-readiness.md`. For the actual production change window after UAT sign-off, use `docs/prod-deployment-mop-runbook.md` as the MOP. IAM user/group documentation is summarized separately in `docs/iam-service-role-reference.md`.

## Required External Inputs

Each environment needs these values from BPI MS / manual setup before `terraform plan`:

```hcl
terraform_role_arn
vpc_id
subnet_id
subnet_ids
availability_zone
existing_security_group_id
existing_kms_key_arn # required when enable_kms = true
existing_quicksight_access_role_arn # optional, for BPI-managed QuickSight role references
```

For SIT, the network values should come from the BPI-MS-approved `vpc-assessment.yaml` CloudFormation stack outputs:

```hcl
vpc_id                     = "<CDCUVpcId output or approved BPI-MS VPC ID>"
subnet_id                  = "<CDCUPrivateSubnetId output>"
subnet_ids                 = ["<CDCUPrivateSubnetId output>"]
availability_zone          = "<CDCUAvailabilityZone output>"
existing_security_group_id = "<CDCURuntimeSecurityGroupId output>"
```

BPI-MS SIT bucket names currently use the regional suffix:

```hcl
data_lake_bucket_name      = "cdcu-sit-data-lake-apse1"
athena_results_bucket_name = "cdcu-sit-athena-results-apse1"
```

`existing_glue_execution_role_arn` and `existing_sagemaker_execution_role_arn` are deprecated compatibility inputs. Active environment roots use the `ST-CDCU` roles created by `modules/iam`.

Glue uses one merged BPI-MS MySQL source secret:

```text
cdcu/{environment}/merged-mysql-connection
```

The active Glue source connection is `cdcu-{environment}-merged-mysql`. Terraform no longer provisions separate Microsite and Legacy Glue source connections because BPI-MS consolidated the source into one RDS database. By default the Glue connection uses the Glue-provided MySQL driver so the Glue console connection test remains supported. Set `mysql_jdbc_driver_class_name` or `mysql_jdbc_driver_jar_uri` only when BPI-MS provides an approved custom driver configuration.

Terraform references the secret names only. Secret values, password rotation material, and database credentials must remain outside Terraform state.

## DE Artifact Uploads

Data Engineering scripts are committed under `artifacts/` and uploaded to the CDCU S3 data lake on `terraform apply`.

| Local directory | File type | S3 key prefix |
|---|---|---|
| `artifacts/glue/extraction/` | `*.py` | `{env}/glue-scripts/extraction/` |
| `artifacts/glue/standardization/` | `*.py` | `{env}/glue-scripts/standardization/` |
| `artifacts/sagemaker/matching/` | `*.py` | `{env}/sagemaker-scripts/matching/` |
| `artifacts/sagemaker/processing/` | `*.py` | `{env}/sagemaker-scripts/processing/` |
| `artifacts/sagemaker/notebooks/` | `*.ipynb` | `{env}/sagemaker-notebooks/` |
| `artifacts/sql/athena/` | `*.sql` | `{env}/sql/` |

Directories containing only README files produce zero S3 objects. That is expected until DEs add scripts.

## Workflow And SageMaker Pipeline Automation

The Glue module can optionally create a CDCU workflow for the extraction and
standardization section of the pipeline:

```text
Glue raw extraction job
-> raw crawler and standardization job
-> standardized crawler
```

The SageMaker module can optionally create a CDCU matching pipeline and
EventBridge rules that start it directly:

```text
EventBridge schedule
-> sagemaker:StartPipelineExecution
-> SageMaker Processing step
-> processed/matching S3 outputs
```

For dependency-driven execution, EventBridge can also listen for the upstream
standardization Glue job `SUCCEEDED` event and start the same SageMaker
Pipeline directly:

```text
Glue standardization job SUCCEEDED
-> EventBridge Glue Job State Change rule
-> sagemaker:StartPipelineExecution
```

This supports the AWS documented pattern where EventBridge invokes
`sagemaker:StartPipelineExecution`; Lambda and Step Functions are not required
for the simple scheduled/event-based automation case.

These features are disabled by default:

```hcl
enable_glue_workflow_orchestration          = false
enable_glue_workflow_schedule               = false
enable_sagemaker_matching_pipeline          = false
enable_sagemaker_matching_pipeline_schedule = false
enable_sagemaker_matching_pipeline_glue_success_event = false
```

When `enable_glue_workflow_schedule = true`, Terraform creates a scheduled
Glue trigger for the workflow. The default expression is:

```hcl
glue_workflow_schedule_expression = "cron(0 18 * * ? *)"
```

AWS evaluates Glue cron expressions in UTC, so this runs daily at 2:00 AM
Asia/Manila. This is time-based execution; it does not automatically detect
new RDS rows. Each scheduled run extracts/processes whatever source data is
available at that time.

Enable it only after BPI-MS confirms the UAT standardized data path and the
SageMaker processing image/script to run. The default processing script is
`matching_prod.py`, generated from `Matching_prod.ipynb`. The processing image
must support SageMaker Processing, Python 3.12, and `pip`. Runtime Python
dependencies are installed by `run_matching_prod.py` from the S3 wheelhouse
before `matching_prod.py` runs.

The default input/output convention is:

```text
input  = s3://cdcu-{environment}-data-lake/standardized/merged/
output = s3://cdcu-{environment}-data-lake/processed/matching/
wheelhouse = s3://cdcu-{environment}-data-lake/artifacts/python-wheelhouse/
```

The SageMaker Processing container can be managed through Terraform using the
`modules/sagemaker-processing-image` module. In UAT, Terraform can create the
ECR repository `cdcu-uat-sagemaker-processing` and expose the image URI:

```text
765875313224.dkr.ecr.ap-southeast-1.amazonaws.com/cdcu-uat-sagemaker-processing:py312
```

Docker build/push is optional and controlled by:

```hcl
enable_sagemaker_processing_image_build = true
```

Enable that flag only from a deployment host with Docker running and approved
ECR permissions. The SageMaker Pipeline remains disabled until the image exists
and `enable_sagemaker_matching_pipeline` is intentionally enabled.

### SageMaker JupyterLab Notebook Autosync

The artifacts module uploads notebooks from `artifacts/sagemaker/notebooks/`
to this S3 prefix during `terraform apply`:

```text
s3://cdcu-{environment}-data-lake/{environment}/sagemaker-notebooks/
```

When `enable_studio_notebook_autosync = true`, the SageMaker module attaches a
JupyterLab lifecycle configuration that syncs those notebooks into:

```text
$HOME/cdcu-managed/notebooks/
```

The sync runs when the JupyterLab app starts. If the app is already open during
deployment, stop/restart the JupyterLab app or space once after apply.

## Local Execution

```bash
# Optional BPI-MS network prerequisite, run through CloudFormation first:
# vpc-assessment.yaml

cd environments/sit
cp terraform.tfvars.example terraform.tfvars
# Fill terraform.tfvars with BPI MS provided values
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

UAT and production use the same flow from `environments/uat` and `environments/prod`. Production requires the prod GitHub environment approval gate for CI/CD applies if CI/CD is enabled later.

## Production Review Notes

The lower-environment values embedded as defaults or examples must not be reused automatically for production. BPI-MS must provide or approve the production VPC, subnet CIDRs, route table, RDS security group, S3 prefix list, KMS key, backend, bucket names, and deployment role.

Terraform uses one Glue catalog database per environment: `cdcu_{environment}_catalog`. The SIT `cdcu_standardized_db` database is a legacy Employee test resource and is not created by the Glue Terraform module. Current standardized output is cataloged in `cdcu_sit_catalog` from the `standardized/merged/` S3 prefix. The legacy database must not be promoted to UAT or production.
