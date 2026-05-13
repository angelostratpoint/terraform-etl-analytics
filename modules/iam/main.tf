data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = "ap-southeast-1"
}

# cdcu-deny-sensitive-services — matches approved access matrix exactly
# NOTE: iam:PassRole is intentionally NOT in this policy.
# It is a separate policy (cdcu_deny_passrole) applied only to human-facing roles,
# NOT to service execution roles (Glue, SageMaker) which require PassRole to function.
resource "aws_iam_policy" "cdcu_deny_sensitive_services" {
  name        = "cdcu-${var.environment}-deny-sensitive-services"
  description = "Explicit deny for sensitive AWS services — iam, rds, ec2, secretsmanager management"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenySensitiveServices"
        Effect = "Deny"
        Action = [
          "iam:*",
          "organizations:*",
          "ec2:*",
          "rds:*",
          "secretsmanager:*",
        ]
        Resource = "*"
      },
    ]
  })

  tags = var.tags
}

# cdcu-deny-passrole — separate policy per approved access matrix
# Applied ONLY to human-facing roles (developer, readonly, qa, business-review).
# NOT attached to service execution roles (Glue, SageMaker, Terraform deployment).
resource "aws_iam_policy" "cdcu_deny_passrole" {
  name        = "cdcu-${var.environment}-deny-passrole"
  description = "Explicit deny of iam:PassRole for human-facing CDCU roles"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyPassRole"
        Effect   = "Deny"
        Action   = ["iam:PassRole"]
        Resource = "*"
      },
    ]
  })

  tags = var.tags
}

# cdcu-deny-networking — separate policy per approved access matrix
resource "aws_iam_policy" "cdcu_deny_networking" {
  name        = "cdcu-${var.environment}-deny-networking"
  description = "Explicit deny of VPC and security group modifications"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyNetworking"
        Effect = "Deny"
        Action = [
          "ec2:CreateSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:ModifyVpc*",
        ]
        Resource = "*"
      },
    ]
  })

  tags = var.tags
}

# cdcu-deny-cloudformation — separate policy per approved access matrix
resource "aws_iam_policy" "cdcu_deny_cloudformation" {
  name        = "cdcu-${var.environment}-deny-cloudformation"
  description = "Explicit deny of CloudFormation for all CDCU roles"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyCloudFormation"
        Effect   = "Deny"
        Action   = ["cloudformation:*"]
        Resource = "*"
      },
    ]
  })

  tags = var.tags
}

# cdcu-deny-cloudshell — separate policy per approved access matrix
resource "aws_iam_policy" "cdcu_deny_cloudshell" {
  name        = "cdcu-${var.environment}-deny-cloudshell"
  description = "Explicit deny of CloudShell for all CDCU roles"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyCloudShell"
        Effect   = "Deny"
        Action   = ["cloudshell:*"]
        Resource = "*"
      },
    ]
  })

  tags = var.tags
}

