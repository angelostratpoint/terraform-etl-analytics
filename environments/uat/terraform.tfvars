# BPI-MS UAT values.
# Never commit database passwords or secret values to source control.

environment = "uat"

terraform_role_arn = ""

# BPI-MS UAT VPC and CDCU network outputs.
vpc_id    = "vpc-0098b00f9a1188ecc"
subnet_id = "subnet-098c1f13897c7f4b1"
subnet_ids = [
  "subnet-098c1f13897c7f4b1",
]

availability_zone = "ap-southeast-1a"

github_org  = ""
github_repo = "cdcu"

sso_principal_arns = []

# KMS is typically disabled in lower environments. If enabled, provide existing_kms_key_arn.
enable_kms    = false
sns_topic_arn = ""

data_lake_bucket_name      = "cdcu-uat-data-lake"
athena_results_bucket_name = "cdcu-uat-athena-results"

glue_worker_count = 2
glue_worker_type  = "G.1X"

# BPI-MS merged source DB used by the single CDCU Glue JDBC connection.
# Replace the endpoint with the approved UAT MySQL RDS endpoint before apply.
merged_jdbc_url              = "jdbc:mysql://merged-rds-endpoint.example.com:3306/cdcu_db?useSSL=false&allowPublicKeyRetrieval=true"
merged_mysql_secret_name     = "cdcu/uat/merged-mysql-connection"
mysql_jdbc_driver_class_name = ""
mysql_jdbc_driver_jar_uri    = ""

git_repository_url = "https://git-codecommit.ap-southeast-1.amazonaws.com/v1/repos/cdcu"

enable_sagemaker_unified_studio = true
sagemaker_studio_user_profile_names = [
  "data-engineer-01",
]
sagemaker_studio_space_instance_type     = "ml.t3.medium"
sagemaker_studio_space_volume_size_gb    = 5
sagemaker_studio_app_network_access_type = "VpcOnly"

# SageMaker Studio and JupyterLab are the approved UAT path. Keep the classic
# notebook disabled to avoid the previous notebook security-group failure.
enable_sagemaker_notebook_instance        = false
sagemaker_notebook_instance_name          = "cdcu-uat-notebook"
sagemaker_notebook_instance_type          = "ml.t3.medium"
sagemaker_notebook_volume_size_gb         = 5
sagemaker_notebook_direct_internet_access = "Disabled"
sagemaker_notebook_root_access            = "Disabled"

enable_quicksight              = false
quicksight_admin_principal_arn = ""
quicksight_spice_capacity_gb   = 10

# IAM/RBAC is managed by the modules/iam module using the ST-CDCU prefix.
# manage_iam is a deprecated compatibility flag and has no effect.
manage_iam                = false
terraform_lock_table_name = "cdcu-terraform-locks-uat"

# Client-managed baseline inputs from BPI MS / manual setup.
existing_quicksight_access_role_arn = ""
existing_kms_key_arn                = ""
existing_security_group_id          = "sg-0d05b2c99c794ca51"
