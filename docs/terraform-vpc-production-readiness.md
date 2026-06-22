# CDCU Terraform and VPC Production Readiness Guide

## Purpose

This document explains the CDCU infrastructure design for BPI-MS technical
review before production deployment. It covers:

- the resources created by the Terraform environment roots;
- the network prerequisites created by `vpc-assessment.yaml`;
- the boundary between BPI-MS-owned baseline resources and CDCU-managed
  application resources;
- the required production inputs and deployment sequence;
- validation evidence required before production approval.

IAM user and group design is maintained separately and is intentionally outside
the detailed scope of this document. See
[`iam-service-role-reference.md`](iam-service-role-reference.md) for the current
human group, runtime role, PassRole, Lake Formation, and validation reference.

## Deployment Architecture

The application flow is:

```text
BPI-MS MySQL/RDS
  -> Glue JDBC connection and extraction job
  -> CDCU S3 raw prefix
  -> Glue standardization job
  -> CDCU S3 standardized prefix
  -> Glue crawlers and Data Catalog
  -> Athena / SageMaker
  -> QuickSight when enabled
```

Infrastructure is split into two layers:

1. `vpc-assessment.yaml` provides optional BPI-MS-controlled network
   prerequisites inside an existing VPC.
2. `environments/{sit,uat,prod}` provisions the CDCU application services by
   calling the reusable Terraform modules.

## Ownership Boundary

### BPI-MS baseline

BPI-MS owns and approves:

- AWS account guardrails, SCPs, permission boundaries, and deployment role;
- existing VPC, VPC CIDR, private route table, NAT path, and network ACL;
- existing RDS instance and RDS security group;
- production subnet CIDRs and Availability Zones;
- KMS key and key policy when KMS is enabled;
- database credentials and secret values;
- QuickSight subscription and account-level setup;
- Terraform backend creation or approval;
- production DNS, routing, firewall, and endpoint policy requirements.

### `vpc-assessment.yaml`

When approved and deployed by BPI-MS, the CloudFormation template creates:

- one CDCU private subnet;
- association of that subnet with an existing private route table;
- one CDCU runtime security group for Glue and SageMaker;
- runtime security-group self-ingress and self-egress;
- outbound TCP 3306 from the runtime security group to the existing RDS
  security group;
- outbound HTTPS to the VPC CIDR and the existing S3 prefix list;
- interface endpoints for Secrets Manager, Glue, CloudWatch Logs, KMS,
  SageMaker API, SageMaker Runtime, and STS.

The template does not create the VPC, route table, NAT gateway, S3 gateway
endpoint, RDS instance, RDS security group, or KMS key.

### Terraform application layer

The environment root creates:

| Module | Main resources |
|---|---|
| `modules/s3` | CDCU data lake and Athena results buckets |
| `modules/iam` | `ST-CDCU` runtime roles and their application policies |
| `modules/glue` | Catalog database, JDBC connection, jobs, and four crawlers |
| `modules/athena` | Workgroup and named queries |
| `modules/sagemaker` | Studio domain, profiles, spaces, code repository, and optional classic notebook |
| `modules/quicksight` | Groups, Athena data source, and dataset when enabled |
| `modules/artifacts` | Glue, SageMaker, and SQL artifact uploads to S3 |

The root enforces baseline inputs before creating Glue or SageMaker resources.
It does not put database passwords or secret values into Terraform.

## Terraform Dependency Flow

```text
Approved BPI-MS baseline
  -> S3
  -> IAM runtime roles
  -> Glue and SageMaker
  -> Athena and QuickSight
  -> artifact uploads
```

Important dependencies:

- Glue receives the subnet and runtime security group from the approved
  network baseline.
- SageMaker Studio uses the approved VPC, subnet list, and runtime security
  group.
- Glue jobs and crawlers use `ST-CDCU-{env}-GlueExecutionRole`.
- SageMaker uses `ST-CDCU-{env}-SageMakerExecutionRole`.
- Athena uses the Terraform-created Glue catalog database and results bucket.
- Artifact paths are derived from the environment and uploaded during
  `terraform apply`.

## VPC Assessment Inputs

The CloudFormation stack requires the following production-approved values:

| Parameter | Meaning |
|---|---|
| `Environment` | Must be `prod` for production |
| `VpcId` | Existing production BPI-MS OSP VPC |
| `VpcCidr` | CIDR of that VPC |
| `CDCUPrivateSubnetCidr` | Approved non-overlapping production subnet CIDR |
| `CDCUAvailabilityZone` | Approved production Availability Zone |
| `PrivateRouteTableId` | Existing production private route table |
| `ExistingRdsSecurityGroupId` | Production RDS security group |

