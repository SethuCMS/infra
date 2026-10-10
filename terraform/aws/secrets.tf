# Containers for application secrets. Terraform creates the empty containers; you put the values in by hand,
# so the values never appear in Terraform state:
#
#   aws secretsmanager put-secret-value --secret-id sethucms/<env>/app/session-secret --secret-string "$(openssl rand -base64 48)"
#   aws secretsmanager put-secret-value --secret-id sethucms/<env>/app/database-url   --secret-string "postgres://..."
#
# The cluster reads them with the External Secrets Operator (see k8s/examples/external-secret.yaml).

resource "aws_secretsmanager_secret" "app" {
  for_each                = toset(["session-secret", "database-url"])
  name                    = "${local.secrets_prefix}/app/${each.key}"
  kms_key_id              = aws_kms_key.data.arn
  recovery_window_in_days = 30
}

# Where customers' own connection secrets can be kept, if a customer prefers Secrets Manager over the built-in vault.
# Only the worker may read this prefix (see iam.tf).
