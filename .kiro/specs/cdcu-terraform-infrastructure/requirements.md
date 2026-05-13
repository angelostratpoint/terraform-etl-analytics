# Requirements Document

## Introduction

This document defines the requirements for the BPI-MS Customer Data Clean-Up (CDCU) Production-Grade Terraform Infrastructure-as-Code (IaC) repository. The platform provisions and manages AWS application-level services that process approximately 1 million customer records through a pipeline: MySQL → AWS Glue → S3 → SageMaker → Athena → QuickSight. Foundational AWS infrastructure (VPC, subnets, route tables, NAT Gateway, VPN, organization-level governance, CloudTrail, and AWS account governance) is managed separately by BPI MS and is outside the Terraform scope defined here.

## Glossary

- **CDCU**: Customer Data Clean-Up — the BPI-MS project this infrastructure supports.
- **Terraform_Module**: A reusable, self-contained Terraform configuration unit that encapsulates a specific AWS service or logical grouping.
- **Terraform_Root**: The top-level Terraform configuration for a given environment that calls Terraform_Modules and wires together environment-specific variables.
- **Remote_State_Backend**: The S3 bucket and DynamoDB table combination used to store and lock Terraform state files.
- **Bootstrap_Script**: A one-time script that provisions the Remote_State_Backend before any other Terraform execution.
- **Environment**: One of two isolated deployment targets — `pre-prod` or `prod` — each with its own state, variables, and naming conventions.
- **IAM_Role**: An AWS Identity and Access Management role assigned to a service or human principal following least-privilege RBAC principles.
- **RBAC**: Role-Based Access Control — the access model used to assign permissions to IAM_Roles.
- **Secrets_Manager**: AWS Secrets Manager, used to store and retrieve sensitive configuration values at runtime.
- **KMS_Key**: An AWS Key Management Service customer-managed key used for encryption of data at rest.
- **Glue_Job**: An AWS Glue ETL job that transforms customer data between pipeline stages.
- **Glue_Crawler**: An AWS Glue Crawler that scans S3 data and updates the Glue Data Catalog.
- **SageMaker_Studio**: Amazon SageMaker Unified Studio, used for data science and ML processing workloads.
- **Athena_Workgroup**: An Amazon Athena workgroup that isolates query execution and results per team or use case.
- **QuickSight**: Amazon QuickSight, used for business intelligence dashboards over processed customer data.
- **tfvars_File**: A Terraform `.tfvars` file containing environment-specific variable values.
- **CI_CD_Pipeline**: A GitHub Actions workflow that automates Terraform plan and apply operations across environments.
- **PR_Workflow**: A pull request-based promotion process used to gate infrastructure changes before deployment.
- **Tagging_Strategy**: A standardized set of AWS resource tags applied to all provisioned resources for cost allocation, ownership, and environment identification.
- **SSO**: AWS IAM Identity Center (Single Sign-On), the mechanism used for temporary, role-based AWS access.
- **ap-southeast-1**: The AWS region (Singapore) to which all CDCU resources are restricted.

---

## Requirements

### Requirement 1: Repository Structure and Module Organization

**User Story:** As a Data Engineer, I want a well-organized Terraform repository with reusable modules and environment-specific configurations, so that I can manage infrastructure consistently across all environments without duplicating code.

#### Acceptance Criteria

1. THE Terraform_Module SHALL be organized into one module per AWS service (S3, Glue, SageMaker, Athena, QuickSight, IAM, Secrets_Manager, CloudWatch, KMS).
2. THE Terraform_Root SHALL exist as a separate directory per Environment (`environments/pre-prod`, `environments/prod`), each containing its own `main.tf`, `variables.tf`, `outputs.tf`, `backend.tf`, and `terraform.tfvars`.
3. THE Terraform_Root SHALL reference Terraform_Modules using relative module source paths, with no inline resource definitions duplicated across environments.
4. THE Terraform_Module SHALL expose input variables and output values so that Terraform_Root configurations can compose modules without modifying module internals.
5. THE Terraform_Root SHALL apply a Tagging_Strategy to all provisioned resources, including at minimum the tags: `Project`, `Environment`, `Owner`, `ManagedBy`, and `CostCenter`.
6. THE Terraform_Root SHALL enforce environment-specific naming conventions using a consistent prefix pattern of `cdcu-{environment}-{service}-{resource}`.

