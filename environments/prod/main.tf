locals {
  environment = var.environment
  subnet_ids  = distinct(compact(concat([var.subnet_id], var.subnet_ids)))
  kms_key_arn = var.enable_kms ? var.existing_kms_key_arn : ""
  common_tags = {
    Project     = "CDCU"
    Environment = local.environment
    ManagedBy   = "Terraform"
    Owner       = "Stratpoint"
    CostCenter  = "CDCU-PROD"
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
  }
}

module "s3" {
  source = "../../modules/s3"

  environment = local.environment
  enable_kms  = var.enable_kms
  kms_key_arn = local.kms_key_arn
  tags        = local.common_tags
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
  glue_worker_count       = var.glue_worker_count
  glue_worker_type        = var.glue_worker_type
  microsite_jdbc_url      = var.microsite_jdbc_url
  legacy_jdbc_url         = var.legacy_jdbc_url
  tags                    = local.common_tags

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
  studio_user_profile_names      = var.sagemaker_studio_user_profile_names
  studio_app_network_access_type = var.sagemaker_studio_app_network_access_type
  studio_space_instance_type     = var.sagemaker_studio_space_instance_type
  studio_space_volume_size_gb    = var.sagemaker_studio_space_volume_size_gb
  tags                           = local.common_tags

  depends_on = [terraform_data.manual_baseline_contract, module.iam]
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
