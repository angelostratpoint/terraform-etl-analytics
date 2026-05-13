# CDCU Operations Runbook

## CloudWatch Alarm Response Procedures

### Alarm: cdcu-{env}-glue-job-failure

**Trigger:** A Glue job entered the FAILED state.

**Response Steps:**
1. Open CloudWatch → Log Groups → `/aws/glue/cdcu-{env}`
2. Find the failed job run log stream
3. Search for `ERROR` entries to identify the root cause
4. Common causes:
   - MySQL connection timeout → Check Secrets Manager secret is current
   - S3 write permission denied → Verify Glue execution role S3 policy
   - Schema mismatch → Review source table changes with DBA
   - Insufficient workers → Increase `glue_worker_count` in tfvars and re-apply
5. Re-run the job via AWS Console or CLI:
   ```bash
   aws glue start-job-run \
     --job-name cdcu-{env}-microsite-raw-extraction \
     --region ap-southeast-1 \
     --profile cdcu-{env}-profile
   ```

---

### Alarm: cdcu-{env}-sagemaker-job-failure

**Trigger:** SageMaker processing job failures exceeded threshold.

**Response Steps:**
1. Open CloudWatch → Log Groups → `/aws/sagemaker/cdcu-{env}`
2. Identify the failed processing job
3. Check SageMaker console → Processing → Jobs for failure reason
4. Common causes:
   - S3 input path not found → Verify Glue standardization job completed
   - Memory exceeded → Switch to a larger instance type (e.g., ml.c4.4xlarge)
   - Python dependency error → Update the processing script and re-deploy via `terraform apply`
5. Re-submit the processing job from the AWS console or CLI

---

### Alarm: cdcu-{env}-athena-query-failure

**Trigger:** Athena query failures exceeded 5 in 10 minutes.

**Response Steps:**
1. Open Athena console → Query history for the workgroup `cdcu-{env}-workgroup`
2. Identify failing queries and error messages
3. Common causes:
   - Table not found → Run the relevant Glue crawler to update catalog
   - Data scanned limit exceeded → Optimize query with partition filters
   - S3 path changed → Verify Glue crawler ran after data pipeline
4. Run validation named query from the Athena console:
   ```sql
   SELECT COUNT(*) FROM cdcu_{env}_catalog.microsite_standardized
   ```

---

## Terraform State Recovery

### State Lock Stuck

If a Terraform operation was interrupted and the state lock was not released:

```bash
# List current locks
aws dynamodb scan \
  --table-name cdcu-terraform-locks-{env} \
  --region ap-southeast-1 \
  --profile cdcu-{env}-profile

# Force-unlock (use the LockID from the scan output)
cd environments/{env}
terraform force-unlock <LOCK_ID>
```

### State Corruption

```bash
# List state versions in S3
aws s3api list-object-versions \
  --bucket cdcu-terraform-state-{env} \
  --prefix cdcu/{env}/terraform.tfstate \
  --profile cdcu-{env}-profile

# Restore a previous version
aws s3api get-object \
  --bucket cdcu-terraform-state-{env} \
  --key cdcu/{env}/terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate.backup \
  --profile cdcu-{env}-profile
```

---

## Glue Job Monitoring

```bash
# List recent job runs
aws glue get-job-runs \
  --job-name cdcu-{env}-microsite-raw-extraction \
  --max-results 10 \
  --region ap-southeast-1 \
  --profile cdcu-{env}-profile

# Get specific job run details
aws glue get-job-run \
  --job-name cdcu-{env}-microsite-raw-extraction \
  --run-id <JOB_RUN_ID> \
  --region ap-southeast-1 \
  --profile cdcu-{env}-profile
```

---

## Cost Monitoring Recommendations

1. Set AWS Budgets alert at 80% of the monthly CDCU budget (~$186/month)
2. Monitor Glue DPU-hours in CloudWatch — high DPU usage indicates inefficient jobs
3. Monitor S3 storage growth — processed data should not exceed raw data size significantly
4. Monitor Athena data scanned — queries scanning > 1 GB should be reviewed for optimization
5. SageMaker processing jobs should be stopped when complete — they are on-demand and do not incur idle costs
