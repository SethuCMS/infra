# Two keys with different jobs:
#   vault  protects the secrets customers give us (database passwords, tokens). Only the worker may use it.
#   data   protects everything else at rest: the database, queue, logs, container images, Kubernetes secrets.

resource "aws_kms_key" "vault" {
  description             = "${local.name}: encrypts connection secrets (envelope encryption keys)"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = { Name = "${local.name}-vault" }
}

resource "aws_kms_alias" "vault" {
  name          = "alias/${local.name}-vault"
  target_key_id = aws_kms_key.vault.key_id
}

data "aws_iam_policy_document" "vault_key" {
  # The account's administrators manage the key through normal IAM permissions.
  statement {
    sid       = "AccountAdministration"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }

  # Belt and braces: the API role can never use this key, even if someone grants it permission by mistake.
  statement {
    sid       = "ApiNeverUsesTheVault"
    effect    = "Deny"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey*", "kms:ReEncrypt*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.api.arn]
    }
  }
}

resource "aws_kms_key_policy" "vault" {
  key_id = aws_kms_key.vault.id
  policy = data.aws_iam_policy_document.vault_key.json
}

resource "aws_kms_key" "data" {
  description             = "${local.name}: encrypts data at rest (database, queue, logs, images, Kubernetes secrets)"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = { Name = "${local.name}-data" }
}

resource "aws_kms_alias" "data" {
  name          = "alias/${local.name}-data"
  target_key_id = aws_kms_key.data.key_id
}

data "aws_iam_policy_document" "data_key" {
  statement {
    sid       = "AccountAdministration"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }

  # CloudWatch Logs may encrypt log groups of this account and region with the key.
  statement {
    sid       = "CloudWatchLogs"
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${local.partition}:logs:${var.region}:${local.account_id}:log-group:*"]
    }
  }
}

resource "aws_kms_key_policy" "data" {
  key_id = aws_kms_key.data.id
  policy = data.aws_iam_policy_document.data_key.json
}
