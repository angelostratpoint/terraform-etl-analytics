###############################################################################
# Module: KMS
# Purpose: Provisions a customer-managed KMS key for CDCU data encryption.
###############################################################################

resource "aws_kms_key" "cdcu_cmk" {
  description             = "CDCU ${var.environment} customer-managed key for data encryption"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true

  policy = data.aws_iam_policy_document.kms_key_policy.json

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-cmk"
  })
}

resource "aws_kms_alias" "cdcu_cmk_alias" {
  name          = "alias/cdcu-${var.environment}-cmk"
  target_key_id = aws_kms_key.cdcu_cmk.key_id
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "kms_key_policy" {
  # Allow root account full key administration
  statement {
    sid    = "AllowRootAccountAdministration"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Allow CDCU IAM roles to use the key — only rendered when role ARNs are provided.
  # When allowed_role_arns is empty (e.g. during initial bootstrap before IAM roles exist),
  # this statement is omitted to avoid an invalid empty-principal key policy error.
  dynamic "statement" {
    for_each = length(var.allowed_role_arns) > 0 ? [1] : []
    content {
      sid    = "AllowCDCURoleKeyUsage"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.allowed_role_arns
      }
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
      ]
      resources = ["*"]
    }
  }

  # Allow CloudWatch Logs service to use the key
  statement {
    sid    = "AllowCloudWatchLogsKeyUsage"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.ap-southeast-1.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
  }
}
