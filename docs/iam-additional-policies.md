# CDCU Additional IAM Policies — Terraform Implementation Guide

This document describes the additional IAM policies requested by Stratpoint for the CDCU
project. These policies are **additive** — BPI MS already has an existing IAM baseline on
their AWS account. The policies below cover the permissions needed for the Terraform-owned
service layer to operate correctly.

BPI MS will review, approve, and execute the Terraform scripts. Stratpoint provides the
`.tf` files and this guide only.

---

## Context

| Item | Detail |
|---|---|
| Resource naming prefix | `ST-CDCU` |
| Target region | `ap-southeast-1` |
| Environments | `pre-prod`, `prod` |
| Terraform module path | `modules/iam/` |
| Executed by | BPI MS Cloud Engineer |
| Prepared by | Stratpoint Cloud Engineering |

---

## What Already Exists on BPI MS AWS Account

BPI MS has already provisioned the following outside Terraform. Terraform consumes these
as input variables only — it does not create or modify them.

| Resource | Variable in terraform.tfvars |
|---|---|
| VPC | `vpc_id` |
| Subnets | `subnet_id`, `subnet_ids` |
| Security Groups | `existing_security_group_id` |
| KMS Key (prod) | `existing_kms_key_arn` |
| Secrets Manager secrets | `cdcu/{env}/microsite-mysql-connection`, `cdcu/{env}/legacy-mysql-connection` |
| Terraform deployment role | `terraform_role_arn` |

---

## What the New IAM Module Provisions

The `modules/iam/` Terraform module creates the following additional roles and groups
using the `ST-CDCU` naming prefix.

---

## IAM Roles (AWS Service Roles)

### ST-CDCU-GlueExecutionRole

Assumed by `glue.amazonaws.com`. Used by all Glue ETL jobs and crawlers.

| Policy Sid | Service | Actions | Resource Scope |
|---|---|---|---|
| `S3DataLakeAccess` | S3 | GetObject, PutObject, DeleteObject, ListBucket, GetBucketVersioning, PutBucketVersioning | `cdcu-{env}-data-lake` bucket |
| `GlueCrawlerAndETL` | Glue | Full crawler, job, catalog, connection actions (see note below) | `*` |
| `SecretsManagerRead` | Secrets Manager | GetSecretValue, DescribeSecret | `cdcu/{env}/*` secrets |
| `CloudWatchLogsGlueWriteRead` | CloudWatch Logs | CreateLogGroup, CreateLogStream, PutLogEvents, GetLogEvents | `/aws/glue/*`, `/aws-glue/*`, and log-stream ARNs |
| `CloudWatchLogsGlueDescribe` | CloudWatch Logs | DescribeLogGroups, DescribeLogStreams | `*` |

> Note on Glue actions: `glue:GetCatalog`, `glue:CreateCatalog`, `glue:DeleteCatalog`,
> and `glue:UpdateCatalog` are **not valid IAM actions** and are excluded from the
> Terraform implementation even if listed in earlier policy drafts.

---

### ST-CDCU-SageMakerExecutionRole

Assumed by `sagemaker.amazonaws.com`. Used by SageMaker Studio, JupyterLab spaces, processing
jobs, training jobs, and pipelines.

| Policy Sid | Service | Actions | Resource Scope |
|---|---|---|---|
| `SageMakerAccess` | SageMaker | Processing, training, model, endpoint, pipeline, Studio domain/user profile, JupyterLab space/app, presigned domain URL, and tag actions | `*` |
| `S3DataLakeAccess` | S3 | GetObject, PutObject, ListBucket | `cdcu-{env}-data-lake` bucket |
| `CloudWatchLogsSageMakerWriteRead` | CloudWatch Logs | CreateLogGroup, CreateLogStream, PutLogEvents, GetLogEvents | `/aws/sagemaker/*` and log-stream ARNs |
| `CloudWatchLogsSageMakerDescribe` | CloudWatch Logs | DescribeLogGroups, DescribeLogStreams | `*` |

`iam:PassRole` is intentionally excluded from the latest approved ST-CDCU policy list.
If SageMaker job submission later requires a scoped PassRole exception, BPI MS must
approve that exception separately because the current account baseline explicitly denies
PassRole.

---