---

### Requirement 2: Remote State Backend

**User Story:** As a Data Engineer, I want Terraform state stored remotely with locking, so that multiple engineers can safely execute Terraform from different devices without state corruption.

#### Acceptance Criteria

1. THE Remote_State_Backend SHALL use an S3 bucket for state file storage and a DynamoDB table for state locking per Environment.
2. THE Bootstrap_Script SHALL provision the Remote_State_Backend S3 bucket and DynamoDB table before any Terraform_Root execution.
3. THE Remote_State_Backend S3 bucket SHALL have versioning enabled, server-side encryption enabled using AES-256 or a KMS_Key, and public access blocked on all four S3 block public access settings.
4. THE Terraform_Root SHALL reference the Remote_State_Backend using a `backend "s3"` block with environment-specific bucket name, key path, and DynamoDB table name.
5. WHEN two engineers execute Terraform simultaneously against the same Environment, THE Remote_State_Backend SHALL prevent concurrent state writes by acquiring a DynamoDB lock before applying changes.
6. IF the DynamoDB lock is already held, THEN THE Terraform_Root SHALL return an error indicating the state is locked and identify the lock holder.

---

### Requirement 3: S3 Data Bucket Provisioning

**User Story:** As a Data Engineer, I want S3 buckets and folder prefixes provisioned for each pipeline stage, so that raw, standardized, processed, log, and error data are stored in isolated, secure locations.

#### Acceptance Criteria

1. THE S3 Terraform_Module SHALL provision a single CDCU data bucket per Environment with the following logical folder prefixes: `raw/microsite/`, `raw/legacy/`, `standardized/microsite/`, `standardized/legacy/`, `processed/matching/merge/`, `processed/matching/unique/`, `processed/matching/manual_review/`, `logs/`, and `errors/`.
2. THE S3 Terraform_Module SHALL enable versioning on the CDCU data bucket.
3. THE S3 Terraform_Module SHALL block all public access on the CDCU data bucket by setting all four S3 block public access settings to `true`.
4. THE S3 Terraform_Module SHALL apply a bucket policy that denies any `s3:PutObject` request that does not use `aws:SecureTransport` (HTTPS).
5. WHERE a KMS_Key is configured, THE S3 Terraform_Module SHALL enable server-side encryption using that KMS_Key as the default encryption key for the CDCU data bucket.
6. WHERE a KMS_Key is not configured, THE S3 Terraform_Module SHALL enable server-side encryption using AES-256 as the default encryption key.
7. THE S3 Terraform_Module SHALL configure a lifecycle rule that transitions objects in the `logs/` prefix to S3 Intelligent-Tiering after 30 days.
8. THE S3 Terraform_Module SHALL output the bucket name and bucket ARN for use by other Terraform_Modules.

---

### Requirement 4: AWS Glue Provisioning

**User Story:** As a Data Engineer, I want AWS Glue jobs, crawlers, and connections provisioned via Terraform, so that ETL transformations and data catalog updates are reproducible and version-controlled.

#### Acceptance Criteria

