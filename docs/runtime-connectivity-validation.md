# CDCU SIT Runtime Connectivity Validation

This document provides a lightweight validation approach for the current BPI-MS
SIT CDCU infrastructure.

This document forms part of the controlled CDCU deployment documentation set.
For the executive handoff view and review/approval record, also refer to the
repository [`README.md`](../README.md) and the root
[`deployment-guide.md`](../deployment-guide.md).

The target CDCU runtime flow is:

```text
Merged MySQL RDS source -> AWS Glue -> S3 -> SageMaker -> Athena -> QuickSight
```

The checks below avoid broad account discovery where possible and use known
CDCU resource names. They are intended for strict least-privilege environments.

## Important Validation Note

AWS CloudShell can validate AWS control-plane access and resource visibility,
but CloudShell does not run inside the CDCU VPC runtime path. Therefore,
CloudShell cannot fully prove private MySQL RDS connectivity.

For private RDS connectivity validation without running a Glue JDBC job, use a
SageMaker Studio terminal or notebook attached to the CDCU SageMaker Studio
domain. SageMaker Studio is deployed inside the approved CDCU VPC/subnet path
and can perform a TCP socket test to the RDS endpoint.

## VPC Endpoint and Private Egress Observation

Current endpoint visibility indicates that `bpims-osp-vpc` has an S3 Gateway
endpoint. The SSM-related interface endpoints visible in the account are
associated with a different VPC and do not automatically provide private
connectivity for the CDCU runtime subnet in `bpims-osp-vpc`.

The S3 Gateway endpoint covers S3 access only. It does not cover runtime calls
to Secrets Manager, CloudWatch Logs, KMS, Glue APIs, SageMaker APIs, SageMaker
Runtime, or STS.

The CDCU runtime services can still work without additional interface endpoints
only if the approved private subnet has another outbound path, such as NAT,
Transit Gateway, firewall/proxy egress, or another BPI-MS approved private
egress route to AWS service endpoints.

If the CDCU runtime subnet is intended to be private with no NAT or public
egress, BPI-MS should provision or confirm the following interface endpoints in
`bpims-osp-vpc`:

| Service | Endpoint service name |
|---|---|
| Secrets Manager | `com.amazonaws.ap-southeast-1.secretsmanager` |
| AWS Glue | `com.amazonaws.ap-southeast-1.glue` |
| CloudWatch Logs | `com.amazonaws.ap-southeast-1.logs` |
| KMS | `com.amazonaws.ap-southeast-1.kms` |
| SageMaker API | `com.amazonaws.ap-southeast-1.sagemaker.api` |
| SageMaker Runtime | `com.amazonaws.ap-southeast-1.sagemaker.runtime` |
| STS | `com.amazonaws.ap-southeast-1.sts` |

Without either private egress or the required interface endpoints, Glue and
SageMaker runtime workloads may fail when reading secrets, writing logs,
calling service APIs, using encrypted resources, or obtaining temporary
credentials.

## Current Console Access Findings

The following findings were observed during SIT access validation. Most of the
IAM gaps are now addressed by the merged `cdcu-access.yaml` baseline and the
Terraform-managed execution-role policies, but the checks remain useful when
BPI-MS validates a fresh deployment or newly added users.

