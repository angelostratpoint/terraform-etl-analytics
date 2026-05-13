locals {
  environment = var.environment
  subnet_ids  = distinct(compact(concat([var.subnet_id], var.subnet_ids)))
  common_tags = {
    Project     = "CDCU"
    Environment = local.environment
    ManagedBy   = "Terraform"
    Owner       = "Stratpoint"
    CostCenter  = "CDCU-PROD"
  }
}

module "kms" {
  count  = var.enable_kms ? 1 : 0
  source = "../../modules/kms"

  environment       = local.environment
  allowed_role_arns = []
  tags              = local.common_tags
}

module "iam" {
  source = "../../modules/iam"

  environment        = local.environment
  enable_kms         = var.enable_kms
  kms_key_arn        = var.enable_kms ? module.kms[0].kms_key_arn : ""
  sso_principal_arns = var.sso_principal_arns
  github_org         = var.github_org
  github_repo        = var.github_repo
  tags               = local.common_tags
}

module "security_groups" {
  source = "../../modules/security_groups"

  environment = local.environment
  vpc_id      = var.vpc_id
  tags        = local.common_tags
}

module "s3" {
  source = "../../modules/s3"

  environment = local.environment
  enable_kms  = var.enable_kms
  kms_key_arn = var.enable_kms ? module.kms[0].kms_key_arn : ""
  tags        = local.common_tags
}

module "secrets_manager" {
  source = "../../modules/secrets_manager"

  environment             = local.environment
  enable_kms              = var.enable_kms
  kms_key_arn             = var.enable_kms ? module.kms[0].kms_key_arn : ""
  recovery_window_in_days = 30
  enable_rotation         = true
  tags                    = local.common_tags
}

module "cloudwatch" {
  source = "../../modules/cloudwatch"

  environment        = local.environment
  log_retention_days = 90
  enable_kms         = var.enable_kms
  kms_key_arn        = var.enable_kms ? module.kms[0].kms_key_arn : ""
  sns_topic_arn      = var.sns_topic_arn
  tags               = local.common_tags
}

module "glue" {
  source = "../../modules/glue"

  environment             = local.environment
  glue_execution_role_arn = module.iam.glue_execution_role_arn
  data_lake_bucket        = module.s3.data_lake_bucket_name
  scripts_bucket          = module.s3.data_lake_bucket_name
  glue_security_group_ids = [module.security_groups.glue_security_group_id]
  subnet_id               = var.subnet_id
  availability_zone       = var.availability_zone
  glue_worker_count       = var.glue_worker_count
  glue_worker_type        = var.glue_worker_type
  tags                    = local.common_tags

  depends_on = [module.secrets_manager]
}

module "athena" {
  source = "../../modules/athena"

  environment           = local.environment
  athena_results_bucket = module.s3.athena_results_bucket_name
  glue_catalog_database = module.glue.catalog_database_name
  enable_kms            = var.enable_kms
  kms_key_arn           = var.enable_kms ? module.kms[0].kms_key_arn : ""
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
  security_group_ids             = [module.security_groups.glue_security_group_id]
  execution_role_arn             = module.iam.sagemaker_execution_role_arn
  studio_user_profile_names      = var.sagemaker_studio_user_profile_names
  studio_app_network_access_type = var.sagemaker_studio_app_network_access_type
  notebook_instance_count        = var.sagemaker_notebook_instance_count
  notebook_instance_type         = var.sagemaker_notebook_instance_type
  tags                           = local.common_tags
}

module "quicksight" {
  source = "../../modules/quicksight"

  environment             = local.environment
  enabled                 = var.enable_quicksight
  admin_principal_arn     = var.quicksight_admin_principal_arn
  athena_workgroup_name   = module.athena.workgroup_name
  glue_catalog_database   = module.glue.catalog_database_name
  spice_capacity_gb       = var.quicksight_spice_capacity_gb
  matching_table_name     = "processed_matching"
  dataset_import_mode     = "SPICE"
  tags                    = local.common_tags
}

module "artifacts" {
  source = "../../modules/artifacts"

  environment         = local.environment
  scripts_bucket      = module.s3.data_lake_bucket_name
  artifacts_base_path = "../../artifacts"
  tags                = local.common_tags

  depends_on = [module.s3]
}