The defaults currently present in `vpc-assessment.yaml` are reference values
from lower-environment assessment work. Production deployment must explicitly
provide approved values. Do not rely on the defaults.

The S3 prefix-list ID in the template must also be verified for the production
account and region before deployment.

## CloudFormation Outputs Consumed by Terraform

After the stack is complete, map its outputs as follows:

| CloudFormation output | Terraform input |
|---|---|
| `CDCUVpcId` | `vpc_id` |
| `CDCUPrivateSubnetId` | `subnet_id` and an entry in `subnet_ids` |
| `CDCURuntimeSecurityGroupId` | `existing_security_group_id` |
| `CDCUAvailabilityZone` | `availability_zone` |

`CDCUPrivateSubnetCidr` is retained as deployment evidence but is not a direct
Terraform variable.

Production should use at least two approved private subnets in different
Availability Zones when required by the BPI-MS availability standard. The
current assessment template creates one subnet per stack deployment, so a
multi-AZ design requires approved additional subnet provisioning or separate
network-stack changes before Terraform is applied.

## Required Production Inputs

Populate `environments/prod/terraform.tfvars` from approved values. Do not
commit that file.

Required decisions and inputs include:

- production Terraform deployment role ARN;
- approved VPC, subnets, Availability Zone, and runtime security group;
- unique S3 bucket names;
- production JDBC endpoint and secret name;
- existing KMS key ARN when `enable_kms = true`;
- Glue worker type and worker count;
- SageMaker Studio profile names and network mode;
- whether the classic notebook instance is approved;
- whether QuickSight is enabled and its approved principal;
- approved CodeCommit repository URL;
- production Terraform state bucket and lock table.

The secret value must be inserted or rotated outside Terraform. Terraform
references only the secret name.

## Data Catalog Design

Terraform currently creates one environment catalog:

```text
cdcu_{environment}_catalog
```

For production this becomes:

```text
cdcu_prod_catalog
```

The Glue crawlers created by `modules/glue` target this database. Standardized
files are stored under:

```text
s3://{production-data-lake}/standardized/merged/
```

SIT contains a legacy manually created database named `cdcu_standardized_db`.
It was created for the earlier Employee standardization test and contains the
legacy `employees_simple` table at `standardized/simple`. It is not created or
used by `modules/glue` and is not part of the target production design.

The approved environment catalog pattern is:

```text
SIT   -> cdcu_sit_catalog
UAT   -> cdcu_uat_catalog
Prod  -> cdcu_prod_catalog
```

Raw and standardized tables remain in the environment catalog while their
underlying data stays separated by S3 prefix. Before production, remove or
retire dependencies on `cdcu_standardized_db` and confirm that no crawler,
workflow, trigger, job, Athena query, or Lake Formation grant still references
it. Do not promote the legacy database to UAT or production.

## Artifact Locations

Terraform uploads repository artifacts to these keys:

```text
{env}/glue-scripts/extraction/
{env}/glue-scripts/standardization/
{env}/sagemaker-scripts/matching/
{env}/sagemaker-scripts/processing/
{env}/sql/
```

The production Glue job `ScriptLocation` values must match the uploaded
production prefixes. A deployment is incomplete when a Glue job exists but its
referenced script object does not.

## SageMaker Offline Python Package Promotion

SIT may use the optional outbound HTTPS rule in `vpc-assessment.yaml` to
download and test approved Python packages through the existing NAT gateway.
UAT and production must keep this optional internet-egress rule disabled and
install packages from an approved offline artifact bundle.

The validated SIT wheelhouse is stored at:

```text
s3://cdcu-sit-data-lake-apse1/artifacts/python-wheelhouse/
```

The current bundle contains 19 objects, approximately 95 MiB, including the
pinned direct packages and their dependencies:

```text
pandas==2.3.3
numpy==1.26.4
rapidfuzz==3.14.5
jellyfish==1.2.1
awswrangler==3.16.0
```

The compiled wheels were produced for CPython 3.12 on Linux x86_64. Before
promotion, verify that the target UAT or production SageMaker image uses a
compatible Python version, operating system, and processor architecture.
Rebuild and reapprove the wheelhouse when the target runtime is incompatible.

### Promotion controls