1. THE Glue Terraform_Module SHALL provision at minimum one Glue_Job per pipeline transformation stage (raw-to-standardized and standardized-to-processed).
2. THE Glue Terraform_Module SHALL provision one Glue_Crawler per S3 data prefix that requires catalog registration.
3. THE Glue Terraform_Module SHALL provision a Glue connection for the MySQL source database, referencing connection credentials stored in Secrets_Manager rather than hardcoded values.
4. THE Glue Terraform_Module SHALL assign the `cdcu-glue-execution-role` IAM_Role to all Glue_Jobs and Glue_Crawlers.
5. THE Glue Terraform_Module SHALL configure Glue_Jobs to write logs to a CloudWatch log group named `/aws/glue/cdcu-{environment}`.
6. WHEN a Glue_Job fails, THE CloudWatch Terraform_Module SHALL trigger a CloudWatch alarm that transitions to the `ALARM` state within 5 minutes of the failure event.
7. THE Glue Terraform_Module SHALL enable partition indexing on Glue Data Catalog tables to support efficient Athena queries.

---

### Requirement 5: Amazon SageMaker Unified Studio Provisioning

**User Story:** As a Data Scientist, I want SageMaker Unified Studio provisioned via Terraform, so that I can run data processing and ML workloads in a managed, secure environment.

#### Acceptance Criteria

1. THE SageMaker Terraform_Module SHALL provision a SageMaker domain configured for Unified Studio in the `ap-southeast-1` region.
2. THE SageMaker Terraform_Module SHALL assign the `cdcu-sagemaker-execution-role` IAM_Role as the default execution role for the SageMaker domain.
3. THE SageMaker Terraform_Module SHALL configure the SageMaker domain to use VPC-only network access mode, referencing subnet IDs and security group IDs provided as input variables.
4. THE SageMaker Terraform_Module SHALL write SageMaker execution logs to a CloudWatch log group named `/aws/sagemaker/cdcu-{environment}`.
5. WHERE a KMS_Key is configured, THE SageMaker Terraform_Module SHALL encrypt SageMaker storage volumes using that KMS_Key.
6. THE SageMaker Terraform_Module SHALL output the SageMaker domain ID and domain ARN for use by other Terraform_Modules.

---

### Requirement 6: Amazon Athena Provisioning

**User Story:** As a Data Analyst, I want Athena workgroups and query result locations provisioned via Terraform, so that query execution is isolated per team and results are stored securely.

#### Acceptance Criteria

1. THE Athena Terraform_Module SHALL provision one Athena_Workgroup per Environment named `cdcu-{environment}-workgroup`.
2. THE Athena Terraform_Module SHALL configure the Athena_Workgroup to enforce a query result location pointing to the `logs/` prefix of the CDCU S3 data bucket.
3. THE Athena Terraform_Module SHALL configure the Athena_Workgroup to enforce encryption of query results using SSE-S3 or SSE-KMS.
4. THE Athena Terraform_Module SHALL set a per-query data scanned limit of 10 GB on the Athena_Workgroup to control query costs.
5. THE Athena Terraform_Module SHALL output the Athena_Workgroup name and ARN for use by IAM_Role policies and QuickSight configuration.

---

### Requirement 7: Amazon QuickSight Access Configuration

**User Story:** As a Business Analyst, I want QuickSight access configured via Terraform, so that dashboard consumers have read-only access to processed data without direct access to underlying S3 or Athena resources.

#### Acceptance Criteria

1. THE QuickSight Terraform_Module SHALL configure QuickSight to use the `cdcu-quicksight-access-role` IAM_Role for data source access.
2. THE QuickSight Terraform_Module SHALL provision a QuickSight data source pointing to the Athena_Workgroup provisioned by the Athena Terraform_Module.
3. THE QuickSight Terraform_Module SHALL restrict QuickSight data source access to principals holding the `cdcu-business-review-role` IAM_Role.
4. THE QuickSight Terraform_Module SHALL output the QuickSight data source ARN for reference in access policies.

---

### Requirement 8: IAM Roles and RBAC Policies

**User Story:** As a Security Engineer, I want all IAM roles and policies defined in Terraform following least-privilege RBAC principles, so that each service and human principal has only the permissions required for its function.

#### Acceptance Criteria