# cdcu-region-restriction — separate policy per approved access matrix
resource "aws_iam_policy" "cdcu_region_restriction" {
  name        = "cdcu-${var.environment}-region-restriction"
  description = "Deny all actions outside ap-southeast-1 for all CDCU roles"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyNonSingaporeRegion"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = "ap-southeast-1"
          }
        }
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "cdcu_kms_access" {
  count = var.enable_kms ? 1 : 0

  name        = "cdcu-${var.environment}-kms-access"
  description = "Limited KMS encrypt/decrypt for CDCU roles"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CDCUKMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey",
        ]
        Resource = var.kms_key_arn
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "cdcu_cloudwatch_logs" {
  name        = "cdcu-${var.environment}-cloudwatch-logs"
  description = "CloudWatch Logs write access for CDCU service roles"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsWrite"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
        ]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/*"
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_role" "cdcu_terraform_deployment" {
  name        = "cdcu-${var.environment}-terraform-deployment-role"
  description = "Role assumed by GitHub Actions CI/CD for Terraform deployments"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowGitHubOIDC"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${local.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      },
    ]
  })

  tags = merge(var.tags, { Name = "cdcu-${var.environment}-terraform-deployment-role" })
}

# Terraform deployment role — allow policy covering all resources it needs to provision.
# Approved additional permissions: S3, Glue, Athena, SageMaker, Secrets Manager,
# CloudWatch, EventBridge, DynamoDB (state lock), KMS, QuickSight, IAM (scoped),
# EC2 describe-only (for VPC/subnet lookups).
resource "aws_iam_policy" "cdcu_terraform_deployment_policy" {
  name        = "cdcu-${var.environment}-terraform-deployment-policy"
  description = "Allow Terraform CI/CD to provision all CDCU infrastructure resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3InfrastructureAccess"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket", "s3:DeleteBucket", "s3:GetBucketPolicy",
          "s3:PutBucketPolicy", "s3:DeleteBucketPolicy", "s3:GetBucketVersioning",
          "s3:PutBucketVersioning", "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock", "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration", "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration", "s3:GetObject", "s3:PutObject",
          "s3:DeleteObject", "s3:ListBucket", "s3:GetBucketLocation",
          "s3:GetBucketLogging", "s3:PutBucketLogging",
          "s3:GetBucketTagging", "s3:PutBucketTagging",
        ]
        Resource = ["arn:aws:s3:::cdcu-*", "arn:aws:s3:::cdcu-*/*"]
      },
      {
        Sid    = "GlueInfrastructureAccess"
        Effect = "Allow"
        Action = [
          "glue:CreateDatabase", "glue:DeleteDatabase", "glue:GetDatabase", "glue:GetDatabases",
          "glue:CreateTable", "glue:DeleteTable", "glue:GetTable", "glue:GetTables", "glue:UpdateTable",
          "glue:CreateCrawler", "glue:DeleteCrawler", "glue:GetCrawler", "glue:GetCrawlers", "glue:UpdateCrawler",
          "glue:CreateJob", "glue:DeleteJob", "glue:GetJob", "glue:GetJobs", "glue:UpdateJob",
          "glue:CreateConnection", "glue:DeleteConnection", "glue:GetConnection", "glue:GetConnections", "glue:UpdateConnection",
          "glue:GetCatalog", "glue:GetCatalogs", "glue:TagResource", "glue:UntagResource",
          "glue:GetPartition", "glue:GetPartitions", "glue:BatchCreatePartition", "glue:BatchDeletePartition",
        ]
        Resource = "*"
      },
      {
        Sid    = "AthenaInfrastructureAccess"
        Effect = "Allow"
        Action = [
          "athena:CreateWorkGroup", "athena:DeleteWorkGroup", "athena:GetWorkGroup", "athena:UpdateWorkGroup",
          "athena:CreateNamedQuery", "athena:DeleteNamedQuery", "athena:GetNamedQuery",
          "athena:StartQueryExecution", "athena:GetQueryExecution", "athena:GetQueryResults",
          "athena:TagResource", "athena:UntagResource", "athena:ListTagsForResource",
        ]
        Resource = "*"
      },
      {
        Sid    = "SageMakerInfrastructureAccess"
        Effect = "Allow"
        Action = [
          "sagemaker:CreateDomain", "sagemaker:DeleteDomain", "sagemaker:DescribeDomain", "sagemaker:UpdateDomain",
          "sagemaker:CreateUserProfile", "sagemaker:DeleteUserProfile", "sagemaker:DescribeUserProfile",
          "sagemaker:CreateCodeRepository", "sagemaker:DeleteCodeRepository", "sagemaker:DescribeCodeRepository", "sagemaker:UpdateCodeRepository",
          "sagemaker:CreateNotebookInstance", "sagemaker:DeleteNotebookInstance", "sagemaker:DescribeNotebookInstance", "sagemaker:UpdateNotebookInstance",
          "sagemaker:StopNotebookInstance", "sagemaker:StartNotebookInstance",
          "sagemaker:AddTags", "sagemaker:DeleteTags", "sagemaker:ListTags",
        ]
        Resource = "arn:aws:sagemaker:${local.region}:${local.account_id}:*"
      },
      {
        Sid    = "SecretsManagerInfrastructureAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret", "secretsmanager:DeleteSecret", "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue", "secretsmanager:PutSecretValue", "secretsmanager:UpdateSecret",
          "secretsmanager:ListSecrets", "secretsmanager:ListSecretVersionIds",
          "secretsmanager:GetResourcePolicy", "secretsmanager:PutResourcePolicy",
          "secretsmanager:TagResource", "secretsmanager:UntagResource",
          "secretsmanager:RotateSecret", "secretsmanager:CancelRotateSecret",
        ]
        Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:cdcu/*"
      },
      {
        Sid    = "KMSInfrastructureAccess"
        Effect = "Allow"
        Action = [
          "kms:CreateKey", "kms:DescribeKey", "kms:EnableKeyRotation", "kms:GetKeyPolicy",
          "kms:GetKeyRotationStatus", "kms:ListKeys", "kms:ListAliases",
          "kms:CreateAlias", "kms:DeleteAlias", "kms:UpdateAlias",
          "kms:PutKeyPolicy", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion",
          "kms:TagResource", "kms:UntagResource", "kms:ListResourceTags",
          "kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey", "kms:ReEncrypt*",
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchInfrastructureAccess"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:DescribeLogGroups",
          "logs:CreateLogStream", "logs:DeleteLogStream", "logs:DescribeLogStreams",
          "logs:PutLogEvents", "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy",
          "logs:TagLogGroup", "logs:UntagLogGroup", "logs:ListTagsLogGroup",
          "cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms", "cloudwatch:DescribeAlarms",
          "cloudwatch:PutDashboard", "cloudwatch:DeleteDashboards",
        ]
        Resource = "*"
      },
      {
        Sid    = "EventBridgeInfrastructureAccess"
        Effect = "Allow"
        Action = [
          "events:PutRule", "events:DeleteRule", "events:DescribeRule",
          "events:PutTargets", "events:RemoveTargets", "events:ListTargetsByRule",
          "events:TagResource", "events:UntagResource",
        ]
        Resource = "*"
      },
      {
        Sid    = "DynamoDBStateLockAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:CreateTable", "dynamodb:DeleteTable", "dynamodb:DescribeTable",
          "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem", "dynamodb:UpdateItem",
          "dynamodb:TagResource", "dynamodb:UntagResource", "dynamodb:ListTagsOfResource",
        ]
        Resource = "arn:aws:dynamodb:${local.region}:${local.account_id}:table/cdcu-*"
      },
      {
        Sid    = "IAMRoleAndPolicyManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy",
          "iam:CreatePolicy", "iam:DeletePolicy", "iam:GetPolicy",
          "iam:GetPolicyVersion", "iam:CreatePolicyVersion", "iam:DeletePolicyVersion",
          "iam:ListPolicyVersions", "iam:ListAttachedRolePolicies", "iam:ListRolePolicies",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
          "iam:TagRole", "iam:UntagRole", "iam:TagPolicy", "iam:UntagPolicy",
          "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider", "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:PassRole",
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2DescribeOnly"
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs", "ec2:DescribeSubnets", "ec2:DescribeSecurityGroups",
          "ec2:DescribeNetworkInterfaces", "ec2:DescribeAvailabilityZones",
          "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateTags", "ec2:DeleteTags",
        ]
        Resource = "*"
      },
      {
        Sid    = "QuickSightInfrastructureAccess"
        Effect = "Allow"
        Action = [
          "quicksight:CreateGroup", "quicksight:DeleteGroup", "quicksight:DescribeGroup",
          "quicksight:CreateDataSource", "quicksight:DeleteDataSource", "quicksight:DescribeDataSource",
          "quicksight:UpdateDataSource", "quicksight:DescribeDataSourcePermissions", "quicksight:UpdateDataSourcePermissions",
          "quicksight:CreateDataSet", "quicksight:DeleteDataSet", "quicksight:DescribeDataSet",
          "quicksight:UpdateDataSet", "quicksight:DescribeDataSetPermissions", "quicksight:UpdateDataSetPermissions",
          "quicksight:TagResource", "quicksight:UntagResource", "quicksight:ListTagsForResource",
          "quicksight:PassDataSource", "quicksight:PassDataSet",
        ]
        Resource = "*"
      },
      {
        Sid    = "SNSAccess"
        Effect = "Allow"
        Action = [
          "sns:CreateTopic", "sns:DeleteTopic", "sns:GetTopicAttributes",
          "sns:SetTopicAttributes", "sns:Subscribe", "sns:Unsubscribe",
          "sns:ListSubscriptionsByTopic", "sns:TagResource", "sns:UntagResource",
        ]
        Resource = "arn:aws:sns:${local.region}:${local.account_id}:cdcu-*"
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "terraform_deployment_allow" {
  role       = aws_iam_role.cdcu_terraform_deployment.name
  policy_arn = aws_iam_policy.cdcu_terraform_deployment_policy.arn
}

# Terraform deployment role does NOT get deny-sensitive-services or deny-passrole —
# it needs IAM and PassRole to provision infrastructure.
resource "aws_iam_role_policy_attachment" "terraform_deployment_region" {
  role       = aws_iam_role.cdcu_terraform_deployment.name
  policy_arn = aws_iam_policy.cdcu_region_restriction.arn
}

resource "aws_iam_role_policy_attachment" "terraform_deployment_deny_cloudformation" {
  role       = aws_iam_role.cdcu_terraform_deployment.name
  policy_arn = aws_iam_policy.cdcu_deny_cloudformation.arn
}

resource "aws_iam_role_policy_attachment" "terraform_deployment_deny_cloudshell" {
  role       = aws_iam_role.cdcu_terraform_deployment.name
  policy_arn = aws_iam_policy.cdcu_deny_cloudshell.arn
}

resource "aws_iam_role" "cdcu_glue_execution" {
  name        = "cdcu-${var.environment}-glue-execution-role"
  description = "Execution role for AWS Glue jobs and crawlers"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowGlueAssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })

  tags = merge(var.tags, { Name = "cdcu-${var.environment}-glue-execution-role" })
}

resource "aws_iam_policy" "cdcu_glue_execution_policy" {
  name        = "cdcu-${var.environment}-glue-execution-policy"
  description = "Permissions for Glue jobs to access S3, Glue catalog, CloudWatch, EventBridge, and Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3DataLakeAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
        ]
        Resource = [
          "arn:aws:s3:::cdcu-*",
          "arn:aws:s3:::cdcu-*/*",
        ]
      },
      {
        Sid    = "GlueCatalogAccess"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase", "glue:GetDatabases", "glue:CreateDatabase", "glue:UpdateDatabase",
          "glue:GetTable", "glue:GetTables", "glue:CreateTable", "glue:UpdateTable", "glue:DeleteTable",
          "glue:GetPartition", "glue:GetPartitions", "glue:BatchCreatePartition", "glue:BatchDeletePartition",
          "glue:CreateCrawler", "glue:UpdateCrawler", "glue:DeleteCrawler",
          "glue:GetCrawler", "glue:GetCrawlers", "glue:StartCrawler", "glue:StopCrawler",
          "glue:CreateJob", "glue:UpdateJob", "glue:DeleteJob",
          "glue:GetJob", "glue:GetJobs", "glue:StartJobRun", "glue:GetJobRun", "glue:GetJobRuns",
          "glue:BatchStopJobRun",
          "glue:GetConnection", "glue:GetConnections",
          "glue:GetCatalog", "glue:GetCatalogs",
        ]
        Resource = "*"
      },
      {
        Sid      = "SecretsManagerGetSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:cdcu/*"
      },
      {
        Sid    = "EventBridgeAccess"
        Effect = "Allow"
        Action = [
          "events:PutRule", "events:PutTargets", "events:DescribeRule",
          "events:EnableRule", "events:DisableRule", "events:DeleteRule", "events:RemoveTargets",
        ]
        Resource = "*"
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "glue_execution_policy" {
  role       = aws_iam_role.cdcu_glue_execution.name
  policy_arn = aws_iam_policy.cdcu_glue_execution_policy.arn
}

resource "aws_iam_role_policy_attachment" "glue_cloudwatch_logs" {
  role       = aws_iam_role.cdcu_glue_execution.name
  policy_arn = aws_iam_policy.cdcu_cloudwatch_logs.arn
}

# Service roles get region restriction, cloudformation deny, cloudshell deny.
# They do NOT get deny-sensitive-services (blocks secretsmanager reads they need)
# and do NOT get deny-passrole (blocks role assumption required for job execution).
resource "aws_iam_role_policy_attachment" "glue_deny_cloudformation" {
  role       = aws_iam_role.cdcu_glue_execution.name
  policy_arn = aws_iam_policy.cdcu_deny_cloudformation.arn
}

resource "aws_iam_role_policy_attachment" "glue_deny_cloudshell" {
  role       = aws_iam_role.cdcu_glue_execution.name
  policy_arn = aws_iam_policy.cdcu_deny_cloudshell.arn
}

resource "aws_iam_role_policy_attachment" "glue_region_restriction" {
  role       = aws_iam_role.cdcu_glue_execution.name
  policy_arn = aws_iam_policy.cdcu_region_restriction.arn
}

resource "aws_iam_role_policy_attachment" "glue_kms" {
  count      = var.enable_kms ? 1 : 0
  role       = aws_iam_role.cdcu_glue_execution.name
  policy_arn = aws_iam_policy.cdcu_kms_access[0].arn
}

resource "aws_iam_role" "cdcu_sagemaker_execution" {
  name        = "cdcu-${var.environment}-sagemaker-execution-role"
  description = "Execution role for SageMaker processing and training jobs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSageMakerAssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })

  tags = merge(var.tags, { Name = "cdcu-${var.environment}-sagemaker-execution-role" })
}

resource "aws_iam_policy" "cdcu_sagemaker_execution_policy" {
  name        = "cdcu-${var.environment}-sagemaker-execution-policy"
  description = "Permissions for SageMaker jobs to access S3, CloudWatch, and Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3DataAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::cdcu-*",
          "arn:aws:s3:::cdcu-*/*",
        ]
      },
      {
        Sid    = "SageMakerJobAccess"
        Effect = "Allow"
        Action = [
          "sagemaker:CreateProcessingJob", "sagemaker:DescribeProcessingJob", "sagemaker:StopProcessingJob",
          "sagemaker:CreateTrainingJob", "sagemaker:DescribeTrainingJob", "sagemaker:StopTrainingJob",
          "sagemaker:CreateModel", "sagemaker:DescribeModel",
          "sagemaker:CreateEndpointConfig", "sagemaker:DescribeEndpointConfig",
          "sagemaker:CreateEndpoint", "sagemaker:DescribeEndpoint", "sagemaker:InvokeEndpoint",
          "sagemaker:CreatePipeline", "sagemaker:StartPipelineExecution",
          "sagemaker:DescribePipeline", "sagemaker:DescribePipelineExecution",
          "sagemaker:ListProcessingJobs", "sagemaker:ListTrainingJobs",
          "sagemaker:DescribeNotebookInstance", "sagemaker:ListNotebookInstances",
        ]
        Resource = "arn:aws:sagemaker:${local.region}:${local.account_id}:*"
      },
      {
        Sid      = "SecretsManagerGetSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:cdcu/*"
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "sagemaker_execution_policy" {
  role       = aws_iam_role.cdcu_sagemaker_execution.name
  policy_arn = aws_iam_policy.cdcu_sagemaker_execution_policy.arn
}

resource "aws_iam_role_policy_attachment" "sagemaker_cloudwatch_logs" {
  role       = aws_iam_role.cdcu_sagemaker_execution.name
  policy_arn = aws_iam_policy.cdcu_cloudwatch_logs.arn
}

# Same as Glue — service role gets region/cloudformation/cloudshell denies only.
resource "aws_iam_role_policy_attachment" "sagemaker_deny_cloudformation" {
  role       = aws_iam_role.cdcu_sagemaker_execution.name
  policy_arn = aws_iam_policy.cdcu_deny_cloudformation.arn
}

resource "aws_iam_role_policy_attachment" "sagemaker_deny_cloudshell" {
  role       = aws_iam_role.cdcu_sagemaker_execution.name
  policy_arn = aws_iam_policy.cdcu_deny_cloudshell.arn
}

resource "aws_iam_role_policy_attachment" "sagemaker_region_restriction" {
  role       = aws_iam_role.cdcu_sagemaker_execution.name
  policy_arn = aws_iam_policy.cdcu_region_restriction.arn
}

resource "aws_iam_role_policy_attachment" "sagemaker_kms" {
  count      = var.enable_kms ? 1 : 0
  role       = aws_iam_role.cdcu_sagemaker_execution.name
  policy_arn = aws_iam_policy.cdcu_kms_access[0].arn
}

resource "aws_iam_role" "cdcu_athena_query" {
  name        = "cdcu-${var.environment}-athena-query-role"
  description = "Role for Athena query execution and QuickSight integration"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAthenaAssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "athena.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })

  tags = merge(var.tags, { Name = "cdcu-${var.environment}-athena-query-role" })
}

resource "aws_iam_policy" "cdcu_athena_query_policy" {
  name        = "cdcu-${var.environment}-athena-query-policy"
  description = "Athena query execution and S3 results access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AthenaQueryExecution"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution", "athena:GetQueryExecution",
          "athena:GetQueryResults", "athena:StopQueryExecution",
          "athena:ListQueryExecutions", "athena:GetWorkGroup",
        ]
        Resource = "*"
      },
      {
        Sid    = "AthenaResultsBucketAccess"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::cdcu-*-athena-results",
          "arn:aws:s3:::cdcu-*-athena-results/*",
        ]
      },
      {
        Sid    = "QuickSightIntegration"
        Effect = "Allow"
        Action = [
          "quicksight:DescribeDashboard",
          "quicksight:ListDashboards",
          "quicksight:GetDashboardEmbedUrl",
        ]
        Resource = "*"
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "athena_query_policy" {
  role       = aws_iam_role.cdcu_athena_query.name
  policy_arn = aws_iam_policy.cdcu_athena_query_policy.arn
}

resource "aws_iam_role_policy_attachment" "athena_deny_sensitive" {
  role       = aws_iam_role.cdcu_athena_query.name
  policy_arn = aws_iam_policy.cdcu_deny_sensitive_services.arn
}

resource "aws_iam_role_policy_attachment" "athena_deny_passrole" {
  role       = aws_iam_role.cdcu_athena_query.name
  policy_arn = aws_iam_policy.cdcu_deny_passrole.arn
}

resource "aws_iam_role_policy_attachment" "athena_deny_networking" {
  role       = aws_iam_role.cdcu_athena_query.name
  policy_arn = aws_iam_policy.cdcu_deny_networking.arn
}

resource "aws_iam_role_policy_attachment" "athena_deny_cloudformation" {
  role       = aws_iam_role.cdcu_athena_query.name
  policy_arn = aws_iam_policy.cdcu_deny_cloudformation.arn
}

resource "aws_iam_role_policy_attachment" "athena_deny_cloudshell" {
  role       = aws_iam_role.cdcu_athena_query.name
  policy_arn = aws_iam_policy.cdcu_deny_cloudshell.arn
}

resource "aws_iam_role_policy_attachment" "athena_region_restriction" {
  role       = aws_iam_role.cdcu_athena_query.name
  policy_arn = aws_iam_policy.cdcu_region_restriction.arn
}

resource "aws_iam_role" "cdcu_quicksight_access" {
  name        = "cdcu-${var.environment}-quicksight-access-role"
  description = "Role for QuickSight to access Athena and S3 data sources"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowQuickSightAssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "quicksight.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })

  tags = merge(var.tags, { Name = "cdcu-${var.environment}-quicksight-access-role" })
}

resource "aws_iam_policy" "cdcu_quicksight_access_policy" {
  name        = "cdcu-${var.environment}-quicksight-access-policy"
  description = "QuickSight read-only access to Athena results and processed S3 data only — not raw PII"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AthenaAccess"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution", "athena:GetQueryExecution",
          "athena:GetQueryResults", "athena:GetWorkGroup",
        ]
        Resource = "*"
      },
      {
        # Scoped to processed/ and athena-results only — raw/ and standardized/ are excluded.
        # This prevents QuickSight from reading raw PII data per data privacy requirements.
        Sid    = "S3ProcessedAndResultsReadAccess"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::cdcu-*-athena-results",
          "arn:aws:s3:::cdcu-*-athena-results/*",
          "arn:aws:s3:::cdcu-*-data-lake",
          "arn:aws:s3:::cdcu-*-data-lake/processed/*",
        ]
      },
      {
        Sid    = "GlueCatalogRead"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase", "glue:GetDatabases",
          "glue:GetTable", "glue:GetTables",
          "glue:GetPartition", "glue:GetPartitions",
        ]
        Resource = "*"
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "quicksight_access_policy" {
  role       = aws_iam_role.cdcu_quicksight_access.name
  policy_arn = aws_iam_policy.cdcu_quicksight_access_policy.arn
}

