# CDCU Terraform Infrastructure Repository

**BPI-MS Customer Data Clean-Up (CDCU) — AWS Platform Infrastructure as Code**

This repository provisions and manages all application-level AWS services for the CDCU data pipeline using Terraform. The pipeline processes approximately 1 million customer records through:

```
MySQL → AWS Glue → S3 → SageMaker → Athena → QuickSight
```

All services, including source databases, reside within the BPI-managed AWS account. Foundational infrastructure (VPC, subnets, networking, account governance) is managed separately by BPI MS and is outside the scope of this repository.

---

## Repository Structure

```
terraform-etl-analytics/
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml      # PR validation: fmt, validate, plan
│       └── terraform-apply.yml     # Merge to main: apply
├── artifacts/                      # Data Engineering scripts (auto-deployed to S3)
│   ├── glue/                       # Glue ETL scripts (.py)
│   ├── sagemaker/                  # SageMaker processing scripts (.py)
│   ├── matching/                   # Customer matching logic (.py)
│   └── sql/                        # Athena SQL queries and views (.sql)
├── bootstrap/
│   └── bootstrap.sh                # One-time remote state provisioning
├── environments/
│   ├── pre-prod/                   # Pre-production environment root
│   └── prod/                       # Production environment root
│       ├── main.tf                 # Module composition
│       ├── providers.tf            # Provider and version constraints
│       ├── backend.tf              # Remote state configuration
│       ├── variables.tf            # Input variable declarations
│       ├── outputs.tf              # Output value declarations
│       └── terraform.tfvars.example
├── modules/
│   ├── artifacts/                  # S3 artifact deployment (fileset-based)
│   ├── kms/                        # Customer-managed KMS key
│   ├── iam/                        # All IAM roles and RBAC policies
│   ├── security_groups/            # Glue security group
│   ├── s3/                         # Data lake and Athena results buckets
│   ├── secrets_manager/            # MySQL and service credential secrets
│   ├── glue/                       # Glue connections, jobs, crawlers
│   ├── sagemaker/                  # SageMaker Studio, notebooks, and code repository
│   ├── quicksight/                 # QuickSight Athena data source and SPICE dataset
│   ├── athena/                     # Athena workgroup and named queries
│   └── cloudwatch/                 # Log groups, metric filters, alarms
├── docs/
│   ├── iam-role-matrix.md
│   ├── deployment-guide.md
│   ├── operations-runbook.md
│   └── troubleshooting.md
├── .gitignore
└── README.md
```

---

## Prerequisites

| Tool | Minimum Version | Install |
|------|----------------|---------|
| Terraform | 1.6.0 | https://developer.hashicorp.com/terraform/install |
| AWS CLI | 2.x | https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html |
| Git | 2.x | https://git-scm.com/downloads |

---

## AWS CLI and SSO Setup

1. Configure your AWS SSO profile:

```bash
aws configure sso --profile cdcu-pre-prod-profile
# SSO start URL: https://your-org.awsapps.com/start
# SSO region: ap-southeast-1
# Account ID: <provided by BPI MS Cloud Engineer>
# Role name: cdcu-pre-prod-terraform-deployment-role
```

2. Authenticate before running Terraform:

```bash
aws sso login --profile cdcu-pre-prod-profile
```

3. Verify access:

```bash
aws sts get-caller-identity --profile cdcu-pre-prod-profile
```

---

## First-Time Setup (Bootstrap)

Run the bootstrap script **once per environment** before any `terraform init`. This creates the S3 state bucket and DynamoDB lock table.

```bash
cd bootstrap
chmod +x bootstrap.sh
./bootstrap.sh pre-prod cdcu-pre-prod-profile
./bootstrap.sh prod     cdcu-prod-profile
```

---

## Terraform Execution

### Local Execution

```bash
# 1. Navigate to the target environment
cd environments/pre-prod

# 2. Copy and fill in tfvars
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with actual values from BPI MS Cloud Engineer

# 3. Initialize
terraform init

# 4. Format check
terraform fmt -check -recursive

# 5. Validate
terraform validate

# 6. Plan
terraform plan -var-file="terraform.tfvars" -out=tfplan

# 7. Apply (after reviewing plan)
terraform apply tfplan
```

### Switching Environments

