data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id    = data.aws_caller_identity.current.account_id
  region        = data.aws_region.current.name
  env           = var.environment
  secret_prefix = "cdcu/${local.env}/"
}

###############################################################################
# Shared Deny Policy
###############################################################################

resource "aws_iam_policy" "deny_sensitive" {
  name        = "ST-CDCU-${local.env}-DenySensitiveServices"
  description = "Denies sensitive service actions outside Stratpoint scope"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenySensitiveServices"
        Effect = "Deny"
        Action = [
          "iam:*",
          "organizations:*",
          "rds:*",
          "secretsmanager:CreateSecret",
          "secretsmanager:UpdateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:PutSecretValue",
          "cloudformation:*",
          "cloudshell:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyOutsideRegion"
        Effect = "Deny"
        NotAction = [
          "iam:*",
          "sts:*",
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = "ap-southeast-1"
          }
        }
      }
    ]
  })

  tags = var.tags
}

###############################################################################
# ST-CDCU-GlueExecutionRole
###############################################################################

resource "aws_iam_role" "glue_execution" {
  name        = "ST-CDCU-${local.env}-GlueExecutionRole"
  description = "Execution role for CDCU Glue ETL jobs and crawlers"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "ST-CDCU-${local.env}-GlueExecutionRole" })
}

resource "aws_iam_policy" "glue_s3" {
  name = "ST-CDCU-${local.env}-GlueS3Access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "S3DataLakeAccess"
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketVersioning",
        "s3:PutBucketVersioning"
      ]
      Resource = [
        var.data_lake_bucket_arn,
        "${var.data_lake_bucket_arn}/*"
      ]
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy" "glue_etl" {
  name = "ST-CDCU-${local.env}-GlueCrawlerAndETL"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GlueCrawlerAndETL"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase", "glue:GetDatabases", "glue:CreateDatabase", "glue:UpdateDatabase",
          "glue:GetTable", "glue:GetTables", "glue:CreateTable", "glue:UpdateTable", "glue:DeleteTable",
          "glue:GetPartition", "glue:GetPartitions", "glue:BatchCreatePartition", "glue:BatchDeletePartition",
          "glue:CreateCrawler", "glue:UpdateCrawler", "glue:DeleteCrawler",
          "glue:GetCrawler", "glue:GetCrawlers", "glue:StartCrawler", "glue:StopCrawler",
          "glue:CreateJob", "glue:UpdateJob", "glue:DeleteJob",
          "glue:GetJob", "glue:GetJobs", "glue:StartJobRun",
          "glue:GetJobRun", "glue:GetJobRuns", "glue:BatchStopJobRun",
          "glue:GetConnection", "glue:CreateConnection", "glue:UpdateConnection",
          "glue:DeleteConnection", "glue:GetConnections",
          "glue:GetSecurityConfiguration",
          "glue:BatchGetPartition", "glue:BatchCreatePartition", "glue:BatchDeletePartition"
        ]
        Resource = "*"
      },
      {
        Sid    = "GlueVPCPlacement"
        Effect = "Allow"
        Action = [
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcEndpoints",
          "ec2:DescribeRouteTables",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "glue_secrets" {
  name = "ST-CDCU-${local.env}-GlueSecretsRead"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "SecretsManagerRead"
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${local.secret_prefix}*"
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy" "glue_cloudwatch" {
  name = "ST-CDCU-${local.env}-GlueCloudWatchLogs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "CloudWatchLogsGlue"
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:GetLogEvents"
      ]
      Resource = [
        "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/glue/*",
        "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws-glue/*"
      ]
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "glue_s3" {
  role       = aws_iam_role.glue_execution.name
  policy_arn = aws_iam_policy.glue_s3.arn
}

resource "aws_iam_role_policy_attachment" "glue_etl" {
  role       = aws_iam_role.glue_execution.name
  policy_arn = aws_iam_policy.glue_etl.arn
}

resource "aws_iam_role_policy_attachment" "glue_secrets" {
  role       = aws_iam_role.glue_execution.name
  policy_arn = aws_iam_policy.glue_secrets.arn
}

resource "aws_iam_role_policy_attachment" "glue_cloudwatch" {
  role       = aws_iam_role.glue_execution.name
  policy_arn = aws_iam_policy.glue_cloudwatch.arn
}

resource "aws_iam_role_policy_attachment" "glue_deny" {
  role       = aws_iam_role.glue_execution.name
  policy_arn = aws_iam_policy.deny_sensitive.arn
}

###############################################################################
# ST-CDCU-SageMakerExecutionRole
###############################################################################

resource "aws_iam_role" "sagemaker_execution" {
  name        = "ST-CDCU-${local.env}-SageMakerExecutionRole"
  description = "Execution role for CDCU SageMaker Studio, notebooks, and jobs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sagemaker.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "ST-CDCU-${local.env}-SageMakerExecutionRole" })
}

resource "aws_iam_policy" "sagemaker_access" {
  name = "ST-CDCU-${local.env}-SageMakerAccess"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SageMakerAccess"
        Effect = "Allow"
        Action = [
          "sagemaker:CreateProcessingJob", "sagemaker:DescribeProcessingJob",
          "sagemaker:StopProcessingJob", "sagemaker:ListProcessingJobs",
          "sagemaker:CreateTrainingJob", "sagemaker:DescribeTrainingJob",
          "sagemaker:StopTrainingJob", "sagemaker:ListTrainingJobs",
          "sagemaker:CreateModel", "sagemaker:DescribeModel",
          "sagemaker:CreateEndpointConfig", "sagemaker:DescribeEndpointConfig",
          "sagemaker:CreateEndpoint", "sagemaker:DescribeEndpoint", "sagemaker:InvokeEndpoint",
          "sagemaker:CreatePipeline", "sagemaker:StartPipelineExecution",
          "sagemaker:DescribePipeline", "sagemaker:DescribePipelineExecution",
          "sagemaker:ListSpaces", "sagemaker:DescribeSpace",
          "sagemaker:ListApps", "sagemaker:DescribeApp",
          "sagemaker:CreateApp", "sagemaker:DeleteApp",
          "sagemaker:ListDomains", "sagemaker:DescribeDomain",
          "sagemaker:ListUserProfiles", "sagemaker:DescribeUserProfile",
          "sagemaker:CreatePresignedDomainUrl",
          "sagemaker:AddTags", "sagemaker:ListTags", "sagemaker:DeleteTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "SageMakerPassRole"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = "arn:aws:iam::${local.account_id}:role/ST-CDCU-${local.env}-SageMakerExecutionRole"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "sagemaker.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "sagemaker_s3" {
  name = "ST-CDCU-${local.env}-SageMakerS3Access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "S3DataLakeAccess"
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ]
      Resource = [
        var.data_lake_bucket_arn,
        "${var.data_lake_bucket_arn}/*"
      ]
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy" "sagemaker_cloudwatch" {
  name = "ST-CDCU-${local.env}-SageMakerCloudWatchLogs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "CloudWatchLogsSageMaker"
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:GetLogEvents"
      ]
      Resource = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/sagemaker/*"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "sagemaker_access" {
  role       = aws_iam_role.sagemaker_execution.name
  policy_arn = aws_iam_policy.sagemaker_access.arn
}

resource "aws_iam_role_policy_attachment" "sagemaker_s3" {
  role       = aws_iam_role.sagemaker_execution.name
  policy_arn = aws_iam_policy.sagemaker_s3.arn
}

resource "aws_iam_role_policy_attachment" "sagemaker_cloudwatch" {
  role       = aws_iam_role.sagemaker_execution.name
  policy_arn = aws_iam_policy.sagemaker_cloudwatch.arn
}

resource "aws_iam_role_policy_attachment" "sagemaker_deny" {
  role       = aws_iam_role.sagemaker_execution.name
  policy_arn = aws_iam_policy.deny_sensitive.arn
}

###############################################################################
# ST-CDCU-AthenaQueryRole
###############################################################################

resource "aws_iam_role" "athena_query" {
  name        = "ST-CDCU-${local.env}-AthenaQueryRole"
  description = "Role for QuickSight to query Athena and browse Glue Data Catalog"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "quicksight.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "ST-CDCU-${local.env}-AthenaQueryRole" })
}

resource "aws_iam_policy" "athena_access" {
  name = "ST-CDCU-${local.env}-AthenaAccess"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AthenaAccess"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution",
          "athena:ListQueryExecutions",
          "athena:GetWorkGroup",
          "athena:ListWorkGroups"
        ]
        Resource = "arn:aws:athena:${local.region}:${local.account_id}:workgroup/${var.athena_workgroup_name}"
      },
      {
        Sid    = "AthenaResultsAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.athena_results_bucket_arn,
          "${var.athena_results_bucket_arn}/*"
        ]
      },
      {
        Sid    = "AthenaGlueCatalogAccess"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "athena_access" {
  role       = aws_iam_role.athena_query.name
  policy_arn = aws_iam_policy.athena_access.arn
}

resource "aws_iam_role_policy_attachment" "athena_deny" {
  role       = aws_iam_role.athena_query.name
  policy_arn = aws_iam_policy.deny_sensitive.arn
}

###############################################################################
# ST-CDCU-CloudEngineering Group
###############################################################################

resource "aws_iam_group" "cloud_engineering" {
  name = "ST-CDCU-${local.env}-CloudEngineering"
}

resource "aws_iam_policy" "ce_dynamodb" {
  name = "ST-CDCU-${local.env}-DynamoDBStateLock"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DynamoDBStateLockAccess"
      Effect = "Allow"
      Action = [
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:UpdateItem"
      ]
      Resource = "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${var.terraform_lock_table_name}"
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy" "ce_eventbridge" {
  name = "ST-CDCU-${local.env}-EventBridgeAccess"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "EventBridgeAccess"
      Effect = "Allow"
      Action = [
        "events:PutRule",
        "events:PutTargets",
        "events:DescribeRule",
        "events:EnableRule",
        "events:DisableRule",
        "events:DeleteRule",
        "events:RemoveTargets",
        "events:ListRules",
        "events:ListTargetsByRule"
      ]
      Resource = "arn:aws:events:${local.region}:${local.account_id}:rule/*"
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy" "ce_amazon_q" {
  name = "ST-CDCU-${local.env}-AmazonQDeveloperAccess"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AmazonQDeveloperAccess"
      Effect = "Allow"
      Action = [
        "q:SendMessage",
        "q:StartConversation",
        "q:GetConversation",
        "q:ListConversations",
        "q:DeleteConversation"
      ]
      Resource = "*"
    }]
  })

  tags = var.tags
}

resource "aws_iam_group_policy_attachment" "ce_glue_s3" {
  group      = aws_iam_group.cloud_engineering.name
  policy_arn = aws_iam_policy.glue_s3.arn
}

resource "aws_iam_group_policy_attachment" "ce_glue_etl" {
  group      = aws_iam_group.cloud_engineering.name
  policy_arn = aws_iam_policy.glue_etl.arn
}

resource "aws_iam_group_policy_attachment" "ce_glue_secrets" {
  group      = aws_iam_group.cloud_engineering.name
  policy_arn = aws_iam_policy.glue_secrets.arn
}

# Combined CloudWatch policy for the group — keeps CE under the 10-policy group limit. — keeps CE under the 10-policy group limit.
# Execution roles (Glue, SageMaker) keep their individual cloudwatch policies.
resource "aws_iam_policy" "ce_cloudwatch_combined" {
  name = "ST-CDCU-${local.env}-CECloudWatchLogsAccess"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "CloudWatchLogsAllCDCU"
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:GetLogEvents"
      ]
      Resource = [
        "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/glue/*",
        "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/sagemaker/*"
      ]
    }]
  })

  tags = var.tags
}

# CloudEngineering group — exactly 10 attachments (AWS hard limit)
# 1. GlueS3Access
# 2. GlueCrawlerAndETL
# 3. GlueSecretsRead
# 4. CECloudWatchLogsAccess (combined Glue + SageMaker)
# 5. SageMakerAccess
# 6. SageMakerS3Access
# 7. AthenaAccess
# 8. DynamoDBStateLock
# 9. EventBridgeAccess
# 10. DenySensitiveServices
# NOTE: AmazonQDeveloperAccess is NOT attached to the group — grant individually per user if needed.
resource "aws_iam_group_policy_attachment" "ce_cloudwatch_combined" {
  group      = aws_iam_group.cloud_engineering.name
  policy_arn = aws_iam_policy.ce_cloudwatch_combined.arn
}

resource "aws_iam_group_policy_attachment" "ce_sagemaker" {
  group      = aws_iam_group.cloud_engineering.name
  policy_arn = aws_iam_policy.sagemaker_access.arn
}

resource "aws_iam_group_policy_attachment" "ce_sagemaker_s3" {
  group      = aws_iam_group.cloud_engineering.name
  policy_arn = aws_iam_policy.sagemaker_s3.arn
}

resource "aws_iam_group_policy_attachment" "ce_athena" {
  group      = aws_iam_group.cloud_engineering.name
  policy_arn = aws_iam_policy.athena_access.arn
}

resource "aws_iam_group_policy_attachment" "ce_dynamodb" {
  group      = aws_iam_group.cloud_engineering.name
  policy_arn = aws_iam_policy.ce_dynamodb.arn
}

resource "aws_iam_group_policy_attachment" "ce_eventbridge" {
  group      = aws_iam_group.cloud_engineering.name
  policy_arn = aws_iam_policy.ce_eventbridge.arn
}

resource "aws_iam_group_policy_attachment" "ce_deny" {
  group      = aws_iam_group.cloud_engineering.name
  policy_arn = aws_iam_policy.deny_sensitive.arn
}

###############################################################################
# ST-CDCU-DataEngineering Group
###############################################################################

resource "aws_iam_group" "data_engineering" {
  name = "ST-CDCU-${local.env}-DataEngineering"
}

resource "aws_iam_policy" "de_secrets" {
  name = "ST-CDCU-${local.env}-DESecretsManagerRead"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "SecretsManagerReadAccess"
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecrets",
        "secretsmanager:ListSecretVersionIds",
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:BatchGetSecretValue"
      ]
      Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${local.secret_prefix}*"
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy" "de_cloudwatch" {
  name = "ST-CDCU-${local.env}-DECloudWatchLogsRead"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "CloudWatchLogsRead"
      Effect = "Allow"
      Action = [
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:GetLogEvents"
      ]
      Resource = [
        "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/glue/*",
        "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/sagemaker/*"
      ]
    }]
  })

  tags = var.tags
}

resource "aws_iam_group_policy_attachment" "de_glue_s3" {
  group      = aws_iam_group.data_engineering.name
  policy_arn = aws_iam_policy.glue_s3.arn
}

resource "aws_iam_group_policy_attachment" "de_glue_etl" {
  group      = aws_iam_group.data_engineering.name
  policy_arn = aws_iam_policy.glue_etl.arn
}

resource "aws_iam_group_policy_attachment" "de_sagemaker" {
  group      = aws_iam_group.data_engineering.name
  policy_arn = aws_iam_policy.sagemaker_access.arn
}

resource "aws_iam_group_policy_attachment" "de_sagemaker_s3" {
  group      = aws_iam_group.data_engineering.name
  policy_arn = aws_iam_policy.sagemaker_s3.arn
}

resource "aws_iam_group_policy_attachment" "de_athena" {
  group      = aws_iam_group.data_engineering.name
  policy_arn = aws_iam_policy.athena_access.arn
}

resource "aws_iam_group_policy_attachment" "de_secrets" {
  group      = aws_iam_group.data_engineering.name
  policy_arn = aws_iam_policy.de_secrets.arn
}

resource "aws_iam_group_policy_attachment" "de_cloudwatch" {
  group      = aws_iam_group.data_engineering.name
  policy_arn = aws_iam_policy.de_cloudwatch.arn
}

resource "aws_iam_group_policy_attachment" "de_deny" {
  group      = aws_iam_group.data_engineering.name
  policy_arn = aws_iam_policy.deny_sensitive.arn
}

###############################################################################
# ST-CDCU-QA Group
###############################################################################

resource "aws_iam_group" "qa" {
  name = "ST-CDCU-${local.env}-QA"
}

resource "aws_iam_policy" "qa_access" {
  name = "ST-CDCU-${local.env}-QAReadOnlyAccess"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3AthenaResultsRead"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.athena_results_bucket_arn,
          "${var.athena_results_bucket_arn}/*"
        ]
      },
      {
        Sid    = "AthenaReadOnly"
        Effect = "Allow"
        Action = [
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:ListQueryExecutions",
          "athena:GetWorkGroup"
        ]
        Resource = "arn:aws:athena:${local.region}:${local.account_id}:workgroup/${var.athena_workgroup_name}"
      },
      {
        Sid    = "CloudWatchLogsRead"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents"
        ]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/glue/*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_group_policy_attachment" "qa_access" {
  group      = aws_iam_group.qa.name
  policy_arn = aws_iam_policy.qa_access.arn
}

resource "aws_iam_group_policy_attachment" "qa_deny" {
  group      = aws_iam_group.qa.name
  policy_arn = aws_iam_policy.deny_sensitive.arn
}
