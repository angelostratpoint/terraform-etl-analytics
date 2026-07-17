locals {
  notebook_instance_name = var.notebook_instance_name != "" ? var.notebook_instance_name : "cdcu-${var.environment}-notebook"
  notebook_subnet_id     = length(var.subnet_ids) > 0 ? var.subnet_ids[0] : null

  studio_notebook_s3_uri                         = var.studio_notebook_s3_uri != "" ? var.studio_notebook_s3_uri : "s3://${var.data_lake_bucket_name}/${var.environment}/sagemaker-notebooks/"
  studio_notebook_local_path                     = var.studio_notebook_local_path != "" ? var.studio_notebook_local_path : "$HOME/cdcu-managed/notebooks/"
  studio_notebook_autosync_lifecycle_config_arns = var.enable_studio_notebook_autosync && var.enable_unified_studio ? aws_sagemaker_studio_lifecycle_config.notebook_autosync[*].arn : []

  matching_pipeline_name               = "cdcu-${var.environment}-matching-pipeline"
  matching_standardized_s3_uri         = var.matching_pipeline_standardized_s3_uri != "" ? var.matching_pipeline_standardized_s3_uri : "s3://${var.data_lake_bucket_name}/standardized/merged/"
  matching_output_s3_uri               = var.matching_pipeline_output_s3_uri != "" ? var.matching_pipeline_output_s3_uri : "s3://${var.data_lake_bucket_name}/processed/matching/"
  matching_wheelhouse_s3_uri           = var.matching_pipeline_wheelhouse_s3_uri != "" ? var.matching_pipeline_wheelhouse_s3_uri : "s3://${var.data_lake_bucket_name}/artifacts/python-wheelhouse/"
  matching_processing_script_s3_prefix = "s3://${var.data_lake_bucket_name}/${var.environment}/sagemaker-scripts/processing/"

  matching_pipeline_definition = {
    Version = "2020-12-01"
    Metadata = {
      Project     = "CDCU"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
    Steps = [
      {
        Name = "CDCUCustomerMatchingProcessing"
        Type = "Processing"
        Arguments = {
          RoleArn = var.execution_role_arn
          AppSpecification = {
            ImageUri             = var.matching_pipeline_processing_image_uri
            ContainerEntrypoint  = ["python3", "/opt/ml/processing/input/code/${var.matching_pipeline_runner_script_name}"]
          }
          Environment = {
            CDCU_ENVIRONMENT            = var.environment
            CDCU_DATA_LAKE_BUCKET       = var.data_lake_bucket_name
            CDCU_STANDARDIZED_S3_URI    = local.matching_standardized_s3_uri
            CDCU_MATCHING_OUTPUT_S3_URI = local.matching_output_s3_uri
            CDCU_MATCHING_SCRIPT_NAME   = var.matching_pipeline_processing_script_name
          }
          ProcessingResources = {
            ClusterConfig = {
              InstanceType   = var.matching_pipeline_instance_type
              InstanceCount  = var.matching_pipeline_instance_count
              VolumeSizeInGB = var.matching_pipeline_volume_size_gb
            }
          }
          ProcessingInputs = [
            {
              InputName = "code"
              S3Input = {
                S3Uri                  = local.matching_processing_script_s3_prefix
                LocalPath              = "/opt/ml/processing/input/code"
                S3DataType             = "S3Prefix"
                S3InputMode            = "File"
                S3DataDistributionType = "FullyReplicated"
                S3CompressionType      = "None"
              }
            },
            {
              InputName = "wheelhouse"
              S3Input = {
                S3Uri                  = local.matching_wheelhouse_s3_uri
                LocalPath              = "/opt/ml/processing/input/wheelhouse"
                S3DataType             = "S3Prefix"
                S3InputMode            = "File"
                S3DataDistributionType = "FullyReplicated"
                S3CompressionType      = "None"
              }
            },
            {
              InputName = "standardized-data"
              S3Input = {
                S3Uri                  = local.matching_standardized_s3_uri
                LocalPath              = "/opt/ml/processing/input/data"
                S3DataType             = "S3Prefix"
                S3InputMode            = "File"
                S3DataDistributionType = "FullyReplicated"
                S3CompressionType      = "None"
              }
            }
          ]
          ProcessingOutputConfig = {
            Outputs = [
              {
                OutputName = "matching-output"
                S3Output = {
                  S3Uri        = local.matching_output_s3_uri
                  LocalPath    = "/opt/ml/processing/output"
                  S3UploadMode = "EndOfJob"
                }
              }
            ]
          }
          StoppingCondition = {
            MaxRuntimeInSeconds = var.matching_pipeline_max_runtime_seconds
          }
        }
      }
    ]
  }
}

resource "aws_sagemaker_studio_lifecycle_config" "notebook_autosync" {
  count = var.enable_unified_studio && var.enable_studio_notebook_autosync ? 1 : 0

  studio_lifecycle_config_name     = "cdcu-${var.environment}-notebook-autosync"
  studio_lifecycle_config_app_type = "JupyterLab"
  studio_lifecycle_config_content = base64encode(<<-SCRIPT
    #!/bin/bash
    set -e

    NOTEBOOK_S3_URI="${local.studio_notebook_s3_uri}"
    NOTEBOOK_LOCAL_PATH="${local.studio_notebook_local_path}"

    mkdir -p "$NOTEBOOK_LOCAL_PATH"
    aws s3 sync "$NOTEBOOK_S3_URI" "$NOTEBOOK_LOCAL_PATH" || true

    echo "CDCU notebook autosync completed from $NOTEBOOK_S3_URI to $NOTEBOOK_LOCAL_PATH"
  SCRIPT
  )

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-notebook-autosync"
  })

  lifecycle {
    precondition {
      condition     = var.data_lake_bucket_name != ""
      error_message = "data_lake_bucket_name is required when enable_studio_notebook_autosync = true."
    }
  }
}