| Area | Current observation | Likely missing access or action | Validation impact |
|---|---|---|---|
| SageMaker Studio domain visibility | DE user cannot see SageMaker domains and receives `sagemaker:ListDomains` access denied | `sagemaker:ListDomains`, `sagemaker:ListUserProfiles`, `sagemaker:ListSpaces`, `sagemaker:DescribeDomain`, `sagemaker:DescribeUserProfile`, `sagemaker:DescribeSpace` | DE cannot confirm Studio domain/profile/space from console |
| S3 bucket visibility | CE/DE cannot list buckets in the S3 console | `s3:ListAllMyBuckets`, if BPI-MS approves broad bucket listing | Console bucket list is blocked; direct known-bucket checks should be used instead |
| Known CDCU S3 bucket validation | Direct bucket checks are preferred for strict access | `s3:HeadBucket`, `s3:ListBucket`, `s3:GetObject`, and optionally `s3:PutObject` on known CDCU buckets only | Allows validation without broad S3 listing |
| Athena database visibility | DE cannot load Glue Data Catalog databases in Athena and receives `glue:GetDatabases` access denied | `glue:GetDatabases`, `glue:GetDatabase`, `glue:GetTables`, `glue:GetTable` | Athena query editor cannot browse CDCU catalog metadata |
| Athena query execution | DE cannot run query validation and receives `athena:StartQueryExecution` access denied | `athena:StartQueryExecution`, `athena:GetQueryExecution`, `athena:GetQueryResults`, `athena:StopQueryExecution`, `athena:GetWorkGroup` on CDCU workgroup | DE cannot validate CDCU data through Athena |
| Lake Formation | Tables/columns may still be inaccessible even if IAM allows Glue/Athena APIs | Lake Formation `DESCRIBE` and `SELECT` for approved Athena/DE/QA principals | Athena may show no accessible columns or block table queries |
| SageMaker running instances | Studio shows no running instances | A JupyterLab app has not been launched, or user lacks app lifecycle access | This is normal after provisioning; Terraform creates domain/profile/space but does not auto-start the app |

For strict least-privilege access, BPI-MS can continue blocking
`s3:ListAllMyBuckets` as long as direct access to the known CDCU buckets is
allowed. The required validation can be performed through direct bucket names.

## SageMaker Studio Running Instance Note

The Terraform SageMaker module provisions:

- SageMaker Studio domain,
- SageMaker user profile,
- SageMaker code repository, and
- JupyterLab space.

Terraform does not automatically launch the JupyterLab app instance. Therefore,
`No running instances` in SageMaker Studio is expected until an approved user
opens Studio and starts the JupyterLab application or space.

If the user cannot start or relaunch the JupyterLab application, BPI-MS should
review the user's SageMaker Studio app lifecycle access, including scoped
permissions such as:

```text
sagemaker:CreateApp
sagemaker:DeleteApp
sagemaker:DescribeApp
sagemaker:ListApps
sagemaker:CreatePresignedDomainUrl
```

The expected CDCU user profile naming is `data-engineering-01`. If the current
deployed profile is `data-scientist-01`, that likely came from a sample
`terraform.tfvars` value and should be aligned before final rollout if BPI-MS
approves the `data-engineering-01` naming.
The current SIT Terraform values use `data-engineer-01`.

## Current SIT Resource Names

Use these current SIT values unless BPI-MS provides updated names:

```bash
export AWS_REGION="ap-southeast-1"
export ENV="sit"

export TF_STATE_BUCKET="cdcu-terraform-state-sit-apse1"
export TF_LOCK_TABLE="cdcu-terraform-locks-sit"

export DATA_LAKE_BUCKET="cdcu-sit-data-lake-apse1"
export ATHENA_RESULTS_BUCKET="cdcu-sit-athena-results-apse1"

export SUBNET_ID="subnet-09fa18cf58e6c3df1"
export RUNTIME_SG_ID="sg-009df7c9e0a85b3eb"

export CODECOMMIT_REPO="cdcu"
export SAGEMAKER_DOMAIN_NAME="cdcu-sit-studio"
export SAGEMAKER_USER_PROFILE="data-engineer-01"
export MERGED_SECRET_NAME="cdcu/sit/merged-mysql-connection"
export MERGED_RDS_ENDPOINT="bpims-osp-db-preprod.ctsdmk8axxaq.ap-southeast-1.rds.amazonaws.com"
```

> Note: The current SIT profile is `data-engineer-01`. If a previously deployed
> profile such as `data-scientist-01` still exists, BPI-MS can retire or ignore
> it after confirming the approved user profile naming.

## 1. CloudShell Control-Plane Validation

Run this in AWS CloudShell or any approved AWS CLI environment.