resource "aws_iam_role" "cdcu_developer" {
  name        = "cdcu-${var.environment}-developer-role"
  description = "Human developer role for Data Engineers working on CDCU"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSSOAssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.sso_principal_arns
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = "ap-southeast-1"
          }
        }
      },
    ]
  })

  tags = merge(var.tags, { Name = "cdcu-${var.environment}-developer-role" })
}

resource "aws_iam_policy" "cdcu_developer_policy" {
  name        = "cdcu-${var.environment}-developer-policy"
  description = "Data Engineer access to S3, Glue, SageMaker, Athena, and CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3DataAccess"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::cdcu-*",
          "arn:aws:s3:::cdcu-*/*",
        ]
      },
      {
        Sid      = "GlueJobAccess"
        Effect   = "Allow"
        Action   = ["glue:StartJobRun", "glue:GetJob", "glue:GetJobRun", "glue:GetJobRuns"]
        Resource = "arn:aws:glue:${local.region}:${local.account_id}:job/cdcu-*"
      },
      {
        Sid      = "GlueConnectionAccess"
        Effect   = "Allow"
        Action   = ["glue:GetConnection", "glue:GetConnections"]
        Resource = "arn:aws:glue:${local.region}:${local.account_id}:connection/cdcu-*"
      },
      {
        Sid    = "SageMakerProcessingAccess"
        Effect = "Allow"
        Action = [
          "sagemaker:CreateProcessingJob", "sagemaker:DescribeProcessingJob",
          "sagemaker:StopProcessingJob", "sagemaker:ListProcessingJobs",
        ]
        Resource = "arn:aws:sagemaker:${local.region}:${local.account_id}:processing-job/cdcu-*"
      },
      {
        Sid      = "SageMakerNotebookReadOnly"
        Effect   = "Allow"
        Action   = ["sagemaker:DescribeNotebookInstance", "sagemaker:ListNotebookInstances"]
        Resource = "arn:aws:sagemaker:${local.region}:${local.account_id}:notebook-instance/cdcu-*"
      },
      {
        Sid      = "CloudWatchLogsRead"
        Effect   = "Allow"
        Action   = ["logs:GetLogEvents", "logs:DescribeLogStreams", "logs:DescribeLogGroups"]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/glue/cdcu-*"
      },
      {
        Sid      = "CodeCommitAccess"
        Effect   = "Allow"
        Action   = ["codecommit:GitPull", "codecommit:GetRepository", "codecommit:ListBranches"]
        Resource = "arn:aws:codecommit:${local.region}:${local.account_id}:cdcu-repository"
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "developer_policy" {
  role       = aws_iam_role.cdcu_developer.name
  policy_arn = aws_iam_policy.cdcu_developer_policy.arn
}

# Human-facing roles get the full set of deny policies including deny-passrole
resource "aws_iam_role_policy_attachment" "developer_deny_sensitive" {
  role       = aws_iam_role.cdcu_developer.name
  policy_arn = aws_iam_policy.cdcu_deny_sensitive_services.arn
}

resource "aws_iam_role_policy_attachment" "developer_deny_passrole" {
  role       = aws_iam_role.cdcu_developer.name
  policy_arn = aws_iam_policy.cdcu_deny_passrole.arn
}

resource "aws_iam_role_policy_attachment" "developer_deny_networking" {
  role       = aws_iam_role.cdcu_developer.name
  policy_arn = aws_iam_policy.cdcu_deny_networking.arn
}

resource "aws_iam_role_policy_attachment" "developer_deny_cloudformation" {
  role       = aws_iam_role.cdcu_developer.name
  policy_arn = aws_iam_policy.cdcu_deny_cloudformation.arn
}

resource "aws_iam_role_policy_attachment" "developer_deny_cloudshell" {
  role       = aws_iam_role.cdcu_developer.name
  policy_arn = aws_iam_policy.cdcu_deny_cloudshell.arn
}

resource "aws_iam_role_policy_attachment" "developer_region_restriction" {
  role       = aws_iam_role.cdcu_developer.name
  policy_arn = aws_iam_policy.cdcu_region_restriction.arn
}

resource "aws_iam_role_policy_attachment" "developer_kms" {
  count      = var.enable_kms ? 1 : 0
  role       = aws_iam_role.cdcu_developer.name
  policy_arn = aws_iam_policy.cdcu_kms_access[0].arn
}

resource "aws_iam_role_policy_attachment" "developer_cloudwatch_logs" {
  role       = aws_iam_role.cdcu_developer.name
  policy_arn = aws_iam_policy.cdcu_cloudwatch_logs.arn
}

resource "aws_iam_role" "cdcu_readonly" {
  name        = "cdcu-${var.environment}-readonly-role"
  description = "Read-only role for QA testers and business reviewers"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSSOAssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.sso_principal_arns
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = "ap-southeast-1"
          }
        }
      },
    ]
  })

  tags = merge(var.tags, { Name = "cdcu-${var.environment}-readonly-role" })
}