1. THE IAM Terraform_Module SHALL provision the following IAM_Roles: `cdcu-terraform-deployment-role`, `cdcu-glue-execution-role`, `cdcu-sagemaker-execution-role`, `cdcu-athena-query-role`, `cdcu-quicksight-access-role`, `cdcu-developer-role`, and `cdcu-readonly-role`.
2. THE IAM Terraform_Module SHALL attach a trust policy to each IAM_Role that restricts `sts:AssumeRole` to the specific AWS service or SSO principal that requires it, with no wildcard principals.
3. THE IAM Terraform_Module SHALL restrict all IAM_Roles to the `ap-southeast-1` region using an `aws:RequestedRegion` condition on all non-global actions.
4. THE IAM Terraform_Module SHALL apply a deny policy to all CDCU IAM_Roles that explicitly denies: `iam:*`, `rds:*`, `ec2:*`, `secretsmanager:*` (except `GetSecretValue`), `iam:PassRole`, all networking change actions, `cloudformation:*`, and `cloudshell:*`.
5. THE `cdcu-developer-role` IAM_Role SHALL allow: S3 read and write on `cdcu-*` buckets, Glue job run and view on `cdcu-*` jobs, Glue connection access, SageMaker processing job execution, and SageMaker notebook read-only access.
6. THE `cdcu-readonly-role` IAM_Role SHALL allow: Athena query execution on the `cdcu-{environment}-workgroup`, S3 read on the Athena results prefix, and QuickSight dashboard read-only access.
7. THE `cdcu-glue-execution-role` IAM_Role SHALL allow: S3 read and write on `cdcu-*` buckets, Glue full CRUD on databases, tables, partitions, crawlers, jobs, and catalog, CloudWatch Logs `CreateLogGroup`, `CreateLogStream`, and `PutLogEvents`, EventBridge full rule and target management, and Secrets_Manager `GetSecretValue`.
8. THE `cdcu-sagemaker-execution-role` IAM_Role SHALL allow: S3 read and write on `cdcu-*` buckets, SageMaker full access for processing, training, model, endpoint, and pipeline operations, CloudWatch Logs `CreateLogGroup`, `CreateLogStream`, and `PutLogEvents`, and Secrets_Manager `GetSecretValue`.
9. THE `cdcu-athena-query-role` IAM_Role SHALL allow: Athena full query execution, S3 read and write on the Athena results prefix, and QuickSight integration actions.
10. WHERE a KMS_Key is configured, THE IAM Terraform_Module SHALL grant all CDCU IAM_Roles limited `kms:Encrypt` and `kms:Decrypt` permissions scoped to the CDCU KMS_Key ARN.
11. THE IAM Terraform_Module SHALL output all IAM_Role ARNs for reference by service Terraform_Modules.

---

### Requirement 9: AWS Secrets Manager Integration

**User Story:** As a Security Engineer, I want all sensitive configuration values stored in Secrets_Manager and referenced at runtime, so that no credentials or secrets are hardcoded in Terraform code or state files.

#### Acceptance Criteria

1. THE Secrets_Manager Terraform_Module SHALL provision a secret for the MySQL source database connection string, named `cdcu/{environment}/mysql-connection`.
2. THE Secrets_Manager Terraform_Module SHALL provision a secret for any additional service credentials required by Glue_Jobs or SageMaker workloads.
3. THE Secrets_Manager Terraform_Module SHALL enable automatic rotation configuration as an input variable, defaulting to disabled, so that rotation can be enabled per Environment.
4. WHERE a KMS_Key is configured, THE Secrets_Manager Terraform_Module SHALL encrypt all secrets using that KMS_Key.
5. THE Glue Terraform_Module SHALL reference the MySQL connection secret from Secrets_Manager using a data source lookup rather than a hardcoded value.
6. THE Terraform_Root SHALL contain no hardcoded credential values in any `.tf` file, `tfvars_File`, or Terraform output.

---

### Requirement 10: CloudWatch Monitoring and Alarms

**User Story:** As a Platform Engineer, I want CloudWatch log groups and alarms provisioned for all CDCU services, so that operational issues are detected and surfaced promptly.

