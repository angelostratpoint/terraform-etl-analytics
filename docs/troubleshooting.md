# CDCU Terraform Troubleshooting Guide

## Common Terraform Errors

### Error: "Error acquiring the state lock"

**Cause:** Another Terraform process is running, or a previous run was interrupted.

**Solution:**
```bash
# Check DynamoDB for active locks
aws dynamodb scan \
  --table-name cdcu-terraform-locks-{env} \
  --region ap-southeast-1 \
  --profile cdcu-{env}-profile

# Force unlock if no other process is running
terraform force-unlock <LOCK_ID>
```

---

### Error: "NoSuchBucket: The specified bucket does not exist"

**Cause:** Remote state backend was not bootstrapped.

**Solution:**
```bash
cd bootstrap
./bootstrap.sh {env} cdcu-{env}-profile
```

---

### Error: "AccessDenied: User is not authorized to perform: sts:AssumeRole"

**Cause:** Your AWS SSO session expired or the Terraform role ARN is incorrect.

**Solution:**
```bash
# Re-authenticate
aws sso login --profile cdcu-{env}-profile

# Verify role ARN in terraform.tfvars matches the actual role
aws iam get-role \
  --role-name cdcu-{env}-terraform-deployment-role \
  --profile cdcu-{env}-profile
```

---

### Error: "InvalidParameterException: Subnet does not exist"

**Cause:** Subnet ID in `terraform.tfvars` is incorrect or from a different region.

**Solution:**
```bash
# Verify subnet ID with BPI MS Cloud Engineer
aws ec2 describe-subnets \
  --subnet-ids subnet-xxxxxxxxx \
  --region ap-southeast-1 \
  --profile cdcu-{env}-profile
```

---

### Error: "ResourceNotFoundException: Secret not found"

**Cause:** Secrets Manager secret was not created or is in a different region.

**Solution:**
```bash
# List secrets
aws secretsmanager list-secrets \
  --region ap-southeast-1 \
  --profile cdcu-{env}-profile

# Create the secret if missing (Terraform should have created it — check apply output)
aws secretsmanager create-secret \
  --name "cdcu/{env}/mysql-connection" \
  --secret-string '{"host":"","port":"3306","dbname":"","username":"","password":""}' \
  --region ap-southeast-1 \
  --profile cdcu-{env}-profile
```

---

### Error: "fileset() returned no files"

**Cause:** The `artifacts/` subdirectory is empty — no scripts have been added yet.

**Solution:**
Add at least one `.py` or `.sql` file to the relevant `artifacts/` subdirectory before running `terraform apply`. The `.gitkeep` placeholder files are ignored by the artifacts module.

---

## Common AWS Service Errors

### Glue Job: "Connection refused" to MySQL

**Cause:** Security group or network ACL blocking Glue → MySQL traffic.

**Solution:**
1. Verify Glue security group allows outbound HTTPS (port 443)
2. Confirm the MySQL RDS instance security group allows inbound from the Glue security group
3. Confirm subnet route table has a route to the MySQL source

---

### SageMaker: "ResourceLimitExceeded"

**Cause:** AWS account limit for SageMaker instances reached.

**Solution:**
```bash
# Request limit increase via AWS Support console
# Approved instance types: ml.t3.medium (notebooks), ml.c4.2xlarge (processing)
```

---

### Athena: "HIVE_METASTORE_ERROR: Table not found"

**Cause:** Glue crawler has not run or failed to register the table.

**Solution:**
```bash
# Start the crawler
aws glue start-crawler \
  --name cdcu-{env}-microsite-standardized-crawler \
  --region ap-southeast-1 \
  --profile cdcu-{env}-profile

# Check crawler status
aws glue get-crawler \
  --name cdcu-{env}-microsite-standardized-crawler \
  --region ap-southeast-1 \
  --profile cdcu-{env}-profile
```

---

## GitHub Actions CI/CD Errors

### Error: "OIDC token validation failed"

**Cause:** GitHub OIDC provider not configured in AWS IAM.

**Solution:**
1. Verify OIDC provider exists:
   ```bash
   aws iam list-open-id-connect-providers --profile cdcu-{env}-profile
   ```
2. If missing, create it:
   ```bash
   aws iam create-open-id-connect-provider \
     --url https://token.actions.githubusercontent.com \
     --client-id-list sts.amazonaws.com \
     --thumbprint-list <GITHUB_THUMBPRINT> \
     --profile cdcu-{env}-profile
   ```

---

### Error: "terraform plan failed with exit code 1"

**Cause:** Syntax error or missing required variable.

**Solution:**
1. Check GitHub Actions logs for the specific error
2. Run `terraform validate` locally to reproduce
3. Verify all required variables are set in GitHub Secrets

---

## Debugging Tips

### Enable Terraform Debug Logging

```bash
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform-debug.log
terraform plan -var-file="terraform.tfvars"
```

### Verify AWS Credentials

```bash
aws sts get-caller-identity --profile cdcu-{env}-profile
# Should return the assumed role ARN, not your SSO user
```

### Check Resource Tagging

```bash
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=CDCU Key=Environment,Values={env} \
  --region ap-southeast-1 \
  --profile cdcu-{env}-profile
```

---

## Escalation Path

| Issue Type | Contact |
|------------|---------|
| Terraform syntax or module errors | Stratpoint Cloud Engineer |
| AWS permission or IAM errors | BPI MS Cloud Administrator |
| Network connectivity issues | BPI MS Network team |
| MySQL source access issues | BPI MS DBA team |
| GitHub Actions CI/CD issues | Stratpoint DevOps team |