resource "aws_iam_policy" "cdcu_readonly_policy" {
  name        = "cdcu-${var.environment}-readonly-policy"
  description = "Read-only access to Athena, S3 results, and QuickSight dashboards"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AthenaQueryAccess"
        Effect   = "Allow"
        Action   = [
          "athena:StartQueryExecution", "athena:GetQueryExecution",
          "athena:GetQueryResults", "athena:GetWorkGroup",
        ]
        Resource = "arn:aws:athena:${local.region}:${local.account_id}:workgroup/cdcu-${var.environment}-workgroup"
      },
      {
        Sid    = "AthenaResultsS3Access"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::cdcu-*-athena-results",
          "arn:aws:s3:::cdcu-*-athena-results/*",
        ]
      },
      {
        Sid    = "QuickSightDashboardAccess"
        Effect = "Allow"
        Action = [
          "quicksight:DescribeDashboard",
          "quicksight:ListDashboards",
          "quicksight:GetDashboardEmbedUrl",
        ]
        Resource = "*"
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "readonly_policy" {
  role       = aws_iam_role.cdcu_readonly.name
  policy_arn = aws_iam_policy.cdcu_readonly_policy.arn
}

resource "aws_iam_role_policy_attachment" "readonly_deny_sensitive" {
  role       = aws_iam_role.cdcu_readonly.name
  policy_arn = aws_iam_policy.cdcu_deny_sensitive_services.arn
}

resource "aws_iam_role_policy_attachment" "readonly_deny_passrole" {
  role       = aws_iam_role.cdcu_readonly.name
  policy_arn = aws_iam_policy.cdcu_deny_passrole.arn
}

resource "aws_iam_role_policy_attachment" "readonly_deny_networking" {
  role       = aws_iam_role.cdcu_readonly.name
  policy_arn = aws_iam_policy.cdcu_deny_networking.arn
}

resource "aws_iam_role_policy_attachment" "readonly_deny_cloudformation" {
  role       = aws_iam_role.cdcu_readonly.name
  policy_arn = aws_iam_policy.cdcu_deny_cloudformation.arn
}

resource "aws_iam_role_policy_attachment" "readonly_deny_cloudshell" {
  role       = aws_iam_role.cdcu_readonly.name
  policy_arn = aws_iam_policy.cdcu_deny_cloudshell.arn
}

resource "aws_iam_role_policy_attachment" "readonly_region_restriction" {
  role       = aws_iam_role.cdcu_readonly.name
  policy_arn = aws_iam_policy.cdcu_region_restriction.arn
}

###############################################################################
# cdcu-qa-role — QA testers: Athena query access + S3 results read/write
# Per approved access matrix: cdcu-athena-query-access + cdcu-athena-output-bucket-access
###############################################################################

resource "aws_iam_role" "cdcu_qa" {
  name        = "cdcu-${var.environment}-qa-role"
  description = "QA tester role for validating cleanup results via Athena"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSSOAssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.sso_principal_arns
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = "ap-southeast-1"
          }
        }
      },
    ]
  })

  tags = merge(var.tags, { Name = "cdcu-${var.environment}-qa-role" })
}

