data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  repository_url = var.enabled ? aws_ecr_repository.processing[0].repository_url : ""
  image_uri      = var.enabled ? "${local.repository_url}:${var.image_tag}" : ""
  local_image    = "${var.repository_name}:${var.image_tag}"
}

resource "aws_ecr_repository" "processing" {
  count = var.enabled ? 1 : 0

  name                 = var.repository_name
  image_tag_mutability = "MUTABLE"
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, {
    Name = var.repository_name
  })
}

resource "terraform_data" "build_and_push" {
  count = var.enabled && var.build_and_push ? 1 : 0

  input = {
    repository_url = local.repository_url
    image_uri      = local.image_uri
    dockerfile_md5 = filemd5("${var.docker_context_path}/Dockerfile")
    image_tag      = var.image_tag
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      aws ecr get-login-password --region ${data.aws_region.current.name} \
        | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com

      docker build -t ${local.local_image} "${var.docker_context_path}"
      docker tag ${local.local_image} ${local.image_uri}
      docker push ${local.image_uri}
    EOT
  }

  depends_on = [aws_ecr_repository.processing]
}