```bash
#!/bin/bash
set -euo pipefail

export AWS_REGION="${AWS_REGION:-ap-southeast-1}"
export ENV="${ENV:-sit}"

export TF_STATE_BUCKET="${TF_STATE_BUCKET:-cdcu-terraform-state-sit-apse1}"
export TF_LOCK_TABLE="${TF_LOCK_TABLE:-cdcu-terraform-locks-sit}"

export DATA_LAKE_BUCKET="${DATA_LAKE_BUCKET:-cdcu-sit-data-lake-apse1}"
export ATHENA_RESULTS_BUCKET="${ATHENA_RESULTS_BUCKET:-cdcu-sit-athena-results-apse1}"

export SUBNET_ID="${SUBNET_ID:-subnet-09fa18cf58e6c3df1}"
export RUNTIME_SG_ID="${RUNTIME_SG_ID:-sg-009df7c9e0a85b3eb}"

export CODECOMMIT_REPO="${CODECOMMIT_REPO:-cdcu}"
export SAGEMAKER_DOMAIN_NAME="${SAGEMAKER_DOMAIN_NAME:-cdcu-sit-studio}"
export MERGED_SECRET_NAME="${MERGED_SECRET_NAME:-cdcu/sit/merged-mysql-connection}"

echo "== 1. Caller identity =="
aws sts get-caller-identity

echo "== 2. Terraform backend =="
aws s3api head-bucket \
  --bucket "$TF_STATE_BUCKET" \
  --region "$AWS_REGION"

aws dynamodb describe-table \
  --table-name "$TF_LOCK_TABLE" \
  --region "$AWS_REGION" \
  --query "Table.{Name:TableName,Status:TableStatus}"

echo "== 3. CDCU S3 buckets by direct name =="
aws s3api head-bucket \
  --bucket "$DATA_LAKE_BUCKET" \
  --region "$AWS_REGION"

aws s3api head-bucket \
  --bucket "$ATHENA_RESULTS_BUCKET" \
  --region "$AWS_REGION"

echo "== 4. Secrets Manager metadata only =="
aws secretsmanager describe-secret \
  --secret-id "$MERGED_SECRET_NAME" \
  --region "$AWS_REGION" \
  --query "{Name:Name,ARN:ARN}"

echo "== 5. CDCU network inputs =="
aws ec2 describe-subnets \
  --subnet-ids "$SUBNET_ID" \
  --region "$AWS_REGION" \
  --query "Subnets[].{SubnetId:SubnetId,VpcId:VpcId,CidrBlock:CidrBlock,AZ:AvailabilityZone,State:State}"

aws ec2 describe-security-groups \
  --group-ids "$RUNTIME_SG_ID" \
  --region "$AWS_REGION" \
  --query "SecurityGroups[].{GroupId:GroupId,GroupName:GroupName,VpcId:VpcId}"

echo "== 5a. VPC endpoint coverage for CDCU VPC =="
VPC_ID=$(aws ec2 describe-subnets \
  --subnet-ids "$SUBNET_ID" \
  --region "$AWS_REGION" \
  --query "Subnets[0].VpcId" \
  --output text)

aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --region "$AWS_REGION" \
  --query "VpcEndpoints[].{Name:Tags[?Key=='Name']|[0].Value,Type:VpcEndpointType,Status:State,Service:ServiceName,Subnets:SubnetIds,RouteTables:RouteTableIds}"

echo "== 5b. Route table and egress path for CDCU subnet =="
ROUTE_TABLE_IDS=$(aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=$SUBNET_ID" \
  --region "$AWS_REGION" \
  --query "RouteTables[].RouteTableId" \
  --output text)

if [ -z "$ROUTE_TABLE_IDS" ] || [ "$ROUTE_TABLE_IDS" = "None" ]; then
  ROUTE_TABLE_IDS=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=true" \
    --region "$AWS_REGION" \
    --query "RouteTables[].RouteTableId" \
    --output text)
fi

echo "Route table IDs: $ROUTE_TABLE_IDS"

aws ec2 describe-route-tables \
  --route-table-ids $ROUTE_TABLE_IDS \
  --region "$AWS_REGION" \
  --query "RouteTables[].{RouteTableId:RouteTableId,Routes:Routes}"

echo "== 6. CodeCommit repository =="
aws codecommit get-repository \
  --repository-name "$CODECOMMIT_REPO" \
  --region "$AWS_REGION" \
  --query "repositoryMetadata.{Name:repositoryName,Arn:Arn,DefaultBranch:defaultBranch}"

echo "== 7. SageMaker Studio =="
aws sagemaker list-domains \
  --region "$AWS_REGION" \
  --query "Domains[?DomainName=='$SAGEMAKER_DOMAIN_NAME'].{Name:DomainName,Id:DomainId,Status:Status}"

aws sagemaker list-user-profiles \
  --region "$AWS_REGION" \
  --query "UserProfiles[].{DomainId:DomainId,UserProfileName:UserProfileName,Status:Status}"

aws sagemaker list-spaces \
  --region "$AWS_REGION" \
  --query "Spaces[].{DomainId:DomainId,SpaceName:SpaceName,Status:Status}"

echo "== 8. Glue visibility =="
aws glue get-databases \
  --region "$AWS_REGION" \
  --query "DatabaseList[].Name"

aws glue get-jobs \
  --region "$AWS_REGION" \
  --query "Jobs[].Name"

aws glue get-crawlers \
  --region "$AWS_REGION" \
  --query "Crawlers[].Name"

aws glue get-connections \
  --region "$AWS_REGION" \
  --query "ConnectionList[].Name"

echo "== 9. Athena workgroup =="
aws athena get-work-group \
  --work-group "cdcu-sit-workgroup" \
  --region "$AWS_REGION" \
  --query "WorkGroup.{Name:Name,State:State}"

echo "CloudShell control-plane validation completed."
```