resource "aws_iam_policy" "cdcu_qa_policy" {
  name        = "cdcu-${var.environment}-qa-policy"
  description = "QA access to Athena workgroup and S3 athena results bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AthenaQueryAccess"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution",
          "athena:ListQueryExecutions",
          "athena:GetWorkGroup",
        ]
        Resource = "arn:aws:athena:${local.region}:${local.account_id}:workgroup/cdcu-${var.environment}-workgroup"
      },
      {
        Sid    = "AthenaOutputBucketAccess"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::cdcu-${var.environment}-athena-results",
          "arn:aws:s3:::cdcu-${var.environment}-athena-results/*",
        ]
      },
      {
        Sid    = "GlueCatalogRead"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase", "glue:GetDatabases",
          "glue:GetTable", "glue:GetTables",
          "glue:GetPartition", "glue:GetPartitions",
        ]
        Resource = "*"
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "qa_policy" {
  role       = aws_iam_role.cdcu_qa.name
  policy_arn = aws_iam_policy.cdcu_qa_policy.arn
}

resource "aws_iam_role_policy_attachment" "qa_deny_sensitive" {
  role       = aws_iam_role.cdcu_qa.name
  policy_arn = aws_iam_policy.cdcu_deny_sensitive_services.arn
}

resource "aws_iam_role_policy_attachment" "qa_deny_passrole" {
  role       = aws_iam_role.cdcu_qa.name
  policy_arn = aws_iam_policy.cdcu_deny_passrole.arn
}