#### Acceptance Criteria

1. THE CloudWatch Terraform_Module SHALL provision log groups for: `/aws/glue/cdcu-{environment}`, `/aws/sagemaker/cdcu-{environment}`, and `/aws/athena/cdcu-{environment}`.
2. THE CloudWatch Terraform_Module SHALL set a log retention period of 90 days on all CDCU log groups.
3. THE CloudWatch Terraform_Module SHALL provision a CloudWatch alarm that triggers when a Glue_Job enters the `FAILED` state, with an evaluation period of 1 and a threshold of 1 failure.
4. THE CloudWatch Terraform_Module SHALL provision a CloudWatch alarm that triggers when SageMaker processing job failures exceed 1 within a 5-minute period.
5. THE CloudWatch Terraform_Module SHALL provision a CloudWatch alarm that triggers when Athena query failures exceed 5 within a 10-minute period.
6. WHERE an SNS topic ARN is provided as an input variable, THE CloudWatch Terraform_Module SHALL configure all alarms to publish notifications to that SNS topic.

---

### Requirement 11: KMS Encryption

**User Story:** As a Security Engineer, I want a customer-managed KMS key provisioned for CDCU, so that data at rest across S3, SageMaker, and Secrets Manager is encrypted with a key I control.

#### Acceptance Criteria

1. THE KMS Terraform_Module SHALL provision one customer-managed KMS_Key per Environment named `cdcu-{environment}-cmk`.
2. THE KMS Terraform_Module SHALL configure the KMS_Key policy to allow key usage only by CDCU IAM_Roles and deny key usage by any principal not in the CDCU IAM_Role list.
3. THE KMS Terraform_Module SHALL enable automatic key rotation on the KMS_Key.
4. THE KMS Terraform_Module SHALL output the KMS_Key ARN and KMS_Key ID for use by S3, SageMaker, and Secrets_Manager Terraform_Modules.
5. THE KMS Terraform_Module SHALL be an optional module, controlled by an `enable_kms` boolean input variable in the Terraform_Root, defaulting to `true` for `prod` and `false` for `pre-prod`.

---

### Requirement 12: Security Group Provisioning

**User Story:** As a Security Engineer, I want service-level security groups provisioned for Glue and SageMaker, so that network access between services is explicitly controlled and auditable.

#### Acceptance Criteria

1. THE Security_Group Terraform_Module SHALL provision a security group for AWS Glue that allows only outbound HTTPS (port 443) to AWS service endpoints and denies all inbound traffic.
2. THE Security_Group Terraform_Module SHALL provision a security group for SageMaker that allows only outbound HTTPS (port 443) to AWS service endpoints and denies all inbound traffic.
3. THE Security_Group Terraform_Module SHALL accept VPC ID as an input variable and SHALL NOT hardcode any VPC ID or subnet ID.
4. THE Security_Group Terraform_Module SHALL output security group IDs for use by the Glue and SageMaker Terraform_Modules.

---

### Requirement 13: Multi-Environment Isolation

**User Story:** As a Platform Engineer, I want each environment (pre-prod, prod) to be fully isolated with its own state, variables, and resource naming, so that changes in pre-prod cannot affect production.

#### Acceptance Criteria

1. THE Terraform_Root SHALL maintain a separate `backend.tf` per Environment pointing to an environment-specific S3 state key and DynamoDB table.
2. THE Terraform_Root SHALL maintain a separate `terraform.tfvars` per Environment containing environment-specific values for all configurable parameters.
3. THE Terraform_Root SHALL apply the `Environment` tag to all resources with the value matching the current Environment name.
4. WHEN Terraform is applied to the `pre-prod` Environment, THE Terraform_Root SHALL provision resources with names prefixed `cdcu-pre-prod-` and SHALL NOT modify resources in the `prod` environment.
5. THE Terraform_Root SHALL define a `locals` block that derives all environment-specific resource names from the `environment` input variable to prevent naming inconsistencies.