resource "aws_sagemaker_domain" "studio" {
  count = var.enable_unified_studio ? 1 : 0

  domain_name             = "cdcu-${var.environment}-studio"
  auth_mode               = "IAM"
  vpc_id                  = var.vpc_id
  subnet_ids              = var.subnet_ids
  app_network_access_type = var.studio_app_network_access_type

  default_user_settings {
    execution_role  = var.execution_role_arn
    security_groups = var.security_group_ids

    jupyter_lab_app_settings {
      lifecycle_config_arns = local.studio_notebook_autosync_lifecycle_config_arns
    }
  }

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-studio"
  })
}

resource "aws_sagemaker_user_profile" "data_scientists" {
  for_each = var.enable_unified_studio ? toset(var.studio_user_profile_names) : toset([])

  domain_id         = aws_sagemaker_domain.studio[0].id
  user_profile_name = each.value

  user_settings {
    execution_role  = var.execution_role_arn
    security_groups = var.security_group_ids

    jupyter_lab_app_settings {
      lifecycle_config_arns = local.studio_notebook_autosync_lifecycle_config_arns
    }
  }

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-${each.value}"
  })
}

resource "aws_sagemaker_code_repository" "cdcu_scripts" {
  code_repository_name = "cdcu-${var.environment}-scripts"

  git_config {
    repository_url = var.git_repository_url
    branch         = var.git_branch
    secret_arn     = var.git_secret_arn != "" ? var.git_secret_arn : null
  }

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-scripts"
  })
}

resource "aws_sagemaker_space" "jupyterlab" {
  for_each = var.enable_unified_studio ? toset(var.studio_user_profile_names) : toset([])

  domain_id  = aws_sagemaker_domain.studio[0].id
  space_name = "${each.value}-jupyterlab"
  ownership_settings {
    owner_user_profile_name = each.value
  }
  space_sharing_settings {
    sharing_type = "Private"
  }
  space_settings {
    app_type = "JupyterLab"
    jupyter_lab_app_settings {
      default_resource_spec {
        instance_type = var.studio_space_instance_type
      }
    }
    space_storage_settings {
      ebs_storage_settings {
        ebs_volume_size_in_gb = var.studio_space_volume_size_gb
      }
    }
  }

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-${each.value}-jupyterlab"
  })

  depends_on = [aws_sagemaker_user_profile.data_scientists]
}