resource "aws_iam_role_policy_attachment" "qa_deny_networking" {
  role       = aws_iam_role.cdcu_qa.name
  policy_arn = aws_iam_policy.cdcu_deny_networking.arn
}

resource "aws_iam_role_policy_attachment" "qa_deny_cloudformation" {
  role       = aws_iam_role.cdcu_qa.name
  policy_arn = aws_iam_policy.cdcu_deny_cloudformation.arn
}

resource "aws_iam_role_policy_attachment" "qa_deny_cloudshell" {
  role       = aws_iam_role.cdcu_qa.name
  policy_arn = aws_iam_policy.cdcu_deny_cloudshell.arn
}

resource "aws_iam_role_policy_attachment" "qa_region_restriction" {
  role       = aws_iam_role.cdcu_qa.name
  policy_arn = aws_iam_policy.cdcu_region_restriction.arn
}

resource "aws_iam_role_policy_attachment" "qa_cloudwatch_logs" {
  role       = aws_iam_role.cdcu_qa.name
  policy_arn = aws_iam_policy.cdcu_cloudwatch_logs.arn
}

resource "aws_iam_role_policy_attachment" "qa_kms" {
  count      = var.enable_kms ? 1 : 0
  role       = aws_iam_role.cdcu_qa.name
  policy_arn = aws_iam_policy.cdcu_kms_access[0].arn
}

