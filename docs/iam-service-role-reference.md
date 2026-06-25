# CDCU IAM and Service Role Reference

## Purpose

This document is the current implementation reference for CDCU IAM access
across SIT, UAT, and production. It complements the BPI-MS IAM design
documentation without duplicating complete policy documents.

This document forms part of the controlled CDCU deployment documentation set.
For the executive handoff view and review/approval record, also refer to the
repository [`README.md`](../README.md) and the root
[`deployment-guide.md`](../deployment-guide.md).

The authoritative configuration remains:

- `cdcu-access.yaml` for human users, team groups, optional Lake Formation
  grants, and operational console access;
- `modules/iam/main.tf` for Terraform-managed runtime roles, runtime policies,
  and compatibility groups consumed by the environment roots.

When this document differs from deployed AWS configuration, compare the active
policy version with the corresponding source file before making changes.

## Access Model

CDCU uses group-based access for human users and service roles for AWS
workloads:

```text
Human user
  -> environment-specific IAM group
  -> customer-managed and group-inline policies

AWS service
  -> ST-CDCU environment execution role
  -> resource-scoped runtime policies
```

Do not attach CDCU service execution policies directly to IAM users. Direct
user attachments should be exceptional, approved, documented, and periodically
reviewed.

## Environment Naming

Human access groups created by `cdcu-access.yaml` use:

```text
{environment}-cdcu-{group}
```

Examples:

```text
sit-cdcu-data-engineers
uat-cdcu-cloud-engineers
prod-cdcu-qa
```

Terraform runtime roles and compatibility groups use:

```text
ST-CDCU-{environment}-{name}
```

Examples:

```text
ST-CDCU-uat-GlueExecutionRole
ST-CDCU-uat-SageMakerExecutionRole
ST-CDCU-uat-AthenaQueryRole
ST-CDCU-uat-EventBridgeGlueRole
```

The two naming models must not be treated as interchangeable. BPI-MS should
use the environment groups from `cdcu-access.yaml` as the primary human access
model. The `ST-CDCU` execution roles are for AWS services.

## Human Access Groups

### Cloud Engineering

Primary group:

```text
{environment}-cdcu-cloud-engineers
```

Main access:

- CDCU CodeCommit and CodePipeline operations;
- Glue, Athena, SageMaker, Secrets Manager, and S3 operational validation;
- CDCU EventBridge rule and S3 event-notification management;
- CloudWatch logs and metrics used for troubleshooting;
- Amazon Q Developer console assistance.

Supporting visibility groups:

| Group | Purpose |
|---|---|
| `{environment}-cdcu-cloud-engineers-cv` | S3 console validation and VPC read-only visibility |
| `{environment}-cdcu-cloud-engineers-tg` | Broader infrastructure and IAM read-only troubleshooting visibility |
| `{environment}-cdcu-codepipeline-viewers` | Pipeline visibility |
| `{environment}-cdcu-release-managers` | Pipeline approval capability |
| `{environment}-cdcu-terraform-operators` | Terraform backend state and lock access only |

Cloud Engineering does not receive unrestricted IAM administration or broad
PassRole. Its EventBridge and pipeline PassRole permissions are restricted to
approved CDCU roles and destination services.

### Data Engineering

Primary group:

```text
{environment}-cdcu-data-engineers
```

Main access:

- Glue jobs, crawlers, connections, Data Catalog, Studio, and run monitoring;
- S3 access to approved CDCU data-lake, script, and Athena-result locations;
- SageMaker Studio, JupyterLab, and approved processing/training resources;
- Athena queries and saved-query operations in the CDCU workgroup;
- read access to `cdcu/{environment}/*` Secrets Manager resources;
- CloudWatch log and metric troubleshooting;
- CDCU EventBridge crawler-trigger rules and S3 bucket notifications;
- approved PassRole operations for CDCU Glue, SageMaker, and EventBridge roles;
- Amazon Q Developer console assistance.

The group receives the following customer-managed policies:

| Policy | Purpose |
|---|---|
| `{environment}-cdcu-global-security-policy` | Shared security baseline and explicit denies |
| `{environment}-cdcu-developer-policy` | CodeCommit and approved development access |
| `{environment}-cdcu-sagemaker-policy` | SageMaker Studio and CDCU workload access |
| `{environment}-cdcu-de-passrole-policy` | Restricted PassRole for approved execution roles |
| `{environment}-cdcu-athena-policy` | CDCU Athena workgroup and result access |
| `{environment}-cdcu-secretsmanager-policy` | Read access to CDCU environment secrets |
| `{environment}-cdcu-glue-policy` | Glue catalog, jobs, crawlers, connection, and monitoring access |
| `{environment}-cdcu-data-engineering-least-privilege-patch` | Core resource-scoped DE access |
| `{environment}-cdcu-data-engineering-optional-access` | Conditional console and authoring permissions |

