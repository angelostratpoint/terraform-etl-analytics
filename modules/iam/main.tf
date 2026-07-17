data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id                 = data.aws_caller_identity.current.account_id
  region                     = data.aws_region.current.name
  env                        = var.environment
  secret_prefix              = "cdcu/${local.env}/"
  glue_catalog_database_name = "cdcu_${replace(local.env, "-", "_")}_catalog"

  glue_catalog_arn       = "arn:aws:glue:${local.region}:${local.account_id}:catalog"
  glue_database_arn      = "arn:aws:glue:${local.region}:${local.account_id}:database/${local.glue_catalog_database_name}"
  glue_table_arn         = "arn:aws:glue:${local.region}:${local.account_id}:table/${local.glue_catalog_database_name}/*"
  glue_crawler_arn       = "arn:aws:glue:${local.region}:${local.account_id}:crawler/cdcu-*"
  glue_job_arn           = "arn:aws:glue:${local.region}:${local.account_id}:job/cdcu-*"
  glue_connection_arn    = "arn:aws:glue:${local.region}:${local.account_id}:connection/cdcu-*"
  glue_trigger_arn       = "arn:aws:glue:${local.region}:${local.account_id}:trigger/cdcu-*"
  glue_workflow_arn      = "arn:aws:glue:${local.region}:${local.account_id}:workflow/cdcu-*"
  glue_assets_bucket_arn = "arn:aws:s3:::aws-glue-assets-${local.account_id}-${local.region}"

  sagemaker_processing_job_arn          = "arn:aws:sagemaker:${local.region}:${local.account_id}:processing-job/cdcu-*"
  sagemaker_pipeline_processing_job_arn = "arn:aws:sagemaker:${local.region}:${local.account_id}:processing-job/pipelines-*"
  sagemaker_training_job_arn            = "arn:aws:sagemaker:${local.region}:${local.account_id}:training-job/cdcu-*"
  sagemaker_model_arn                   = "arn:aws:sagemaker:${local.region}:${local.account_id}:model/cdcu-*"
  sagemaker_endpoint_config_arn         = "arn:aws:sagemaker:${local.region}:${local.account_id}:endpoint-config/cdcu-*"
  sagemaker_endpoint_arn                = "arn:aws:sagemaker:${local.region}:${local.account_id}:endpoint/cdcu-*"
  sagemaker_pipeline_arn                = "arn:aws:sagemaker:${local.region}:${local.account_id}:pipeline/cdcu-*"
  sagemaker_processing_ecr_repo_arn     = "arn:aws:ecr:${local.region}:${local.account_id}:repository/cdcu-${local.env}-sagemaker-processing"
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
          "cloudformation:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyCloudShellExceptTemporaryValidationUser"
        Effect = "Deny"
        Action = [
          "cloudshell:*"
        ]
        Resource = "*"
        Condition = {
          StringNotLike = {
            "aws:PrincipalArn" = "arn:aws:iam::${local.account_id}:user/sp-angelojoe.delossantos"
          }
        }
      },
      {
        Sid    = "DenyOutsideRegion"
        Effect = "Deny"
        NotAction = [
          "iam:*",
          "sts:*",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:GetMetricWidgetImage",
          "cloudwatch:GetDashboard",
          "cloudwatch:ListDashboards",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:ListMetrics",
          "glue:BatchGet*",
          "glue:Describe*",
          "glue:Get*",
          "glue:List*",
          "glue:BatchGetCrawlers",
          "glue:BatchGetTriggers",
          "glue:BatchGetWorkflows",
          "glue:DescribeInboundIntegrations",
          "glue:DescribeIntegrations",
          "glue:GetConnection",
          "glue:GetConnections",
          "glue:GetCrawler",
          "glue:GetCrawlerMetrics",
          "glue:GetCrawlers",
          "glue:GetJob",
          "glue:GetJobRun",
          "glue:GetJobRuns",
          "glue:GetJobs",
          "glue:GetTrigger",
          "glue:GetTriggers",
          "glue:GetWorkflow",
          "glue:GetWorkflowRun",
          "glue:GetWorkflowRuns",
          "glue:GetWorkflows",
          "glue:ListConnections",
          "glue:ListCrawlers",
          "glue:ListDatabases",
          "glue:ListJobs",
          "glue:ListWorkflows",
          "logs:DescribeQueries",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetQueryResults",
          "logs:StartQuery",
          "logs:StopQuery",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:GetObjectVersion",
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
    Statement = [
      {
        Sid    = "S3DataLakeObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${var.data_lake_bucket_arn}/*"
      },
      {
        Sid    = "S3DataLakeBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketNotification",
          "s3:GetBucketVersioning",
          "s3:PutBucketNotification"
        ]
        Resource = var.data_lake_bucket_arn
      },
      {
        Sid    = "S3GlueAssetsBucketCreateAccess"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket"
        ]
        Resource = local.glue_assets_bucket_arn
        Condition = {
          StringEquals = {
            "s3:LocationConstraint" = local.region
          }
        }
      },
      {
        Sid    = "S3GlueAssetsBucketReadAccess"
        Effect = "Allow"
        Action = [
          "s3:GetBucketPublicAccessBlock",
          "s3:ListBucket",
          "s3:PutBucketPublicAccessBlock"
        ]
        Resource = local.glue_assets_bucket_arn
      },
      {
        Sid    = "S3GlueAssetsObjectReadAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${local.glue_assets_bucket_arn}/*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "glue_etl" {
  name = "ST-CDCU-${local.env}-GlueCrawlerAndETL"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GlueCatalogAccess"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase", "glue:GetDatabases", "glue:CreateDatabase", "glue:UpdateDatabase",
          "glue:GetTable", "glue:GetTables", "glue:SearchTables", "glue:CreateTable", "glue:UpdateTable", "glue:DeleteTable",
          "glue:GetPartition", "glue:GetPartitions", "glue:CreatePartition", "glue:UpdatePartition", "glue:DeletePartition",
          "glue:BatchCreatePartition", "glue:BatchUpdatePartition", "glue:BatchDeletePartition",
          "glue:BatchGetPartition", "glue:GetCatalogImportStatus"
        ]
        Resource = [
          local.glue_catalog_arn,
          local.glue_database_arn,
          local.glue_table_arn,
          # Allow access to the default database so DE scripts using
          # from_catalog(database="default") do not get AccessDeniedException.
          "arn:aws:glue:${local.region}:${local.account_id}:database/default",
          "arn:aws:glue:${local.region}:${local.account_id}:table/default/*"
        ]
      },
      {
        Sid    = "GlueCrawlerAccess"
        Effect = "Allow"
        Action = [
          "glue:CreateCrawler", "glue:UpdateCrawler", "glue:DeleteCrawler",
          "glue:GetCrawler", "glue:GetCrawlers", "glue:StartCrawler", "glue:StopCrawler",
          "glue:GetTags", "glue:TagResource", "glue:UntagResource"
        ]
        Resource = [
          local.glue_crawler_arn,
          "*"
        ]
      },
      {
        Sid    = "GlueJobAccess"
        Effect = "Allow"
        Action = [
          "glue:CreateJob", "glue:UpdateJob", "glue:DeleteJob",
          "glue:GetJob", "glue:GetJobs", "glue:BatchGetJobs",
          "glue:StartJobRun", "glue:GetJobRun", "glue:GetJobRuns", "glue:BatchStopJobRun",
          "glue:GetJobBookmark", "glue:ResetJobBookmark",
          "glue:GetTags", "glue:TagResource", "glue:UntagResource"
        ]
        Resource = [
          local.glue_job_arn,
          "*"
        ]
      },
      {
        Sid    = "GlueConnectionAccess"
        Effect = "Allow"
        Action = [
          "glue:GetConnection", "glue:GetConnections", "glue:CreateConnection", "glue:UpdateConnection",
          "glue:DeleteConnection", "glue:GetSecurityConfiguration", "glue:GetSecurityConfigurations",
          "glue:GetTags", "glue:TestConnection"
        ]
        Resource = "*"
      },
      {
        Sid    = "GlueStudioScriptAndVisualEditor"
        Effect = "Allow"
        Action = [
          "glue:CreateScript", "glue:GetDataflowGraph"
        ]
        Resource = "*"
      },
      {
        Sid    = "EventBridgeCrawlerRuleDiscovery"
        Effect = "Allow"
        Action = [
          "events:DescribeEventBus",
          "events:ListEventBuses",
          "events:ListRuleNamesByTarget",
          "events:ListRules",
          "events:ListTargetsByRule",
          "schemas:ListRegistries",
          "schemas:ListSchemas",
          "schemas:DescribeRegistry",
          "schemas:DescribeSchema",
          "schemas:SearchSchemas"
        ]
        Resource = "*"
      },
      {
        Sid    = "EventBridgeCrawlerRules"
        Effect = "Allow"
        Action = [
          "events:DeleteRule",
          "events:DescribeRule",
          "events:DisableRule",
          "events:EnableRule",
          "events:PutRule",
          "events:PutTargets",
          "events:RemoveTargets",
          "events:TagResource",
          "events:UntagResource"
        ]
        Resource = "arn:aws:events:${local.region}:${local.account_id}:rule/cdcu-${local.env}-*"
      },
      {
        # AWS does not support resource-level restrictions for these actions.
        Sid    = "GlueStudioConsoleWildcard"
        Effect = "Allow"
        Action = [
          "glue:GetCrawlerMetrics",
          "glue:ListSchemas", "glue:GetRegistry", "glue:ListRegistries",
          "schemas:ListRegistries", "schemas:ListSchemas", "schemas:DescribeRegistry", "schemas:DescribeSchema", "schemas:SearchSchemas",
          "cloudwatch:GetMetricData", "cloudwatch:GetMetricStatistics", "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricWidgetImage", "cloudwatch:GetDashboard", "cloudwatch:ListDashboards",
          "cloudwatch:DescribeAlarms", "cloudwatch:DescribeAlarmsForMetric"
        ]
        Resource = "*"
      },
      {
        # Glue monitoring widgets and account-level summaries use wildcard reads
        # even when the actual jobs/crawlers are resource-scoped.
        Sid    = "GlueJobRunMonitoringConsoleRead"
        Effect = "Allow"
        Action = [
          "glue:BatchGetJobs",
          "glue:BatchGetCrawlers",
          "glue:BatchGetTriggers",
          "glue:BatchGetWorkflows",
          "glue:BatchGet*",
          "glue:Describe*",
          "glue:DescribeInboundIntegrations",
          "glue:DescribeIntegrations",
          "glue:Get*",
          "glue:GetCrawler",
          "glue:GetCrawlerMetrics",
          "glue:GetCrawlers",
          "glue:GetJob",
          "glue:GetJobRun",
          "glue:GetJobRuns",
          "glue:GetJobs",
          "glue:GetTrigger",
          "glue:GetTriggers",
          "glue:GetWorkflow",
          "glue:GetWorkflowRun",
          "glue:GetWorkflowRuns",
          "glue:GetWorkflows",
          "glue:List*",
          "glue:ListCrawlers",
          "glue:ListJobs",
          "glue:ListWorkflows"
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
          "ec2:DescribeNetworkInterfaces",
          "ec2:CreateTags"
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
    Statement = [
      {
        Sid    = "CloudWatchLogsGlueWriteRead"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:DescribeQueries",
          "logs:StartQuery",
          "logs:GetQueryResults",
          "logs:StopQuery"
        ]
        Resource = [
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/glue/*",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/glue/*:log-stream:*",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws-glue/*",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws-glue/*:log-stream:*"
        ]
      },
      {
        Sid    = "CloudWatchLogsGlueDescribe"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "glue_kms" {
  name = "ST-CDCU-${local.env}-GlueKMSDecrypt"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KMSDecryptForGlueConnections"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
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

resource "aws_iam_role_policy_attachment" "glue_kms" {
  role       = aws_iam_role.glue_execution.name
  policy_arn = aws_iam_policy.glue_kms.arn
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
  description = "Execution role for CDCU SageMaker Studio, JupyterLab spaces, and jobs"

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
        Sid    = "SageMakerCDCUWorkloadAccess"
        Effect = "Allow"
        Action = [
          "sagemaker:CreateProcessingJob", "sagemaker:DescribeProcessingJob",
          "sagemaker:StopProcessingJob",
          "sagemaker:CreateTrainingJob", "sagemaker:DescribeTrainingJob",
          "sagemaker:StopTrainingJob",
          "sagemaker:CreateModel", "sagemaker:DescribeModel",
          "sagemaker:CreateEndpointConfig", "sagemaker:DescribeEndpointConfig",
          "sagemaker:CreateEndpoint", "sagemaker:DescribeEndpoint", "sagemaker:InvokeEndpoint",
          "sagemaker:CreatePipeline", "sagemaker:StartPipelineExecution",
          "sagemaker:DescribePipeline", "sagemaker:DescribePipelineExecution"
        ]
        Resource = [
          local.sagemaker_processing_job_arn,
          local.sagemaker_pipeline_processing_job_arn,
          local.sagemaker_training_job_arn,
          local.sagemaker_model_arn,
          local.sagemaker_endpoint_config_arn,
          local.sagemaker_endpoint_arn,
          local.sagemaker_pipeline_arn
        ]
      },
      {
        Sid    = "SageMakerStudioControlPlaneAccess"
        Effect = "Allow"
        Action = [
          "sagemaker:ListProcessingJobs", "sagemaker:ListTrainingJobs",
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
        Sid    = "SageMakerPassOwnExecutionRole"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = aws_iam_role.sagemaker_execution.arn
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "sagemaker.amazonaws.com"
          }
        }
      },
      {
        Sid    = "SageMakerECRAuthorization"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "SageMakerProcessingImagePull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:DescribeImages",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = local.sagemaker_processing_ecr_repo_arn
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "sagemaker_s3" {
  name = "ST-CDCU-${local.env}-SageMakerS3Access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SageMakerS3DataLakeObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${var.data_lake_bucket_arn}/*"
      },
      {
        Sid      = "SageMakerS3DataLakeListAccess"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = var.data_lake_bucket_arn
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "sagemaker_cloudwatch" {
  name = "ST-CDCU-${local.env}-SageMakerCloudWatchLogs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsSageMakerWriteRead"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:DescribeQueries",
          "logs:StartQuery",
          "logs:GetQueryResults",
          "logs:StopQuery"
        ]
        Resource = [
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/sagemaker/*",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/sagemaker/*:log-stream:*"
        ]
      },
      {
        Sid    = "CloudWatchLogsSageMakerDescribe"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "sagemaker_amazon_q" {
  name = "ST-CDCU-${local.env}-SageMakerAmazonQAccess"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AmazonQDeveloperInSageMakerStudio"
        Effect = "Allow"
        Action = [
          "q:StartConversation",
          "q:SendMessage",
          "q:GetConversation",
          "q:ListConversations",
          "q:PassRequest",
          "sagemaker-data-science-assistant:SendConversation",
          "sagemaker-data-science-assistant:GetConversation",
          "sagemaker-data-science-assistant:ListConversations",
          "codewhisperer:GenerateRecommendations"
        ]
        Resource = "*"
      }
    ]
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

resource "aws_iam_role_policy_attachment" "sagemaker_amazon_q" {
  role       = aws_iam_role.sagemaker_execution.name
  policy_arn = aws_iam_policy.sagemaker_amazon_q.arn
}

resource "aws_iam_role_policy_attachment" "sagemaker_athena" {
  role       = aws_iam_role.sagemaker_execution.name
  policy_arn = aws_iam_policy.athena_access.arn
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
        Sid    = "AthenaWorkgroupQueryAccess"
        Effect = "Allow"
        Action = [
          "athena:BatchGetQueryExecution",
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution",
          "athena:ListQueryExecutions",
          "athena:BatchGetNamedQuery",
          "athena:GetNamedQuery",
          "athena:ListNamedQueries",
          "athena:CreateNamedQuery",
          "athena:DeleteNamedQuery",
          "athena:GetWorkGroup"
        ]
        Resource = "arn:aws:athena:${local.region}:${local.account_id}:workgroup/${var.athena_workgroup_name}"
      },
      {
        Sid    = "AthenaConsoleDiscoveryAccess"
        Effect = "Allow"
        Action = [
          "athena:ListWorkGroups",
          "athena:ListDataCatalogs"
        ]
        Resource = "*"
      },
      {
        Sid    = "AthenaDataCatalogAccess"
        Effect = "Allow"
        Action = [
          "athena:GetDataCatalog",
          "athena:GetTableMetadata",
          "athena:ListDatabases",
          "athena:ListTableMetadata"
        ]
        Resource = "arn:aws:athena:${local.region}:${local.account_id}:datacatalog/AwsDataCatalog"
      },
      {
        Sid    = "AthenaResultsAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${var.athena_results_bucket_arn}/*"
      },
      {
        Sid      = "AthenaResultsListAccess"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = var.athena_results_bucket_arn
      },
      {
        Sid    = "AthenaGlueCatalogAccess"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:SearchTables",
          "glue:GetPartition",
          "glue:GetPartitions"
        ]
        Resource = [
          local.glue_catalog_arn,
          local.glue_database_arn,
          local.glue_table_arn
        ]
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
# ST-CDCU-EventBridgeGlueRole
###############################################################################

resource "aws_iam_role" "eventbridge_glue" {
  name        = "ST-CDCU-${local.env}-EventBridgeGlueRole"
  description = "Execution role for EventBridge rules that invoke CDCU Glue and SageMaker targets"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "ST-CDCU-${local.env}-EventBridgeGlueRole" })
}

resource "aws_iam_policy" "eventbridge_glue" {
  name        = "ST-CDCU-${local.env}-EventBridgeGlueAccess"
  description = "Allows EventBridge to start approved CDCU Glue crawlers/jobs and SageMaker pipeline/processing targets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EventBridgeGlueTargets"
        Effect = "Allow"
        Action = [
          "glue:StartCrawler",
          "glue:StartJobRun"
        ]
        Resource = [
          "arn:aws:glue:${local.region}:${local.account_id}:crawler/cdcu-${local.env}-*",
          "arn:aws:glue:${local.region}:${local.account_id}:job/cdcu-${local.env}-*"
        ]
      },
      {
        Sid    = "EventBridgeSageMakerProcessingTargets"
        Effect = "Allow"
        Action = [
          "sagemaker:CreateProcessingJob"
        ]
        Resource = "arn:aws:sagemaker:${local.region}:${local.account_id}:processing-job/cdcu-${local.env}-*"
      },
      {
        Sid    = "EventBridgeSageMakerPipelineTargets"
        Effect = "Allow"
        Action = [
          "sagemaker:StartPipelineExecution"
        ]
        Resource = "arn:aws:sagemaker:${local.region}:${local.account_id}:pipeline/cdcu-${local.env}-*"
      },
      {
        Sid    = "EventBridgePassSageMakerExecutionRole"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
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

resource "aws_iam_role_policy_attachment" "eventbridge_glue" {
  role       = aws_iam_role.eventbridge_glue.name
  policy_arn = aws_iam_policy.eventbridge_glue.arn
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
    Statement = [
      {
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
        Resource = "arn:aws:events:${local.region}:${local.account_id}:rule/cdcu-*"
      },
      {
        Sid    = "EventBridgeSchemaDiscovery"
        Effect = "Allow"
        Action = [
          "schemas:ListRegistries",
          "schemas:ListSchemas",
          "schemas:DescribeRegistry",
          "schemas:DescribeSchema",
          "schemas:SearchSchemas"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyNonCDCUEventBridgeRuleMutation"
        Effect = "Deny"
        Action = [
          "events:PutRule",
          "events:PutTargets",
          "events:EnableRule",
          "events:DisableRule",
          "events:DeleteRule",
          "events:RemoveTargets"
        ]
        NotResource = "arn:aws:events:${local.region}:${local.account_id}:rule/cdcu-*"
      },
      {
        Sid    = "EventBridgeGluePassRole"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "arn:aws:iam::${local.account_id}:role/ST-CDCU-${local.env}-EventBridgeGlueRole"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "events.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "ce_amazon_q" {
  name = "ST-CDCU-${local.env}-AmazonQDeveloperAccess"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AmazonQConsoleAssistantOnly"
        Effect = "Allow"
        Action = [
          "q:SendMessage",
          "q:StartConversation",
          "q:GetConversation",
          "q:ListConversations",
          "q:DeleteConversation"
        ]
        Resource = "*"
      },
      {
        Sid      = "AllowSTSContextForQ"
        Effect   = "Allow"
        Action   = ["sts:SetContext"]
        Resource = "arn:aws:sts::*:self"
      },
      {
        Sid    = "ExplicitlyDenyQAdministrativeFunctions"
        Effect = "Deny"
        Action = [
          "q:CreateAssignment",
          "q:DeleteAssignment",
          "q:CreatePlugin",
          "q:UpdatePlugin",
          "q:DeletePlugin",
          "q:GetPlugin",
          "q:UsePlugin",
          "q:ListPlugins",
          "q:ListPluginProviders",
          "q:TagResource",
          "q:UntagResource",
          "q:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid      = "ExplicitlyDenyCodeGenerationFeatures"
        Effect   = "Deny"
        Action   = ["q:GenerateCodeFromCommands"]
        Resource = "*"
      }
    ]
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
    Statement = [
      {
        Sid    = "CloudWatchLogsAllCDCUWriteRead"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:GetQueryResults",
          "logs:StopQuery"
        ]
        Resource = [
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/glue/*",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/glue/*:log-stream:*",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws-glue/*",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws-glue/*:log-stream:*",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/sagemaker/*",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/sagemaker/*:log-stream:*"
        ]
      },
      {
        Sid    = "CloudWatchLogsAllCDCUDescribe"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
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

resource "aws_iam_group_policy" "ce_lakeformation_admin" {
  name  = "CloudEngineerLakeFormationGovernanceAdminInlinePolicy"
  group = aws_iam_group.cloud_engineering.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LakeFormationGovernanceAdmin"
        Effect = "Allow"
        Action = [
          "lakeformation:DescribeResource",
          "lakeformation:GetDataLakeSettings",
          "lakeformation:GetEffectivePermissionsForPath",
          "lakeformation:GetLFTag",
          "lakeformation:GetResourceLFTags",
          "lakeformation:GrantPermissions",
          "lakeformation:ListLFTags",
          "lakeformation:ListPermissions",
          "lakeformation:ListResources",
          "lakeformation:RevokePermissions",
          "lakeformation:PutDataLakeSettings",
          "lakeformation:RegisterResource",
          "lakeformation:DeregisterResource",
          "lakeformation:SearchDatabasesByLFTags",
          "lakeformation:SearchTablesByLFTags",
          "ram:GetResourceShareInvitations",
          "ram:GetResourceShares",
          "ram:ListPrincipals",
          "ram:ListResources"
        ]
        Resource = "*"
      }
    ]
  })
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
    Statement = [
      {
        Sid      = "SecretsManagerList"
        Effect   = "Allow"
        Action   = ["secretsmanager:ListSecrets"]
        Resource = "*"
      },
      {
        Sid    = "SecretsManagerReadAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds",
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:BatchGetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${local.secret_prefix}*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "de_cloudwatch" {
  name = "ST-CDCU-${local.env}-DECloudWatchLogsRead"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsRead"
        Effect = "Allow"
        Action = [
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:GetQueryResults",
          "logs:StopQuery"
        ]
        Resource = [
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/glue/*",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/glue/*:log-stream:*",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws-glue/*",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws-glue/*:log-stream:*",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/sagemaker/*",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/sagemaker/*:log-stream:*"
        ]
      },
      {
        Sid    = "CloudWatchLogsDescribe"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "de_passrole" {
  name = "ST-CDCU-${local.env}-DEPassRole"
  # Merged SageMaker + Glue PassRole into one policy to stay under the
  # 10-policy-per-group AWS limit. Mirrors CDCUDataEngineerPassRolePolicy
  # in cdcu-access.yaml. Each service PassRole is a separate Sid.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowOnlyApprovedSageMakerExecutionRoles"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = "arn:aws:iam::${local.account_id}:role/ST-CDCU-${local.env}-SageMakerExecutionRole"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "sagemaker.amazonaws.com"
          }
        }
      },
      {
        Sid    = "AllowOnlyApprovedGlueExecutionRoles"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = "arn:aws:iam::${local.account_id}:role/ST-CDCU-${local.env}-GlueExecutionRole"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "glue.amazonaws.com"
          }
        }
      },
      {
        Sid    = "AllowOnlyApprovedEventBridgeGlueRoles"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = "arn:aws:iam::${local.account_id}:role/ST-CDCU-${local.env}-EventBridgeGlueRole"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "events.amazonaws.com"
          }
        }
      },
      {
        Sid    = "ExecutionRoleRead"
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:ListRoles",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies"
        ]
        Resource = [
          "arn:aws:iam::${local.account_id}:role/ST-CDCU-${local.env}-GlueExecutionRole",
          "arn:aws:iam::${local.account_id}:role/ST-CDCU-${local.env}-SageMakerExecutionRole",
          "arn:aws:iam::${local.account_id}:role/ST-CDCU-${local.env}-EventBridgeGlueRole"
        ]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "de_glue_console" {
  name = "ST-CDCU-${local.env}-DEGlueConsoleAccess"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GlueStudioS3BucketDiscovery"
        Effect = "Allow"
        Action = [
          "glue:ListConnections",
          "glue:BatchGetCrawlers",
          "glue:ListCrawlers",
          "glue:ListDatabases",
          "glue:ListJobs",
          "glue:ListWorkflows",
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation"
        ]
        Resource = "*"
      },
      {
        Sid    = "GlueStudioIAMRoleDiscovery"
        Effect = "Allow"
        Action = ["iam:ListRoles"]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_group_policy" "de_glue_orchestration" {
  name  = "DataEngineerGlueWorkflowTriggerInlinePolicy"
  group = aws_iam_group.data_engineering.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GlueWorkflowTriggerScopedAccess"
        Effect = "Allow"
        Action = [
          "glue:CreateTrigger",
          "glue:UpdateTrigger",
          "glue:DeleteTrigger",
          "glue:StartTrigger",
          "glue:StopTrigger",
          "glue:CreateWorkflow",
          "glue:UpdateWorkflow",
          "glue:DeleteWorkflow",
          "glue:StartWorkflowRun",
          "glue:GetTags",
          "glue:TagResource",
          "glue:UntagResource"
        ]
        Resource = [
          "arn:aws:glue:${local.region}:${local.account_id}:trigger/cdcu-${local.env}-*",
          "arn:aws:glue:${local.region}:${local.account_id}:workflow/cdcu-${local.env}-*"
        ]
      },
      {
        Sid    = "GlueWorkflowTriggerDiscovery"
        Effect = "Allow"
        Action = [
          "glue:GetTrigger",
          "glue:GetTriggers",
          "glue:BatchGetTriggers",
          "glue:GetWorkflow",
          "glue:GetWorkflows",
          "glue:BatchGetWorkflows",
          "glue:GetWorkflowRun",
          "glue:GetWorkflowRuns",
          "glue:ListWorkflows"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_group_policy" "de_eventbridge_crawler_trigger" {
  name  = "DataEngineerEventBridgeCrawlerTriggerInlinePolicy"
  group = aws_iam_group.data_engineering.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EventBridgeCrawlerTriggerRules"
        Effect = "Allow"
        Action = [
          "events:PutRule",
          "events:PutTargets",
          "events:DescribeRule",
          "events:EnableRule",
          "events:DisableRule",
          "events:DeleteRule",
          "events:RemoveTargets",
          "events:ListTargetsByRule",
          "events:TagResource",
          "events:UntagResource"
        ]
        Resource = "arn:aws:events:${local.region}:${local.account_id}:rule/cdcu-${local.env}-*"
      },
      {
        Sid    = "EventBridgeCrawlerTriggerDiscovery"
        Effect = "Allow"
        Action = [
          "events:DescribeEventBus",
          "events:ListRuleNamesByTarget",
          "events:ListRules",
          "events:ListEventBuses",
          "scheduler:ListSchedules",
          "scheduler:ListScheduleGroups",
          "schemas:ListRegistries",
          "schemas:ListSchemas",
          "schemas:DescribeRegistry",
          "schemas:DescribeSchema",
          "schemas:SearchSchemas"
        ]
        Resource = "*"
      },
      {
        Sid    = "CDCUDataLakeEventNotificationAccess"
        Effect = "Allow"
        Action = [
          "s3:GetBucketNotification",
          "s3:PutBucketNotification"
        ]
        Resource = [
          "arn:aws:s3:::cdcu-${local.env}-data-lake",
          "arn:aws:s3:::cdcu-${local.env}-data-lake-apse1"
        ]
      }
    ]
  })
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

resource "aws_iam_group_policy_attachment" "de_passrole" {
  group      = aws_iam_group.data_engineering.name
  policy_arn = aws_iam_policy.de_passrole.arn
}

resource "aws_iam_group_policy_attachment" "de_glue_console" {
  group      = aws_iam_group.data_engineering.name
  policy_arn = aws_iam_policy.de_glue_console.arn
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
        Sid      = "S3ConsoleBucketDiscovery"
        Effect   = "Allow"
        Action   = ["s3:ListAllMyBuckets"]
        Resource = "*"
      },
      {
        Sid    = "S3DataLakeValidationList"
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = var.data_lake_bucket_arn
      },
      {
        Sid    = "S3DataLakeValidationRead"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${var.data_lake_bucket_arn}/*"
      },
      {
        Sid      = "S3AthenaResultsRead"
        Effect   = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${var.athena_results_bucket_arn}/*"
      },
      {
        Sid      = "S3AthenaResultsList"
        Effect   = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = var.athena_results_bucket_arn
      },
      {
        Sid    = "AthenaReadOnly"
        Effect = "Allow"
        Action = [
          "athena:BatchGetQueryExecution",
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:ListQueryExecutions",
          "athena:StopQueryExecution",
          "athena:GetWorkGroup"
        ]
        Resource = "arn:aws:athena:${local.region}:${local.account_id}:workgroup/${var.athena_workgroup_name}"
      },
      {
        Sid    = "AthenaConsoleDiscovery"
        Effect = "Allow"
        Action = [
          "athena:ListDataCatalogs",
          "athena:ListWorkGroups"
        ]
        Resource = "*"
      },
      {
        Sid    = "AthenaCatalogMetadataRead"
        Effect = "Allow"
        Action = [
          "athena:GetDataCatalog",
          "athena:GetTableMetadata",
          "athena:ListDatabases",
          "athena:ListTableMetadata"
        ]
        Resource = "arn:aws:athena:${local.region}:${local.account_id}:datacatalog/AwsDataCatalog"
      },
      {
        Sid    = "GlueCatalogValidationRead"
        Effect = "Allow"
        Action = [
          "glue:BatchGetPartition",
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:GetTable",
          "glue:GetTables",
          "glue:SearchTables"
        ]
        Resource = [
          "arn:aws:glue:${local.region}:${local.account_id}:catalog",
          "arn:aws:glue:${local.region}:${local.account_id}:database/cdcu_${local.env}_catalog",
          "arn:aws:glue:${local.region}:${local.account_id}:table/cdcu_${local.env}_catalog/*"
        ]
      },
      {
        Sid    = "QuickSightValidationReview"
        Effect = "Allow"
        Action = [
          "quicksight:DescribeAnalysis",
          "quicksight:DescribeDashboard",
          "quicksight:DescribeDataSet",
          "quicksight:DescribeDataSource",
          "quicksight:DescribeGroup",
          "quicksight:GenerateEmbedUrlForRegisteredUser",
          "quicksight:GetDashboardEmbedUrl",
          "quicksight:ListAnalyses",
          "quicksight:ListDashboards",
          "quicksight:ListDataSets",
          "quicksight:ListDataSources",
          "quicksight:ListGroups"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogsRead"
        Effect = "Allow"
        Action = ["logs:GetLogEvents"]
        Resource = [
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/glue/*",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/glue/*:log-stream:*",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws-glue/*",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws-glue/*:log-stream:*"
        ]
      },
      {
        Sid    = "CloudWatchLogsDescribe"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
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
