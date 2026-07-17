locals {
  environment = var.environment
  subnet_ids  = distinct(compact(concat([var.subnet_id], var.subnet_ids)))
  kms_key_arn = var.enable_kms ? var.existing_kms_key_arn : ""
  sagemaker_matching_pipeline_processing_image_uri = (
    var.sagemaker_matching_pipeline_processing_image_uri != ""
    ? var.sagemaker_matching_pipeline_processing_image_uri
    : module.sagemaker_processing_image.image_uri
  )
  common_tags = {
    Project     = "CDCU"
    Environment = local.environment
    ManagedBy   = "Terraform"
    Owner       = "Stratpoint"
    CostCenter  = "CDCU-UAT"
  }
}

resource "terraform_data" "manual_baseline_contract" {
  input = local.environment

  lifecycle {
    precondition {
      condition     = var.existing_security_group_id != ""
      error_message = "existing_security_group_id is required. Network and security groups are manually provisioned by BPI MS."
    }

    precondition {
      condition     = !var.enable_kms || var.existing_kms_key_arn != ""
      error_message = "existing_kms_key_arn is required when enable_kms = true. KMS baseline is manually provisioned by BPI MS."
    }

    precondition {
      condition     = var.merged_jdbc_url != "" && var.merged_mysql_secret_name != ""
      error_message = "merged_jdbc_url and merged_mysql_secret_name are required for the shared BPI MS source database."
    }
  }
}

module "s3" {
  source = "../../modules/s3"

  environment                = local.environment
  enable_kms                 = var.enable_kms
  kms_key_arn                = local.kms_key_arn
  data_lake_bucket_name      = var.data_lake_bucket_name
  athena_results_bucket_name = var.athena_results_bucket_name
  tags                       = local.common_tags
}

module "iam" {
  source = "../../modules/iam"

  environment               = local.environment
  data_lake_bucket_arn      = module.s3.data_lake_bucket_arn
  athena_results_bucket_arn = module.s3.athena_results_bucket_arn
  athena_workgroup_name     = "cdcu-${local.environment}-workgroup"
  terraform_lock_table_name = var.terraform_lock_table_name
  tags                      = local.common_tags

  depends_on = [module.s3]
}

module "glue" {
  source = "../../modules/glue"

  environment             = local.environment
  glue_execution_role_arn = module.iam.glue_execution_role_arn
  data_lake_bucket        = module.s3.data_lake_bucket_name
  scripts_bucket          = module.s3.data_lake_bucket_name
  glue_security_group_ids = [var.existing_security_group_id]
  subnet_id               = var.subnet_id
  availability_zone       = var.availability_zone
  glue_worker_count            = var.glue_worker_count
  glue_worker_type             = var.glue_worker_type
  merged_jdbc_url              = var.merged_jdbc_url
  merged_mysql_secret_name     = var.merged_mysql_secret_name
  mysql_jdbc_driver_class_name = var.mysql_jdbc_driver_class_name
  mysql_jdbc_driver_jar_uri    = var.mysql_jdbc_driver_jar_uri
  enable_workflow_orchestration = var.enable_glue_workflow_orchestration
  enable_workflow_schedule      = var.enable_glue_workflow_schedule
  workflow_schedule_expression  = var.glue_workflow_schedule_expression
  tags                         = local.common_tags

  depends_on = [terraform_data.manual_baseline_contract, module.iam]
}

module "athena" {
  source = "../../modules/athena"

  environment           = local.environment
  athena_results_bucket = module.s3.athena_results_bucket_name
  glue_catalog_database = module.glue.catalog_database_name
  enable_kms            = var.enable_kms
  kms_key_arn           = local.kms_key_arn
  tags                  = local.common_tags
}

module "sagemaker_processing_image" {
  source = "../../modules/sagemaker-processing-image"

  enabled             = var.enable_sagemaker_processing_image_repository
  build_and_push      = var.enable_sagemaker_processing_image_build
  repository_name     = var.sagemaker_processing_image_repository_name != "" ? var.sagemaker_processing_image_repository_name : "cdcu-${local.environment}-sagemaker-processing"
  image_tag           = var.sagemaker_processing_image_tag
  docker_context_path = abspath("${path.module}/../../docker/sagemaker-processing")
  force_delete        = var.sagemaker_processing_image_force_delete
  tags                = local.common_tags
}