Its group-inline policies provide:

- read-only VPC/RDS troubleshooting;
- CDCU EventBridge rule management and schema discovery;
- S3 event-notification read/write on CDCU data-lake buckets.

### Developers

Group:

```text
{environment}-cdcu-developers
```

This group receives the shared security and developer policies plus an inline
policy for `cdcu-{environment}-*` EventBridge rules. It should not be used as a
replacement for the Data Engineering group when Glue, Athena, SageMaker, or
Secrets Manager access is required.

### QA and Business Review

Groups:

```text
{environment}-cdcu-qa
{environment}-cdcu-business-review
```

These groups receive:

- the shared security policy;
- `{environment}-cdcu-qa-validation-policy`;
- Athena validation in the CDCU workgroup;
- read-only Glue Data Catalog discovery for `cdcu_{environment}_catalog`;
- S3 console bucket discovery and read-only access to the CDCU data lake;
- read/write access required for Athena query results;
- QuickSight dashboard, analysis, dataset, and data-source review.

They do not receive Glue or SageMaker administration, PassRole, Terraform
backend access, or unrestricted S3 data-lake write access.

The QA validation policy must include the console-discovery actions required
to navigate Athena and S3. These actions do not grant unrestricted object or
catalog access:

```text
glue:GetDatabase
glue:GetDatabases
glue:GetTable
glue:GetTables
glue:GetPartition
glue:GetPartitions
s3:ListAllMyBuckets
s3:GetBucketLocation
athena:ListWorkGroups
athena:ListDataCatalogs
athena:ListDatabases
athena:ListTableMetadata
```

Data access remains scoped to the environment catalog and buckets:

```text
arn:aws:glue:REGION:ACCOUNT_ID:database/cdcu_ENVIRONMENT_catalog
arn:aws:glue:REGION:ACCOUNT_ID:table/cdcu_ENVIRONMENT_catalog/*
arn:aws:s3:::cdcu-ENVIRONMENT-data-lake
arn:aws:s3:::cdcu-ENVIRONMENT-data-lake/*
arn:aws:s3:::cdcu-ENVIRONMENT-athena-results
arn:aws:s3:::cdcu-ENVIRONMENT-athena-results/*
```

QuickSight IAM permissions must still be paired with QuickSight user
registration, the approved Reader role, and dashboard or dataset sharing.

Athena must be able to verify the configured results bucket before a query
runs. The QA policy therefore requires `s3:GetBucketLocation` and
`s3:ListBucket` on the environment Athena results bucket, plus
`s3:GetObject` and `s3:PutObject` on its query-results objects. Because the
bucket is provisioned separately, QA does not require `s3:CreateBucket`,
`s3:GetBucketPolicy`, or `s3:GetBucketVersioning`.

For example:

```text
arn:aws:s3:::cdcu-ENVIRONMENT-athena-results
arn:aws:s3:::cdcu-ENVIRONMENT-athena-results/*
```

The environment-specific `-apse1` bucket variant is also supported by
`cdcu-access.yaml`.

## Customer-Managed Policies

`cdcu-access.yaml` defines the following environment policies:

| Policy | Responsibility |
|---|---|
| `{environment}-cdcu-global-security-policy` | Password self-service, CDCU logging baseline, regional and sensitive-operation restrictions |
| `{environment}-cdcu-developer-policy` | CDCU CodeCommit and development access |
| `{environment}-cdcu-qa-validation-policy` | Athena and QuickSight validation |
| `{environment}-cdcu-codepipeline-policy` | Pipeline viewing and approval |
| `{environment}-cdcu-athena-policy` | Athena workgroup, saved queries, and result bucket |
| `{environment}-cdcu-sagemaker-policy` | Studio discovery, app lifecycle, jobs, and CDCU S3 access |
| `{environment}-cdcu-secretsmanager-policy` | CDCU secret read and approved KMS operations |
| `{environment}-cdcu-de-passrole-policy` | Restricted DE PassRole |
| `{environment}-cdcu-terraform-backend-policy` | Terraform state bucket and lock table |
| `{environment}-cdcu-glue-policy` | Glue catalog, jobs, crawlers, connections, Studio, and monitoring |
| `{environment}-cdcu-data-engineering-least-privilege-patch` | Core DE Athena, S3, and Glue access |
| `{environment}-cdcu-data-engineering-optional-access` | Optional DE console and authoring access |
| `{environment}-cdcu-quicksight-bootstrap-policy` | Temporary QuickSight subscription/bootstrap access when enabled |