### ST-CDCU-AthenaQueryRole

Assumed by `quicksight.amazonaws.com`. Used by QuickSight to query Athena and browse
the Glue Data Catalog.

| Policy Sid | Service | Actions | Resource Scope |
|---|---|---|---|
| `AthenaAccess` | Athena | StartQueryExecution, GetQueryExecution, GetQueryResults, StopQueryExecution, ListQueryExecutions, GetWorkGroup, ListWorkGroups | `cdcu-{env}-workgroup` ARN |
| `AthenaResultsAccess` | S3 | GetObject, PutObject, ListBucket | `cdcu-{env}-athena-results` bucket |
| `AthenaGlueCatalogAccess` | Glue | GetDatabase, GetDatabases, GetTable, GetTables, GetPartition, GetPartitions | `*` |

---

## IAM Groups (Human User Groups)

### ST-CDCU-CloudEngineering

Full deployment access for Cloud Engineers. Covers all services plus Terraform state
management.

| Policy Sid | Service | Actions | Resource Scope |
|---|---|---|---|
| All policies from ST-CDCU-GlueExecutionRole | — | — | — |
| All policies from ST-CDCU-SageMakerExecutionRole | — | — | — |
| All policies from ST-CDCU-AthenaQueryRole | — | — | — |
| `DynamoDBStateLockAccess` | DynamoDB | DescribeTable, GetItem, PutItem, DeleteItem, UpdateItem | Terraform lock table ARN |
| `EventBridgeAccess` | EventBridge | PutRule, PutTargets, DescribeRule, EnableRule, DisableRule, DeleteRule, RemoveTargets, ListRules, ListTargetsByRule | `arn:aws:events:ap-southeast-1:{account}:rule/cdcu-*` |
| `DenyNonCDCUEventBridgeRuleMutation` | EventBridge | Explicit deny for mutating non-CDCU rules | NotResource `arn:aws:events:ap-southeast-1:{account}:rule/cdcu-*` |
| `AmazonQConsoleAssistantOnly` | Amazon Q | SendMessage, StartConversation, GetConversation, ListConversations, DeleteConversation | `*` |
| `AllowSTSContextForQ` | STS | SetContext | `arn:aws:sts::*:self` |
| `ExplicitlyDenyQAdministrativeFunctions` | Amazon Q | CreateAssignment, DeleteAssignment, CreatePlugin, UpdatePlugin, DeletePlugin, GetPlugin, UsePlugin, ListPlugins, ListPluginProviders, TagResource, UntagResource, ListTagsForResource | `*` |
| `ExplicitlyDenyCodeGenerationFeatures` | Amazon Q | GenerateCodeFromCommands | `*` |

> Note: `q:PassRequest` is **not a valid IAM action** and is excluded.

---

### ST-CDCU-DataEngineering

Access for Data Engineers working on ETL scripts, SageMaker Studio/JupyterLab spaces, and Athena queries.

| Policy Sid | Service | Actions | Resource Scope |
|---|---|---|---|
| `S3DataLakeAccess` | S3 | GetObject, PutObject, DeleteObject, ListBucket, GetBucketVersioning, PutBucketVersioning | `cdcu-{env}-data-lake` bucket |
| `GlueCrawlerAndETL` | Glue | Same as ST-CDCU-GlueExecutionRole | `*` |
| `SageMakerAccess` | SageMaker | Same as ST-CDCU-SageMakerExecutionRole | `*` |
| `AthenaAccess` | Athena | Same as ST-CDCU-AthenaQueryRole | `cdcu-{env}-workgroup` ARN |
| `AthenaResultsAccess` | S3 | GetObject, PutObject, ListBucket | `cdcu-{env}-athena-results` bucket |
| `SecretsManagerReadAccess` | Secrets Manager | GetSecretValue, DescribeSecret, ListSecrets, ListSecretVersionIds, GetResourcePolicy, BatchGetSecretValue | `cdcu/{env}/*` secrets |
| `CloudWatchLogsRead` | CloudWatch Logs | GetLogEvents | `/aws/glue/*`, `/aws-glue/*`, `/aws/sagemaker/*`, and log-stream ARNs |
| `CloudWatchLogsDescribe` | CloudWatch Logs | DescribeLogGroups, DescribeLogStreams | `*` |