1. Validate a complete offline installation in SIT using `--no-index`.
2. Preserve the approved `requirements.txt` and generate a SHA-256 manifest.
3. Submit the bundle for the BPI-MS package scanning and approval process.
4. Copy the same immutable files to the target environment artifact prefix.
5. Verify target-bucket encryption, object ownership, and versioning controls.
6. Confirm the target SageMaker execution role has only the required
   `s3:ListBucket`, `s3:GetObject`, and, when applicable, `kms:Decrypt`
   permissions.
7. Download the wheelhouse to local SageMaker storage and install with
   `--no-index`; standard pip does not install directly from an `s3://` URL.
8. Record the checksum, S3 object list, pip output, and import-test output as
   deployment evidence.

SIT and UAT are separate AWS accounts. The default controlled promotion process
therefore downloads the approved bundle with the SIT profile and uploads the
same local files with the UAT profile. A direct S3-to-S3 sync is allowed only
when the approved principal has both source read and destination write access.

Example from an approved BPI-MS deployment workstation:

```bash
set -e

STAGING_DIR="$HOME/cdcu-python-wheelhouse"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# Download the approved source bundle from SIT.
aws s3 sync \
  s3://cdcu-sit-data-lake-apse1/artifacts/python-wheelhouse/ \
  "$STAGING_DIR/" \
  --profile bpims-dev \
  --exact-timestamps

# Generate a portable checksum manifest on macOS/Linux.
find "$STAGING_DIR" -type f ! -name SHA256SUMS -print |
  sort |
  while IFS= read -r file; do shasum -a 256 "$file"; done \
  > "$STAGING_DIR/SHA256SUMS"

# Upload the approved immutable bundle to UAT.
aws s3 sync \
  "$STAGING_DIR/" \
  s3://cdcu-uat-data-lake/artifacts/python-wheelhouse/ \
  --profile bpims-core-uat \
  --exact-timestamps

aws s3 ls \
  s3://cdcu-uat-data-lake/artifacts/python-wheelhouse/ \
  --recursive \
  --human-readable \
  --summarize \
  --profile bpims-core-uat
```

For production, repeat the upload only after UAT validation and production
approval:

```bash
aws s3 sync \
  "$STAGING_DIR/" \
  s3://cdcu-prod-data-lake/artifacts/python-wheelhouse/ \
  --profile <approved-production-profile> \
  --exact-timestamps
```

When a target bucket requires an explicit customer-managed KMS key, use the
approved `--sse aws:kms --sse-kms-key-id <key-arn>` options and confirm both
the deployment principal and SageMaker execution role are allowed by the key
policy.

### Offline install in UAT or production SageMaker

Run the installation from the target SageMaker environment:

```bash
TARGET_BUCKET=cdcu-uat-data-lake
LOCAL_WHEELHOUSE=/tmp/cdcu-wheelhouse

rm -rf "$LOCAL_WHEELHOUSE"
mkdir -p "$LOCAL_WHEELHOUSE"

aws s3 sync \
  "s3://$TARGET_BUCKET/artifacts/python-wheelhouse/" \
  "$LOCAL_WHEELHOUSE/"

python -m pip install \
  --no-index \
  --find-links "$LOCAL_WHEELHOUSE" \
  -r "$LOCAL_WHEELHOUSE/requirements.txt"

python - <<'PY'
import pandas as pd
import numpy as np
from rapidfuzz import fuzz
import jellyfish
import awswrangler as wr

print("Offline wheelhouse validation passed")
print("pandas:", pd.__version__)
print("numpy:", np.__version__)
print("rapidfuzz:", fuzz.ratio("Garcia", "Garcia"))
print("jellyfish:", jellyfish.jaro_winkler_similarity("Smith", "Smyth"))
print("awswrangler:", wr.__version__)
PY
```

Do not enable UAT or production internet egress solely for package
installation. If packages are needed repeatedly, BPI-MS may replace the S3
wheelhouse with an approved CodeArtifact repository or a versioned custom
SageMaker image.

## EventBridge Boundary

The current application Terraform creates the EventBridge invocation role and
permissions used by CDCU automation. It does not create the complete S3 event
pattern, EventBridge rule, Glue workflow, or workflow trigger.

The pattern validated in SIT was:

```text
S3 Object Created
  -> EventBridge rule
  -> Glue workflow
  -> Glue crawler
  -> Glue Data Catalog update
```

Production automation should be promoted as infrastructure as code after the
final event prefix, workflow, crawler, retry policy, and dead-letter queue
requirements are approved. Manual creation should not be treated as the
production source of truth.

## Production Deployment Sequence

1. Review and approve production names, account ID, region, and ownership.
2. Create or verify the Terraform backend.
3. Validate the existing VPC, route table, RDS security group, NAT path, NACL,
   and S3 gateway endpoint.