### Expected Outcome

This validates:

- caller identity is in the correct AWS account,
- Terraform backend bucket is reachable,
- DynamoDB lock table exists,
- CDCU S3 buckets exist by direct name,
- secret containers exist,
- approved subnet and runtime security group exist,
- VPC endpoint coverage and route table egress path are visible,
- CodeCommit repo exists,
- SageMaker Studio domain/profile/space is visible,
- Glue/Athena control-plane visibility is available.

This does not prove private RDS connectivity. It confirms whether the CDCU
runtime subnet appears to have either the required VPC endpoints or another
BPI-MS approved outbound route.

## 2. RDS TCP Connectivity Test from SageMaker Studio

Run this from a SageMaker Studio terminal or notebook under the approved CDCU
Studio domain. This avoids creating or running a Glue job.

### Option A: Host Provided by BPI-MS

Use this option if BPI-MS does not want the test to read secret values.

```bash
python - <<'PY'
import socket

targets = [
    ("bpims-osp-db-preprod.ctsdmk8axxaq.ap-southeast-1.rds.amazonaws.com", 3306),
]

for host, port in targets:
    print(f"Testing TCP connection to {host}:{port}")
    try:
        with socket.create_connection((host, port), timeout=10):
            print(f"SUCCESS: {host}:{port} is reachable")
    except Exception as exc:
        print(f"FAILED: {host}:{port} is not reachable - {exc}")
PY
```

### Option B: Host Loaded from Secrets Manager

Use this option only if BPI-MS approves `secretsmanager:GetSecretValue` for the
operator or runtime role. The script does not print usernames or passwords.

```bash
python - <<'PY'
import boto3
import json
import socket

REGION = "ap-southeast-1"
SECRET_NAMES = [
    "cdcu/sit/merged-mysql-connection",
]

secrets = boto3.client("secretsmanager", region_name=REGION)

def get_first(payload, keys, default=None):
    for key in keys:
        value = payload.get(key)
        if value:
            return value
    return default

for secret_name in SECRET_NAMES:
    print(f"Loading connection host from {secret_name}")
    response = secrets.get_secret_value(SecretId=secret_name)
    payload = json.loads(response["SecretString"])

    host = get_first(payload, ["host", "hostname", "server"])
    port = int(get_first(payload, ["port"], 3306))

    if not host:
        print(f"FAILED: no host field found in {secret_name}")
        continue

    print(f"Testing TCP connection to {host}:{port}")
    try:
        with socket.create_connection((host, port), timeout=10):
            print(f"SUCCESS: {host}:{port} is reachable")
    except Exception as exc:
        print(f"FAILED: {host}:{port} is not reachable - {exc}")
PY
```

### Expected Outcome

If the TCP test succeeds from SageMaker Studio, the private runtime network path
is reachable from the CDCU managed-service subnet/security-group path.

If it fails, the most likely causes are:

- RDS security group does not allow inbound from the CDCU runtime security group.
- Route table or subnet placement is not aligned with the RDS path.
- DNS resolution to the RDS endpoint is unavailable.
- Network ACL or firewall policy blocks the traffic.
- The test is not running from the VPC-attached SageMaker Studio environment.

## 3. S3 Write/Read Smoke Test

Run from CloudShell or SageMaker Studio if the role has direct access to the
known CDCU data lake bucket.

```bash
TEST_KEY="validation/connectivity-smoke-test-$(date +%Y%m%d%H%M%S).txt"

echo "cdcu connectivity smoke test" > /tmp/cdcu-connectivity-smoke-test.txt

aws s3 cp /tmp/cdcu-connectivity-smoke-test.txt \
  "s3://$DATA_LAKE_BUCKET/$TEST_KEY" \
  --region "$AWS_REGION"

aws s3 cp \
  "s3://$DATA_LAKE_BUCKET/$TEST_KEY" \
  /tmp/cdcu-connectivity-smoke-test-downloaded.txt \
  --region "$AWS_REGION"

cat /tmp/cdcu-connectivity-smoke-test-downloaded.txt
```

### Expected Outcome

This confirms the caller can write and read an object in the known CDCU data
lake bucket. If this fails, review bucket policy, IAM policy, KMS settings, and
Lake Formation/S3 location governance if enabled.

## 4. Athena Smoke Test

Run only after the Glue catalog database and tables exist.

```bash
QUERY_ID=$(aws athena start-query-execution \
  --query-string "SHOW DATABASES;" \
  --work-group "cdcu-sit-workgroup" \
  --result-configuration "OutputLocation=s3://$ATHENA_RESULTS_BUCKET/query-results/" \
  --region "$AWS_REGION" \
  --query "QueryExecutionId" \
  --output text)

echo "QueryExecutionId: $QUERY_ID"

aws athena get-query-execution \
  --query-execution-id "$QUERY_ID" \
  --region "$AWS_REGION" \
  --query "QueryExecution.Status"
```

If Lake Formation is enabled, Athena table/column queries also require
Lake Formation `DESCRIBE` and `SELECT` grants for the approved query principal.

## Minimum Permission Notes

For the checks above, BPI-MS may allow only scoped actions on known CDCU
resources:

```text
sts:GetCallerIdentity
s3:HeadBucket on known CDCU buckets
s3:ListBucket/GetObject/PutObject on known CDCU bucket prefixes, if smoke test is approved
dynamodb:DescribeTable on cdcu-terraform-locks-sit
secretsmanager:DescribeSecret on cdcu/sit/*
secretsmanager:GetSecretValue only if Option B is approved
ec2:DescribeSubnets
ec2:DescribeSecurityGroups
codecommit:GetRepository
sagemaker:ListDomains
sagemaker:ListUserProfiles
sagemaker:ListSpaces
glue:GetDatabases
glue:GetJobs
glue:GetCrawlers
glue:GetConnections
athena:GetWorkGroup
athena:StartQueryExecution
athena:GetQueryExecution
```

Amazon Q is not required for these validation checks. Amazon Q access remains a
separate IAM approval item.

## Validation Coverage

| Flow segment | Validation method |
|---|---|
| AWS account and IAM identity | `aws sts get-caller-identity` |
| Terraform backend | S3 `head-bucket` and DynamoDB `describe-table` |
| Secrets containers | Secrets Manager `describe-secret` |
| VPC placement inputs | EC2 subnet/security group describe commands |
| VPC endpoint coverage | EC2 `describe-vpc-endpoints` for the CDCU VPC |
| Private egress path | EC2 `describe-route-tables` for the CDCU subnet |
| Code repository | CodeCommit `get-repository` |
| SageMaker Studio | SageMaker list domain/profile/space commands |
| Private RDS network path | SageMaker Studio TCP socket test |
| S3 data lake access | S3 write/read smoke test |
| Glue control plane | Glue get database/job/crawler/connection commands |
| Athena workgroup | Athena `get-work-group` and optional smoke query |
| QuickSight | Manual dashboard/dataset validation after Athena and Lake Formation access are ready |