---

### ST-CDCU-QA

Read-only access for QA testers to validate pipeline outputs via Athena and CloudWatch.

| Policy Sid | Service | Actions | Resource Scope |
|---|---|---|---|
| `S3AthenaResultsRead` | S3 | GetObject, ListBucket | `cdcu-{env}-athena-results` bucket only |
| `AthenaReadOnly` | Athena | GetQueryExecution, GetQueryResults, ListQueryExecutions, GetWorkGroup | `cdcu-{env}-workgroup` ARN |
| `CloudWatchLogsRead` | CloudWatch Logs | GetLogEvents | `/aws/glue/*`, `/aws-glue/*`, and log-stream ARNs |
| `CloudWatchLogsDescribe` | CloudWatch Logs | DescribeLogGroups, DescribeLogStreams | `*` |

---

## Shared Deny Policies

These deny statements are attached to **all roles and groups** above. They enforce the
boundary that Stratpoint does not own or modify BPI MS's account baseline.

| Policy Sid | Denied Actions | Resource |
|---|---|---|
| `DenySensitiveServices` | `iam:*`, `organizations:*`, `rds:*`, `secretsmanager:CreateSecret`, `secretsmanager:UpdateSecret`, `secretsmanager:DeleteSecret`, `secretsmanager:PutSecretValue`, `cloudformation:*`, `cloudshell:*` | `*` |
| `DenyOutsideRegion` | All actions where `aws:RequestedRegion != ap-southeast-1` | `*` |

---

## VPC Access Clarification

EC2 and VPC are **outside Terraform ownership** for this project per the README.
Terraform consumes `vpc_id`, `subnet_id`, and `existing_security_group_id` as input
values only. The only EC2 permissions in the IAM module are Glue VPC placement actions
required for Glue jobs/crawlers to create and remove runtime network interfaces in the
approved subnet/security group path. These are runtime support permissions, not EC2
instance or networking governance permissions.

BPI MS owns and manages all network resources. Stratpoint has confirmed that EC2 actions
are blocked at the account level for Stratpoint IAM users.

---

## Terraform Module File Structure

```text
modules/iam/
├── main.tf        # aws_iam_role, aws_iam_policy, aws_iam_group, attachments
├── variables.tf   # environment, bucket ARNs, workgroup name, lock table name, tags
└── outputs.tf     # role ARNs, group names
```

The module is wired into both environment roots:

```text
environments/pre-prod/main.tf  →  module "iam" { source = "../../modules/iam" }
environments/prod/main.tf      →  module "iam" { source = "../../modules/iam" }
```

Once the IAM module runs, `module.iam.glue_execution_role_arn` and
`module.iam.sagemaker_execution_role_arn` replace the `existing_*` input variables
that were previously filled manually in `terraform.tfvars`.

---

## RBAC Summary by Team

| Team | IAM Group / Role | Access Level |
|---|---|---|
| Cloud Engineering | `ST-CDCU-CloudEngineering` | Full deploy — all services + Terraform state |
| Data Engineering | `ST-CDCU-DataEngineering` | S3, Glue, SageMaker, Athena, Secrets Manager |
| QA | `ST-CDCU-QA` | Read-only — Athena results, CloudWatch logs |
| Glue service | `ST-CDCU-GlueExecutionRole` | ETL jobs and crawlers at runtime |
| SageMaker service | `ST-CDCU-SageMakerExecutionRole` | ML jobs and Studio at runtime |
| QuickSight service | `ST-CDCU-AthenaQueryRole` | Dashboard queries via Athena |

---

## Pre-Deployment Checklist for BPI MS

Before running `terraform apply` on the IAM module:

- [ ] Confirm `ST-CDCU` prefix is acceptable for resource naming in BPI MS account
- [ ] Confirm Terraform lock table name matches the backend table, such as `cdcu-terraform-locks-pre-prod` or `cdcu-terraform-locks-prod`
- [ ] Confirm `q:PassRequest` removal is acknowledged — it is not a valid IAM action
- [ ] Confirm Secrets Manager write/delete access is **not** granted to Stratpoint roles — BPI MS owns secret values
- [ ] Provide CE access to Stratpoint once scripts are reviewed and approved
