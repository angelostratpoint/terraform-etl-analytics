# CDCU IAM Role and Policy Matrix

## Role Summary

| Role Name | Trust Principal | Scope | Human/Service |
|-----------|----------------|-------|---------------|
| `cdcu-{env}-terraform-deployment-role` | GitHub Actions OIDC | Terraform IaC deployment | CI/CD |
| `cdcu-{env}-glue-execution-role` | `glue.amazonaws.com` | ETL job and crawler execution | Service |
| `cdcu-{env}-sagemaker-execution-role` | `sagemaker.amazonaws.com` | ML processing and training | Service |
| `cdcu-{env}-athena-query-role` | `athena.amazonaws.com` | Query execution | Service |
| `cdcu-{env}-quicksight-access-role` | `quicksight.amazonaws.com` | Dashboard data access | Service |
| `cdcu-{env}-developer-role` | SSO (Data Engineers) | Development and debugging | Human |
| `cdcu-{env}-readonly-role` | SSO (QA / Business) | Read-only review access | Human |

`{env}` is either `pre-prod` or `prod`.

---

## Detailed Policy Breakdown

### cdcu-{env}-glue-execution-role

| Policy | Actions | Resources |
|--------|---------|-----------|
| S3 Data Lake | GetObject, PutObject, DeleteObject, ListBucket | `arn:aws:s3:::cdcu-*` |
| Glue Catalog | Full CRUD on databases, tables, partitions, crawlers, jobs | `*` |
| Secrets Manager | GetSecretValue | `arn:aws:secretsmanager:...:secret:cdcu/*` |
| CloudWatch Logs | CreateLogGroup, CreateLogStream, PutLogEvents | `/aws/*` |
| EventBridge | PutRule, PutTargets, DescribeRule, EnableRule, DisableRule | `*` |
| KMS (prod only) | Encrypt, Decrypt, GenerateDataKey | CDCU CMK ARN |
| **DENY** | iam:*, rds:*, ec2:*, secretsmanager:Create/Update/Delete, cloudformation:*, cloudshell:* | `*` |
| **DENY** | All actions outside ap-southeast-1 | `*` |

### cdcu-{env}-sagemaker-execution-role

| Policy | Actions | Resources |
|--------|---------|-----------|
| S3 Data Lake | GetObject, PutObject, DeleteObject, ListBucket | `arn:aws:s3:::cdcu-*` |
| SageMaker | Processing, Training, Model, Endpoint, Pipeline operations | `arn:aws:sagemaker:...:*` |
| Secrets Manager | GetSecretValue | `arn:aws:secretsmanager:...:secret:cdcu/*` |
| CloudWatch Logs | CreateLogGroup, CreateLogStream, PutLogEvents | `/aws/*` |
| KMS (prod only) | Encrypt, Decrypt, GenerateDataKey | CDCU CMK ARN |
| **DENY** | Same as above | `*` |

### cdcu-{env}-developer-role (Human — Data Engineers)

| Policy | Actions | Resources |
|--------|---------|-----------|
| S3 | GetObject, PutObject, ListBucket | `arn:aws:s3:::cdcu-*` |
| Glue Jobs | StartJobRun, GetJob, GetJobRun, GetJobRuns | `arn:aws:glue:...:job/cdcu-*` |
| Glue Connections | GetConnection, GetConnections | `arn:aws:glue:...:connection/cdcu-*` |
| SageMaker Processing | Create, Describe, Stop, List processing jobs | `arn:aws:sagemaker:...:processing-job/cdcu-*` |
| SageMaker Notebooks | Describe, List notebook instances | `arn:aws:sagemaker:...:notebook-instance/cdcu-*` |
| CloudWatch Logs | GetLogEvents, DescribeLogStreams, DescribeLogGroups | `/aws/glue/cdcu-*` |
| CodeCommit | GitPull, GetRepository, ListBranches | `cdcu-repository` |
| **DENY** | Same deny policies as service roles | `*` |

### cdcu-{env}-readonly-role (Human — QA / Business)

| Policy | Actions | Resources |
|--------|---------|-----------|
| Athena | StartQueryExecution, GetQueryExecution, GetQueryResults, GetWorkGroup | `cdcu-{env}-workgroup` |
| S3 Athena Results | GetObject, ListBucket | `arn:aws:s3:::cdcu-*-athena-results` |
| QuickSight | DescribeDashboard, ListDashboards, GetDashboardEmbedUrl | `*` |
| **DENY** | Same deny policies | `*` |

---

## Shared Deny Policies (Applied to ALL CDCU Roles)

| Policy Name | Denied Actions |
|-------------|---------------|
| `cdcu-{env}-deny-sensitive-services` | `iam:*`, `organizations:*`, `ec2:*`, `rds:*`, `secretsmanager:Create/Update/Delete/Put`, `iam:PassRole`, `cloudformation:*`, `cloudshell:*` |
| `cdcu-{env}-deny-networking` | `ec2:CreateSecurityGroup`, `ec2:AuthorizeSecurityGroupIngress`, `ec2:ModifyVpc*` |
| `cdcu-{env}-region-restriction` | All actions outside `ap-southeast-1` |

---

## Service Trust Relationships

```
glue.amazonaws.com          → cdcu-{env}-glue-execution-role
sagemaker.amazonaws.com     → cdcu-{env}-sagemaker-execution-role
athena.amazonaws.com        → cdcu-{env}-athena-query-role
quicksight.amazonaws.com    → cdcu-{env}-quicksight-access-role
GitHub Actions OIDC         → cdcu-{env}-terraform-deployment-role
SSO (Data Engineers)        → cdcu-{env}-developer-role
SSO (QA / Business)         → cdcu-{env}-readonly-role
```

---

## RBAC by Team

| Team | Role | Access Level |
|------|------|-------------|
| Cloud Engineer | `cdcu-{env}-terraform-deployment-role` (via CI/CD) | Infrastructure provisioning |
| Data Engineer | `cdcu-{env}-developer-role` | S3, Glue, SageMaker, CloudWatch |
| QA Tester | `cdcu-{env}-readonly-role` | Athena queries, QuickSight dashboards |
| Business Analyst | `cdcu-{env}-readonly-role` | QuickSight dashboards only |