---

### Requirement 14: GitHub Repository Structure and CI/CD

**User Story:** As a Platform Engineer, I want the Terraform repository structured for enterprise GitHub usage with CI/CD automation, so that infrastructure changes follow a controlled, auditable promotion workflow.

#### Acceptance Criteria

1. THE CI_CD_Pipeline SHALL include a GitHub Actions workflow that runs `terraform fmt -check`, `terraform validate`, and `terraform plan` on every pull request targeting the `main` branch.
2. THE CI_CD_Pipeline SHALL include a GitHub Actions workflow that runs `terraform apply` only on merge to `main`, scoped to the target Environment determined by the PR branch name or workflow input.
3. THE CI_CD_Pipeline SHALL use OIDC-based AWS authentication via GitHub Actions, referencing the `cdcu-terraform-deployment-role` IAM_Role ARN stored as a GitHub Actions secret, with no long-lived AWS credentials stored in the repository.
4. THE PR_Workflow SHALL require at minimum one peer review approval before a pull request can be merged to `main`.
5. THE Terraform repository SHALL include a `.gitignore` file that excludes `.terraform/`, `*.tfstate`, `*.tfstate.backup`, `*.tfvars` (except example files), and `*.tfplan` files.
6. THE Terraform repository SHALL include a `README.md` at the root level documenting: repository structure, environment setup steps, Terraform execution instructions, AWS CLI and SSO setup, and branching strategy.
7. THE CI_CD_Pipeline SHALL store the `terraform plan` output as a pull request comment for reviewer visibility.

---

### Requirement 15: Documentation and Knowledge Transfer

**User Story:** As a new team member, I want comprehensive documentation covering deployment, operations, and troubleshooting, so that I can onboard and operate the CDCU infrastructure without requiring direct knowledge transfer from the original authors.

#### Acceptance Criteria

1. THE Terraform repository SHALL include a Terraform deployment guide covering: prerequisites, AWS CLI and SSO configuration, backend bootstrap steps, environment initialization, plan and apply execution, and state management.
2. THE Terraform repository SHALL include an IAM role and policy matrix document listing all IAM_Roles, their trust relationships, attached policies, and the AWS services or human principals that assume each role.
3. THE Terraform repository SHALL include a GitHub usage guide covering: repository cloning, branch naming conventions, PR creation, review process, and environment promotion workflow.
4. THE Terraform repository SHALL include an operations support document covering: CloudWatch alarm response procedures, Glue_Job failure remediation steps, SageMaker job failure remediation steps, and Terraform state recovery procedures.
5. THE Terraform repository SHALL include a troubleshooting guide covering: common Terraform errors, AWS permission errors, state lock resolution, and backend connectivity issues.
6. THE Terraform repository SHALL include a production deployment checklist covering: pre-deployment verification steps, deployment execution steps, post-deployment validation steps, and rollback procedures.

---

### Requirement 16: Provider and Version Constraints

**User Story:** As a Platform Engineer, I want Terraform provider versions and the Terraform CLI version pinned, so that infrastructure deployments are reproducible and unaffected by upstream provider changes.

#### Acceptance Criteria

1. THE Terraform_Root SHALL declare a `required_providers` block specifying the `hashicorp/aws` provider with an exact minor version constraint (e.g., `~> 5.0`).
2. THE Terraform_Root SHALL declare a `required_version` constraint specifying the minimum Terraform CLI version (e.g., `>= 1.6.0`).
3. THE Terraform_Root SHALL include a `.terraform.lock.hcl` file committed to the repository to lock provider dependency hashes.
4. THE Terraform_Root SHALL configure the AWS provider with `region = "ap-southeast-1"` and SHALL NOT hardcode any AWS account ID or access key in the provider block.
5. THE Terraform_Root SHALL configure the AWS provider to assume the `cdcu-terraform-deployment-role` IAM_Role using the `assume_role` block, referencing the role ARN from a variable or environment variable.
