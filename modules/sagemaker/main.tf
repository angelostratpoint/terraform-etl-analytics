locals {
  notebook_instance_name = var.notebook_instance_name != "" ? var.notebook_instance_name : "cdcu-${var.environment}-notebook"
  notebook_subnet_id     = length(var.subnet_ids) > 0 ? var.subnet_ids[0] : null
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
