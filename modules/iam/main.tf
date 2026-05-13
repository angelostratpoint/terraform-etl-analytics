data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = "ap-southeast-1"
}

resource "aws_iam_policy" "cdcu_deny_sensitive_services" {
  name        = "cdcu-${var.environment}-deny-sensitive-services"
  description = "Explicit deny for sensitive AWS services across all CDCU roles"

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
          "secretsmanager:CreateSecret",
          "secretsmanager:UpdateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:PutSecretValue",
          "iam:PassRole",
          "ec2:CreateSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:ModifyVpc*",
          "cloudformation:*",
          "cloudshell:*",
        ]
        Resource = "*"
      },
      {
        Sid      = "DenyNonSingaporeRegion"
        Effect   = "Deny"
        Action   = "*"
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

resource "aws_iam_role_policy_attachment" "terraform_deployment_deny" {
  role       = aws_iam_role.cdcu_terraform_deployment.name
  policy_arn = aws_iam_policy.cdcu_deny_sensitive_services.arn
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

resource "aws_iam_role_policy_attachment" "glue_deny_sensitive" {
  role       = aws_iam_role.cdcu_glue_execution.name
  policy_arn = aws_iam_policy.cdcu_deny_sensitive_services.arn
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

resource "aws_iam_role_policy_attachment" "sagemaker_deny_sensitive" {
  role       = aws_iam_role.cdcu_sagemaker_execution.name
  policy_arn = aws_iam_policy.cdcu_deny_sensitive_services.arn
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
  description = "QuickSight read-only access to Athena and S3 results"

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
        Sid    = "S3ResultsReadAccess"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::cdcu-*",
          "arn:aws:s3:::cdcu-*/*",
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

resource "aws_iam_role_policy_attachment" "developer_deny_sensitive" {
  role       = aws_iam_role.cdcu_developer.name
  policy_arn = aws_iam_policy.cdcu_deny_sensitive_services.arn
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