```bash
cd environments/prod
terraform init   # Re-init required — different backend
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

---

## Artifact Deployment

Data Engineering scripts in `artifacts/` are automatically uploaded to S3 on every `terraform apply`. No manual upload step is needed.

```
artifacts/glue/        → s3://cdcu-{env}-data-lake/{env}/glue-scripts/
artifacts/sagemaker/   → s3://cdcu-{env}-data-lake/{env}/sagemaker-scripts/
artifacts/matching/    → s3://cdcu-{env}-data-lake/{env}/matching-scripts/
artifacts/sql/         → s3://cdcu-{env}-data-lake/{env}/sql/
```

Files are versioned by MD5 hash — Terraform only re-uploads changed files. See `artifacts/README.md` for naming conventions and usage.

---

## Branching Strategy

| Branch | Purpose | Deploys To |
|--------|---------|-----------|
| `main` | Production-ready code | Determined by commit tag |
| `feature/pre-prod-*` | Pre-prod feature work | pre-prod |
| `feature/prod-*` | Prod changes | prod (requires approval) |
| `hotfix/prod-*` | Emergency prod fixes | prod (requires approval) |

### Environment Promotion

```
feature branch → PR → pre-prod → prod
```

Each promotion requires a pull request with at least one peer review approval. Production deployments require manual approval via GitHub environment protection rules.

To target prod on merge, include `[env:prod]` in the commit message. All other merges default to pre-prod.

---

## Environment Configuration

| Setting | pre-prod | prod |
|---------|----------|------|
| KMS Encryption | Disabled | Enabled |
| Log Retention | 30 days | 90 days |
| Glue Workers | 2 × G.1X | 10 × G.1X |
| Secret Recovery | 7 days | 30 days |
| Secret Rotation | Disabled | Enabled |
| SNS Alerts | Optional | Required |

---

## S3 Data Lake Structure

```
cdcu-{env}-data-lake/
├── {env}/
│   ├── glue-scripts/       # Glue ETL scripts (auto-deployed from artifacts/)
│   ├── sagemaker-scripts/  # SageMaker processing scripts (auto-deployed)
│   ├── matching-scripts/   # Matching logic scripts (auto-deployed)
│   └── sql/                # Athena SQL files (auto-deployed)
├── raw/
│   ├── microsite/          # Raw Microsite MySQL extracts
│   └── legacy/             # Raw Legacy MySQL extracts
├── standardized/
│   ├── microsite/          # Parquet — standardized Microsite data
│   └── legacy/             # Parquet — standardized Legacy data
├── processed/
│   └── matching/
│       ├── merge/          # High-confidence duplicate pairs
│       ├── unique/         # Confirmed unique records
│       └── manual_review/  # Records requiring human review
├── logs/                   # Job execution logs
└── errors/                 # Error records and exception outputs
```

---

## SageMaker Configuration

SageMaker Studio is provisioned by this repository when `enable_sagemaker_unified_studio = true`. The prod defaults match the implementation estimate: 2 Studio user profiles and 4 classic on-demand notebook instances for data science work.

Approved instance specifications (from AWS pricing estimate):

| Use Case | Instance | vCPU | Memory | Storage |
|----------|----------|------|--------|---------|
| Studio Notebooks | ml.t3.medium | 2 | 4 GiB | EBS only |
| Processing Jobs | ml.c4.2xlarge | 8 | 15 GiB | EBS (gp2) |

Processing and training jobs remain on-demand workloads invoked via the AWS console or CLI. See `artifacts/sagemaker/README.md` for the job invocation template.

---

## QuickSight Configuration

The QuickSight module provisions author/reader/admin groups, an Athena data source, and a SPICE dataset for the CDCU matching output. The AWS account must already have QuickSight subscribed. If `quicksight_admin_principal_arn` is left blank, the module-created admin group owns the data source and dataset; otherwise point it to an existing QuickSight user or group, for example:

```
arn:aws:quicksight:ap-southeast-1:123456789012:group/default/cdcu-admins
```

---

## IAM Roles Summary

| Role | Principal | Purpose |
|------|-----------|---------|
| `cdcu-{env}-terraform-deployment-role` | GitHub Actions OIDC | CI/CD Terraform execution |
| `cdcu-{env}-glue-execution-role` | glue.amazonaws.com | Glue job and crawler execution |
| `cdcu-{env}-sagemaker-execution-role` | sagemaker.amazonaws.com | SageMaker processing jobs |
| `cdcu-{env}-athena-query-role` | athena.amazonaws.com | Athena query execution |
| `cdcu-{env}-quicksight-access-role` | quicksight.amazonaws.com | QuickSight data source access |
| `cdcu-{env}-developer-role` | SSO (Data Engineers) | Human developer access |
| `cdcu-{env}-readonly-role` | SSO (QA / Business) | Read-only dashboard access |

---

## Security Notes

- No credentials are stored in this repository
- All secrets are stored in AWS Secrets Manager under `cdcu/{env}/`
- S3 buckets enforce HTTPS-only access and block all public access
- All IAM roles are region-restricted to `ap-southeast-1`
- KMS encryption is mandatory for `prod`
- GitHub Actions uses OIDC — no long-lived AWS credentials in secrets

---

## Monthly Cost Estimate (ap-southeast-1)

Based on the approved AWS pricing estimate:

| Service | Monthly (USD) |
|---------|--------------|
| SageMaker Studio Notebooks (ml.t3.medium × 2) | $2.02 |
| SageMaker On-Demand Notebooks (ml.c4.2xlarge) | $9.03 |
| SageMaker Processing (ml.c4.2xlarge) | $13.30 |
| SageMaker Training (ml.c4.2xlarge) | $13.47 |
| Amazon Athena (200 queries/day, 4 DPUs) | $44.68 |
| Amazon QuickSight (1 author, 10 readers, 10 GB SPICE) | $72.00 |
| AWS Glue ETL Jobs (10 DPUs) | $9.94 |
| AWS Glue Crawlers (6 crawlers) | $22.02 |
| S3 Standard (1 GB) | $0.03 |
| Data Transfer | $0.12 |
| **Total** | **$186.61** |

Full estimate: https://calculator.aws/#/estimate?id=09ba761ef64e85d83204232e72aa14cbdb8e2c5e

---

## Support

For infrastructure issues, contact the Stratpoint Cloud Engineering team.
For access issues, contact the BPI-MS Cloud Administrator.
