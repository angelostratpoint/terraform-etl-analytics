locals {
  environment = var.environment
  subnet_ids  = distinct(compact(concat([var.subnet_id], var.subnet_ids)))
  common_tags = {
    Project     = "CDCU"
    Environment = local.environment
    ManagedBy   = "Terraform"
    Owner       = "Stratpoint"
    CostCenter  = "CDCU-PRE-PROD"
  }

  # IAM role ARN resolution:
  # When manage_iam = true  → use ARNs from the IAM module (Terraform-managed)
  # When manage_iam = false → use pre-existing ARNs provided as variables (manually managed)
  # This supports Task 3.2 of the implementation plan where IAM is set up manually
  # before the Terraform scripts run (Tasks 3.3+).
  glue_execution_role_arn      = var.manage_iam ? module.iam[0].glue_execution_role_arn : var.existing_glue_execution_role_arn
  sagemaker_execution_role_arn = var.manage_iam ? module.iam[0].sagemaker_execution_role_arn : var.existing_sagemaker_execution_role_arn
}

module "kms" {
  count  = var.enable_kms ? 1 : 0
  source = "../../modules/kms"

  environment = local.environment
  # Pass the service execution role ARNs so the KMS key policy grants them usage.
  # The dynamic statement in the KMS module handles the empty-list case safely.
  allowed_role_arns = var.enable_kms ? [
    local.glue_execution_role_arn,
    local.sagemaker_execution_role_arn,
  ] : []
  tags = local.common_tags

  depends_on = [module.iam]
}

# IAM module is optional — only runs when manage_iam = true.
# When manage_iam = false (default), IAM roles are created manually per Task 3.2
# and their ARNs are passed in via existing_*_role_arn variables.
module "iam" {
  count  = var.manage_iam ? 1 : 0
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
  recovery_window_in_days = 7
  enable_rotation         = false
  tags                    = local.common_tags
}

module "cloudwatch" {
  source = "../../modules/cloudwatch"

  environment        = local.environment
  log_retention_days = 30
  enable_kms         = var.enable_kms
  kms_key_arn        = var.enable_kms ? module.kms[0].kms_key_arn : ""
  sns_topic_arn      = var.sns_topic_arn
  tags               = local.common_tags
}

module "glue" {
  source = "../../modules/glue"

  environment             = local.environment
  glue_execution_role_arn = local.glue_execution_role_arn
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
  execution_role_arn             = local.sagemaker_execution_role_arn
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