The QuickSight bootstrap policy must be attached only to an approved
administrator for initial account setup and removed after subscription and
regional setup are complete.

## Runtime Service Roles

### Glue execution role

Role:

```text
ST-CDCU-{environment}-GlueExecutionRole
```

Trusted service:

```text
glue.amazonaws.com
```

Responsibilities:

- read Glue scripts from the environment artifact prefixes;
- read and write approved raw, standardized, processed, error, and temporary
  S3 prefixes;
- create and update the environment Glue catalog tables and partitions;
- use the approved Glue JDBC connection;
- read `cdcu/{environment}/*` secrets;
- create and write Glue CloudWatch logs;
- use the approved KMS key when enabled.

The catalog scope is:

```text
cdcu_{environment}_catalog
```

A manually created catalog database is not automatically included. New catalog
databases must be approved and added to infrastructure as code rather than
granted through an ad hoc wildcard.

### SageMaker execution role

Role:

```text
ST-CDCU-{environment}-SageMakerExecutionRole
```

Trusted service:

```text
sagemaker.amazonaws.com
```

Responsibilities:

- run CDCU Studio, JupyterLab, processing, training, and model operations;
- access approved CDCU data-lake and Athena-result buckets;
- read Glue catalog metadata and use Athena where required;
- write SageMaker and processing logs;
- use approved Amazon Q data-science capabilities when enabled.

### Athena query role

Role:

```text
ST-CDCU-{environment}-AthenaQueryRole
```

Trusted service:

```text
quicksight.amazonaws.com
```

Responsibilities:

- run queries in `cdcu-{environment}-workgroup`;
- read Glue metadata from `cdcu_{environment}_catalog`;
- write and read query results in the approved Athena results bucket;
- support QuickSight access through the approved account configuration.

### EventBridge invocation role

Role:

```text
ST-CDCU-{environment}-EventBridgeGlueRole
```

Trusted service:

```text
events.amazonaws.com
```

Attached policy:

```text
ST-CDCU-{environment}-EventBridgeGlueAccess
```

Responsibilities:

- start `cdcu-{environment}-*` Glue crawlers;
- start `cdcu-{environment}-*` Glue jobs;
- create approved `cdcu-{environment}-*` SageMaker processing jobs;
- pass only `ST-CDCU-{environment}-SageMakerExecutionRole` to SageMaker.

This policy remains attached to the EventBridge role. It must not be attached
directly to a human user.

## PassRole Boundaries

Human PassRole permissions are limited by both role ARN and destination
service:

| Approved role | Destination service |
|---|---|
| `ST-CDCU-{environment}-GlueExecutionRole` | `glue.amazonaws.com` |
| `ST-CDCU-{environment}-SageMakerExecutionRole` | `sagemaker.amazonaws.com` |
| `ST-CDCU-{environment}-EventBridgeGlueRole` | `events.amazonaws.com` |

Pipeline-related PassRole is separately restricted to approved
`cdcu-{environment}-*` CodePipeline and CodeBuild roles.

Do not replace these statements with `iam:PassRole` on `*`.

## Lake Formation

IAM permission alone may not provide catalog or table access when Lake
Formation governs a resource. `cdcu-access.yaml` can grant:

- Glue execution-role permissions on the environment database;
- Glue data-location access to the CDCU data-lake;
- Athena principal `DESCRIBE` and `SELECT`;
- QuickSight principal `DESCRIBE` and `SELECT`.

Lake Formation principals must be IAM users, roles, or supported QuickSight
principals. IAM groups cannot be used directly as Lake Formation principals.

The legacy SIT `cdcu_standardized_db` database is not part of the target catalog
design. The approved catalog pattern is `cdcu_{environment}_catalog`.

## Required Wildcard Statements

`Resource: "*"` does not automatically mean unrestricted administrative
access. AWS requires it for some account-level discovery APIs that do not
support resource ARNs.

Examples in this implementation include:

- CloudWatch metric and log-group discovery;
- SageMaker `List*`, search, and some Studio discovery operations;
- Glue crawler metrics and account-level monitoring summaries;
- EventBridge and Scheduler list operations;
- EventBridge Schemas list and search operations;
- EC2 and RDS `Describe*` network troubleshooting;
- S3 `ListAllMyBuckets` for approved console workflows;
- Secrets Manager and KMS list operations.