module "sagemaker" {
  source = "../../modules/sagemaker"

  environment                    = local.environment
  git_repository_url             = var.git_repository_url
  git_branch                     = "main"
  enable_unified_studio          = var.enable_sagemaker_unified_studio
  vpc_id                         = var.vpc_id
  subnet_ids                     = local.subnet_ids
  security_group_ids             = [var.existing_security_group_id]
  execution_role_arn             = module.iam.sagemaker_execution_role_arn
  eventbridge_role_arn           = module.iam.eventbridge_glue_role_arn
  data_lake_bucket_name          = module.s3.data_lake_bucket_name
  studio_user_profile_names      = var.sagemaker_studio_user_profile_names
  studio_app_network_access_type = var.sagemaker_studio_app_network_access_type
  studio_space_instance_type     = var.sagemaker_studio_space_instance_type
  studio_space_volume_size_gb    = var.sagemaker_studio_space_volume_size_gb
  enable_studio_notebook_autosync = var.enable_studio_notebook_autosync
  studio_notebook_s3_uri          = var.studio_notebook_s3_uri
  studio_notebook_local_path      = var.studio_notebook_local_path
  enable_notebook_instance        = var.enable_sagemaker_notebook_instance
  notebook_instance_name          = var.sagemaker_notebook_instance_name
  notebook_instance_type          = var.sagemaker_notebook_instance_type
  notebook_volume_size_gb         = var.sagemaker_notebook_volume_size_gb
  notebook_direct_internet_access = var.sagemaker_notebook_direct_internet_access
  notebook_root_access            = var.sagemaker_notebook_root_access
  enable_matching_pipeline        = var.enable_sagemaker_matching_pipeline
  matching_pipeline_schedule_enabled        = var.enable_sagemaker_matching_pipeline_schedule
  matching_pipeline_glue_success_event_enabled = var.enable_sagemaker_matching_pipeline_glue_success_event
  matching_pipeline_trigger_glue_job_name      = module.glue.merged_standardization_job_name
  matching_pipeline_schedule_expression     = var.sagemaker_matching_pipeline_schedule_expression
  matching_pipeline_processing_image_uri    = local.sagemaker_matching_pipeline_processing_image_uri
  matching_pipeline_processing_script_name  = var.sagemaker_matching_pipeline_processing_script_name
  matching_pipeline_runner_script_name      = var.sagemaker_matching_pipeline_runner_script_name
  matching_pipeline_wheelhouse_s3_uri       = var.sagemaker_matching_pipeline_wheelhouse_s3_uri
  matching_pipeline_instance_type           = var.sagemaker_matching_pipeline_instance_type
  matching_pipeline_instance_count          = var.sagemaker_matching_pipeline_instance_count
  matching_pipeline_volume_size_gb          = var.sagemaker_matching_pipeline_volume_size_gb
  matching_pipeline_max_runtime_seconds     = var.sagemaker_matching_pipeline_max_runtime_seconds
  matching_pipeline_standardized_s3_uri     = var.sagemaker_matching_pipeline_standardized_s3_uri
  matching_pipeline_output_s3_uri           = var.sagemaker_matching_pipeline_output_s3_uri
  tags                           = local.common_tags

  depends_on = [terraform_data.manual_baseline_contract, module.iam, module.sagemaker_processing_image]
}

module "quicksight" {
  source = "../../modules/quicksight"

  environment           = local.environment
  enabled               = var.enable_quicksight
  admin_principal_arn   = var.quicksight_admin_principal_arn
  athena_workgroup_name = module.athena.workgroup_name
  glue_catalog_database = module.glue.catalog_database_name
  spice_capacity_gb     = var.quicksight_spice_capacity_gb
  matching_table_name   = "processed_matching"
  dataset_import_mode   = "SPICE"
  tags                  = local.common_tags
}

module "artifacts" {
  source = "../../modules/artifacts"

  environment         = local.environment
  scripts_bucket      = module.s3.data_lake_bucket_name
  artifacts_base_path = "../../artifacts"
  tags                = local.common_tags

  depends_on = [module.s3]
}
