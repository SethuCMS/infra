# Separate cloud identities for the API and the worker, so each can do only its own job.
#   api     send jobs to the queue; read its own application secrets. Cannot use the vault key.
#   worker  everything the API can, plus: use the vault key, read connection secrets, and assume customers' roles.

locals {
  oidc_provider_arn = aws_iam_openid_connect_provider.eks.arn
  oidc_issuer       = replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")
}

data "aws_iam_policy_document" "api_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${var.kubernetes_namespace}:api"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "worker_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${var.kubernetes_namespace}:worker"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api" {
  name               = "${local.name}-api"
  assume_role_policy = data.aws_iam_policy_document.api_trust.json
}

resource "aws_iam_role" "worker" {
  name               = "${local.name}-worker"
  assume_role_policy = data.aws_iam_policy_document.worker_trust.json
}

# ---- API ------------------------------------------------------------------------------------------

data "aws_iam_policy_document" "api" {
  statement {
    sid       = "SendJobs"
    actions   = ["sqs:SendMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"]
    resources = [aws_sqs_queue.jobs.arn]
  }

  statement {
    sid       = "ReadOwnSecrets"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [for secret in aws_secretsmanager_secret.app : secret.arn]
  }

  # Needed to send encrypted queue messages and read secrets encrypted with the data key. Not the vault key.
  statement {
    sid       = "UseDataKey"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [aws_kms_key.data.arn]
  }
}

resource "aws_iam_role_policy" "api" {
  name   = "api"
  role   = aws_iam_role.api.id
  policy = data.aws_iam_policy_document.api.json
}

# ---- worker ---------------------------------------------------------------------------------------

data "aws_iam_policy_document" "worker" {
  statement {
    sid       = "ReceiveJobs"
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:ChangeMessageVisibility", "sqs:GetQueueAttributes", "sqs:GetQueueUrl", "sqs:SendMessage"]
    resources = [aws_sqs_queue.jobs.arn]
  }

  statement {
    sid       = "UseVaultKey"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [aws_kms_key.vault.arn]
  }

  statement {
    sid       = "UseDataKey"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [aws_kms_key.data.arn]
  }

  statement {
    sid       = "ReadSecrets"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = ["arn:${local.partition}:secretsmanager:${var.region}:${local.account_id}:secret:${local.secrets_prefix}/*"]
  }

  # Cross-account access to customer clouds. Each customer creates a role named <prefix>... that trusts this role and
  # requires an external id. We can only ever assume roles with that name prefix.
  statement {
    sid       = "AssumeCustomerRoles"
    actions   = ["sts:AssumeRole"]
    resources = ["arn:${local.partition}:iam::*:role/${var.customer_role_name_prefix}*"]
  }
}

resource "aws_iam_role_policy" "worker" {
  name   = "worker"
  role   = aws_iam_role.worker.id
  policy = data.aws_iam_policy_document.worker.json
}
