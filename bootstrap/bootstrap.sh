#!/usr/bin/env bash
# CDCU Terraform Remote State Bootstrap Script
#
# PURPOSE:
#   Provisions the S3 bucket and DynamoDB table required for Terraform remote
#   state management. Run this ONCE per environment before any terraform init.
#
# USAGE:
#   ./bootstrap.sh <environment> <aws_profile>
#
# EXAMPLES:
#   ./bootstrap.sh sit cdcu-sit-profile
#   ./bootstrap.sh uat cdcu-uat-profile
#   ./bootstrap.sh prod cdcu-prod-profile
#
# PREREQUISITES:
#   - AWS CLI installed and configured
#   - Sufficient IAM permissions to create S3 buckets and DynamoDB tables
#   - The target AWS account and region must be ap-southeast-1

set -euo pipefail

ENVIRONMENT="${1:-}"
AWS_PROFILE="${2:-default}"
REGION="ap-southeast-1"

if [[ -z "$ENVIRONMENT" ]]; then
  echo "ERROR: Environment argument is required."
  echo "Usage: ./bootstrap.sh <environment> [aws_profile]"
  echo "Valid environments: sit, uat, prod"
  exit 1
fi

if [[ ! "$ENVIRONMENT" =~ ^(sit|uat|prod)$ ]]; then
  echo "ERROR: Invalid environment '$ENVIRONMENT'. Must be one of: sit, uat, prod"
  exit 1
fi

STATE_BUCKET="cdcu-terraform-state-${ENVIRONMENT}"
LOCK_TABLE="cdcu-terraform-locks-${ENVIRONMENT}"

echo "============================================================"
echo "CDCU Terraform Bootstrap"
echo "Environment : $ENVIRONMENT"
echo "Region      : $REGION"
echo "State Bucket: $STATE_BUCKET"
echo "Lock Table  : $LOCK_TABLE"
echo "AWS Profile : $AWS_PROFILE"
echo "============================================================"
echo ""

echo "[1/4] Creating S3 state bucket: $STATE_BUCKET"

if aws s3api head-bucket --bucket "$STATE_BUCKET" --profile "$AWS_PROFILE" 2>/dev/null; then
  echo "  -> Bucket already exists, skipping creation."
else
  aws s3api create-bucket \
    --bucket "$STATE_BUCKET" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" \
    --profile "$AWS_PROFILE"
  echo "  -> Bucket created."
fi

echo "[2/4] Enabling versioning on $STATE_BUCKET"
aws s3api put-bucket-versioning \
  --bucket "$STATE_BUCKET" \
  --versioning-configuration Status=Enabled \
  --profile "$AWS_PROFILE"
echo "  -> Versioning enabled."

echo "[3/4] Blocking public access on $STATE_BUCKET"
aws s3api put-public-access-block \
  --bucket "$STATE_BUCKET" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
  --profile "$AWS_PROFILE"
echo "  -> Public access blocked."

aws s3api put-bucket-encryption \
  --bucket "$STATE_BUCKET" \
  --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}' \
  --profile "$AWS_PROFILE"
echo "  -> Server-side encryption enabled (AES256)."

echo "[4/4] Creating DynamoDB lock table: $LOCK_TABLE"

if aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$REGION" --profile "$AWS_PROFILE" 2>/dev/null; then
  echo "  -> Table already exists, skipping creation."
else
  aws dynamodb create-table \
    --table-name "$LOCK_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION" \
    --profile "$AWS_PROFILE" \
    --tags Key=Project,Value=CDCU Key=Environment,Value="$ENVIRONMENT" Key=ManagedBy,Value=Bootstrap

  echo "  -> Waiting for table to become active..."
  aws dynamodb wait table-exists \
    --table-name "$LOCK_TABLE" \
    --region "$REGION" \
    --profile "$AWS_PROFILE"
  echo "  -> DynamoDB table created and active."
fi

echo ""
echo "============================================================"
echo "Bootstrap complete for environment: $ENVIRONMENT"
echo ""
echo "Next steps:"
echo "  1. cd environments/$ENVIRONMENT"
echo "  2. Copy terraform.tfvars.example to terraform.tfvars"
echo "  3. Fill in actual values in terraform.tfvars"
echo "  4. terraform init"
echo "  5. terraform plan"
echo "  6. terraform apply"
echo "============================================================"