4. Deploy the approved production network prerequisite stack.
5. Record and review all CloudFormation outputs.
6. Deploy the approved production `cdcu-access.yaml` human-access stack.
7. Verify the active CE, DE, and QA managed-policy versions and attachments.
8. Populate the uncommitted production `terraform.tfvars`.
9. Insert or verify the production database secret outside Terraform.
10. Run formatting, initialization, validation, and plan.
11. Review the complete plan for replacement, deletion, and cross-environment
   references.
12. Apply only after BPI-MS approval.
13. Complete runtime validation before enabling automated triggers.

Example:

```bash
cd environments/prod
terraform fmt -check -recursive
terraform init -reconfigure
terraform validate
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform show tfplan
terraform apply tfplan
```

## Production Validation Checklist

### Network

- Production subnet is private and does not auto-assign public IP addresses.
- Subnet is associated with the approved private route table.
- Runtime security group has self-reference rules required by Glue.
- Runtime security group can reach the RDS security group on TCP 3306.
- RDS security group allows TCP 3306 from the runtime security group.
- HTTPS access to required AWS endpoints is available.
- VPC endpoint private DNS is enabled and endpoint status is `Available`.
- NACL and route tables do not block return traffic.

### Terraform

- Backend account, bucket, key, region, and lock table are production-specific.
- Provider assumes only the approved production deployment role.
- Plan contains no SIT or UAT account IDs, ARNs, bucket names, subnet IDs, or
  security group IDs.
- S3 names are globally unique and approved.
- KMS is enabled with the approved production key when required.
- No secret values appear in code, plan output, logs, or state inputs.

### Runtime

- Glue connection references the production endpoint, secret, subnet, and
  runtime security group.
- Glue connection test succeeds.
- Glue script objects exist at their configured S3 locations.
- Extraction writes to the approved raw prefix.
- Standardization writes to the approved standardized prefix.
- Crawlers finish successfully and update the expected production catalog.
- Athena queries run in the production workgroup and write to the production
  results bucket.
- SageMaker Studio can read and write only the approved CDCU production paths.
- QuickSight is validated only when enabled and subscribed.
- EventBridge automation is enabled only after manual pipeline validation.

### Human access

- The production `cdcu-access.yaml` stack is deployed to the production
  account, not a SIT or UAT account.
- CE, DE, and QA users inherit access through the approved environment groups;
  policies are not attached directly to individual users.
- Active managed-policy versions were inspected after deployment.
- QA can discover the Glue catalog, list CDCU buckets, read approved data-lake
  paths, execute Athena validation queries, and review approved QuickSight
  assets.
- QA can verify the production Athena results bucket through
  `s3:GetBucketLocation`, list it, and read/write only the approved query
  results objects.
- QA does not receive Glue job or crawler administration, SageMaker
  administration, PassRole, bucket creation or policy inspection, or
  unrestricted data-lake write access.
- QuickSight users are registered with the approved role and the required
  dashboards or datasets are shared explicitly.
- Lake Formation `DESCRIBE` and `SELECT` grants are verified when Lake
  Formation governs the production catalog.

## Rollback and Change Control

- Keep the reviewed Terraform plan as deployment evidence.
- Do not manually delete Terraform-managed resources during rollback.
- Use a reviewed corrective Terraform plan for configuration rollback.
- Roll back the network stack only after confirming no Glue ENIs, SageMaker
  apps, or endpoints still depend on it.
- Preserve state bucket versions and DynamoDB locking.
- Record any emergency console change and reconcile it into infrastructure as
  code before the next deployment.

## Current Open Items Before Production

- Retire the SIT legacy `cdcu_standardized_db` references after dependency
  validation; production uses `cdcu_prod_catalog`.
- Final production VPC, subnet, route table, RDS security group, and S3 prefix
  list values.
- Multi-AZ subnet requirement and implementation.
- Production KMS key and key-policy validation.
- Decision on the classic SageMaker notebook instance.
- QuickSight enablement and principal details.
- EventBridge workflow, filtering, retry, and dead-letter queue design.
- End-to-end UAT evidence covering Glue, S3, crawlers, Athena, SageMaker, and
  optional QuickSight.
- Approval and promotion of the validated SageMaker wheelhouse from SIT to UAT,
  followed by offline installation and import evidence.
- Production package strategy decision: approved S3 wheelhouse, CodeArtifact,
  or versioned custom SageMaker image.
- Production QA access validation using the same least-privilege permissions
  proven in SIT and UAT, including Glue catalog discovery and S3 console
  discovery.