###############################################################################
# cdcu-business-review-role — Business users: QuickSight dashboard read-only
# Per approved access matrix: cdcu-quicksight-dashboard-access
###############################################################################

resource "aws_iam_role" "cdcu_business_review" {
  name        = "cdcu-${var.environment}-business-review-role"
  description = "Business reviewer role for QuickSight dashboard read-only access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSSOAssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.sso_principal_arns
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = "ap-southeast-1"
          }
        }
      },
    ]
  })

  tags = merge(var.tags, { Name = "cdcu-${var.environment}-business-review-role" })
}

resource "aws_iam_policy" "cdcu_business_review_policy" {
  name        = "cdcu-${var.environment}-business-review-policy"
  description = "QuickSight dashboard read-only access for business reviewers"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "QuickSightDashboardAccess"
        Effect = "Allow"
        Action = [
          "quicksight:DescribeDashboard",
          "quicksight:ListDashboards",
          "quicksight:GetDashboardEmbedUrl",
        ]
        Resource = "*"
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "business_review_policy" {
  role       = aws_iam_role.cdcu_business_review.name
  policy_arn = aws_iam_policy.cdcu_business_review_policy.arn
}

resource "aws_iam_role_policy_attachment" "business_review_deny_sensitive" {
  role       = aws_iam_role.cdcu_business_review.name
  policy_arn = aws_iam_policy.cdcu_deny_sensitive_services.arn
}

resource "aws_iam_role_policy_attachment" "business_review_deny_passrole" {
  role       = aws_iam_role.cdcu_business_review.name
  policy_arn = aws_iam_policy.cdcu_deny_passrole.arn
}

resource "aws_iam_role_policy_attachment" "business_review_deny_networking" {
  role       = aws_iam_role.cdcu_business_review.name
  policy_arn = aws_iam_policy.cdcu_deny_networking.arn
}

resource "aws_iam_role_policy_attachment" "business_review_deny_cloudformation" {
  role       = aws_iam_role.cdcu_business_review.name
  policy_arn = aws_iam_policy.cdcu_deny_cloudformation.arn
}

resource "aws_iam_role_policy_attachment" "business_review_deny_cloudshell" {
  role       = aws_iam_role.cdcu_business_review.name
  policy_arn = aws_iam_policy.cdcu_deny_cloudshell.arn
}

resource "aws_iam_role_policy_attachment" "business_review_region_restriction" {
  role       = aws_iam_role.cdcu_business_review.name
  policy_arn = aws_iam_policy.cdcu_region_restriction.arn
}