resource "aws_sagemaker_notebook_instance" "classic" {
  count = var.enable_notebook_instance ? 1 : 0

  name                   = local.notebook_instance_name
  role_arn               = var.execution_role_arn
  instance_type          = var.notebook_instance_type
  subnet_id              = local.notebook_subnet_id
  security_groups        = var.security_group_ids
  volume_size            = var.notebook_volume_size_gb
  direct_internet_access = var.notebook_direct_internet_access
  root_access            = var.notebook_root_access

  tags = merge(var.tags, {
    Name = local.notebook_instance_name
  })
}

resource "aws_sagemaker_pipeline" "matching" {
  count = var.enable_matching_pipeline ? 1 : 0

  pipeline_name        = local.matching_pipeline_name
  pipeline_display_name = "CDCU-${var.environment}-Matching-Pipeline"
  role_arn             = var.execution_role_arn
  pipeline_definition  = jsonencode(local.matching_pipeline_definition)

  tags = merge(var.tags, {
    Name = local.matching_pipeline_name
  })

  lifecycle {
    precondition {
      condition     = var.data_lake_bucket_name != ""
      error_message = "data_lake_bucket_name is required when enable_matching_pipeline = true."
    }

    precondition {
      condition     = var.matching_pipeline_processing_image_uri != ""
      error_message = "matching_pipeline_processing_image_uri is required when enable_matching_pipeline = true."
    }
  }
}

resource "aws_cloudwatch_event_rule" "matching_pipeline_schedule" {
  count = var.enable_matching_pipeline && var.matching_pipeline_schedule_enabled ? 1 : 0

  name                = "cdcu-${var.environment}-matching-pipeline-schedule"
  description         = "Starts the CDCU ${var.environment} SageMaker matching pipeline"
  schedule_expression = var.matching_pipeline_schedule_expression
  state               = "ENABLED"

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-matching-pipeline-schedule"
  })
}

resource "aws_cloudwatch_event_target" "matching_pipeline" {
  count = var.enable_matching_pipeline && var.matching_pipeline_schedule_enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.matching_pipeline_schedule[0].name
  target_id = "cdcu-${var.environment}-matching-pipeline"
  arn       = aws_sagemaker_pipeline.matching[0].arn
  role_arn  = var.eventbridge_role_arn

  lifecycle {
    precondition {
      condition     = var.eventbridge_role_arn != ""
      error_message = "eventbridge_role_arn is required when matching_pipeline_schedule_enabled = true."
    }
  }
}

resource "aws_cloudwatch_event_rule" "matching_pipeline_after_glue_success" {
  count = var.enable_matching_pipeline && var.matching_pipeline_glue_success_event_enabled ? 1 : 0

  name        = "cdcu-${var.environment}-matching-after-glue-success"
  description = "Starts the CDCU ${var.environment} SageMaker matching pipeline after the upstream Glue job succeeds"

  event_pattern = jsonencode({
    source      = ["aws.glue"]
    detail-type = ["Glue Job State Change"]
    detail = {
      jobName = [var.matching_pipeline_trigger_glue_job_name]
      state   = ["SUCCEEDED"]
    }
  })

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-matching-after-glue-success"
  })

  lifecycle {
    precondition {
      condition     = var.matching_pipeline_trigger_glue_job_name != ""
      error_message = "matching_pipeline_trigger_glue_job_name is required when matching_pipeline_glue_success_event_enabled = true."
    }
  }
}

resource "aws_cloudwatch_event_target" "matching_pipeline_after_glue_success" {
  count = var.enable_matching_pipeline && var.matching_pipeline_glue_success_event_enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.matching_pipeline_after_glue_success[0].name
  target_id = "cdcu-${var.environment}-matching-pipeline-after-glue"
  arn       = aws_sagemaker_pipeline.matching[0].arn
  role_arn  = var.eventbridge_role_arn

  lifecycle {
    precondition {
      condition     = var.eventbridge_role_arn != ""
      error_message = "eventbridge_role_arn is required when matching_pipeline_glue_success_event_enabled = true."
    }
  }
}