Write, delete, start, update, data access, and PassRole actions should remain
resource-scoped whenever AWS supports resource-level permissions.

## Known Validation Item

IAM Access Analyzer reported that `glue:GetScript` is not a valid Glue IAM
action. Glue script access is provided through:

- `glue:GetJob` to read the job and its `ScriptLocation`;
- `s3:GetObject` on the approved Glue script prefix;
- `s3:PutObject` when authorized script updates are required;
- `glue:CreateScript` and `glue:GetDataflowGraph` for supported Glue Studio
  generation workflows.

`glue:GetScript` has been removed from `cdcu-access.yaml` and the Terraform IAM
mirror. Redeploy the target human-access stack and Terraform IAM module, then
rerun IAM Access Analyzer to confirm that the active policy no longer contains
the invalid action.

## Validation Procedure

### Validate policy syntax

Retrieve and validate the active policy version:

```bash
export AWS_PROFILE=bpims-core-uat
export ACCOUNT_ID=765875313224
POLICY_NAME=uat-cdcu-glue-policy
POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME"

VERSION=$(aws iam get-policy \
  --policy-arn "$POLICY_ARN" \
  --query 'Policy.DefaultVersionId' \
  --output text)

aws iam get-policy-version \
  --policy-arn "$POLICY_ARN" \
  --version-id "$VERSION" \
  --query 'PolicyVersion.Document' \
  --output json > "/tmp/$POLICY_NAME.json"

aws accessanalyzer validate-policy \
  --policy-document "file:///tmp/$POLICY_NAME.json" \
  --policy-type IDENTITY_POLICY
```

Change the profile, account ID, and policy name for SIT or production.

### Validate effective access

Use principal-policy simulation for a real user or role and the exact target
resource. Include required context keys such as `aws:RequestedRegion` when the
shared security policy contains regional conditions.

```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::765875313224:user/USER_NAME \
  --action-names glue:TestConnection \
  --resource-arns arn:aws:glue:ap-southeast-1:765875313224:connection/cdcu-uat-merged-mysql \
  --context-entries \
    ContextKeyName=aws:RequestedRegion,ContextKeyValues=ap-southeast-1,ContextKeyType=string
```

### Validate group inheritance

Review:

- groups assigned to each user;
- managed and inline policies attached to each group;
- direct user policies;
- active managed-policy versions;
- permission boundaries, SCPs, and session policies;
- role trust relationships;
- Lake Formation grants where applicable.

### Validate human-access deployment separately

Human group policies from `cdcu-access.yaml` are deployed through
CloudFormation. Runtime roles and the secondary `ST-CDCU-*` groups from
`modules/iam` are deployed through Terraform. A successful Terraform apply
does not prove that the human-access CloudFormation stack was updated.

After changing `cdcu-access.yaml`, verify the target environment explicitly:

```bash
aws cloudformation describe-stacks \
  --stack-name sit-cdcu-access \
  --region ap-southeast-1 \
  --query 'Stacks[0].[StackStatus,LastUpdatedTime]'

POLICY_ARN="arn:aws:iam::929350647322:policy/sit-cdcu-qa-validation-policy"
VERSION=$(aws iam get-policy \
  --policy-arn "$POLICY_ARN" \
  --query 'Policy.DefaultVersionId' \
  --output text)

aws iam get-policy-version \
  --policy-arn "$POLICY_ARN" \
  --version-id "$VERSION" \
  --query 'PolicyVersion.Document.Statement'
```

Repeat with the UAT or production account, stack, and policy names. Confirm
the last-updated time and active policy document before asking users to
retest. If CloudFormation reports `No changes to deploy`, verify that the
latest repository revision was pulled and that the command targets the
intended account and environment.

The June 10, 2026 QA validation issue demonstrated this distinction: the
Terraform apply completed, but the SIT QA user continued to receive the old
`sit-cdcu-qa-validation-policy` until the correct human-access deployment was
used. After the correct access update, QA could access the required console
and validation functions.

## Operational Rules

- Assign human permissions through groups.
- Keep execution policies attached to service roles.
- Avoid AWS-managed full-access policies when the CDCU scoped policies are
  sufficient.
- Do not grant users permission to attach policies to themselves.
- Review explicit denies before adding a new allow.
- Validate active policy versions after every CloudFormation or Terraform
  deployment.
- Test actual runtime behavior after policy simulation.
- Record emergency manual changes and reconcile them into source control.

