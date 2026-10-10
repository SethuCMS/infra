output "egress_ip_addresses" {
  description = "Fixed public addresses the worker connects from. Customers add these to their database allowlists."
  value       = aws_eip.nat[*].public_ip
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "Use in k8s overlays (NetworkPolicy ipBlock) so pods can reach the database and private endpoints."
  value       = var.vpc_cidr
}

output "database_subnet_cidrs" {
  value = local.database_subnet_cidrs
}

output "cluster_name" {
  description = "Run: aws eks update-kubeconfig --name <this value>"
  value       = aws_eks_cluster.main.name
}

output "api_role_arn" {
  description = "Put in the api ServiceAccount annotation (eks.amazonaws.com/role-arn)."
  value       = aws_iam_role.api.arn
}

output "worker_role_arn" {
  description = "Put in the worker ServiceAccount annotation. Customers trust this role in their cross-account roles."
  value       = aws_iam_role.worker.arn
}

output "vault_key_arn" {
  description = "Value for KMS_KEY_REF."
  value       = aws_kms_key.vault.arn
}

output "queue_url" {
  description = "Value for QUEUE_URL."
  value       = aws_sqs_queue.jobs.url
}

output "database_endpoint" {
  value = aws_db_instance.control_plane.address
}

output "database_admin_secret_arn" {
  description = "Where AWS keeps the database admin password. Use it once to create a limited application user, then stop using it."
  value       = aws_db_instance.control_plane.master_user_secret[0].secret_arn
}

output "app_secret_arns" {
  description = "Containers to fill in with aws secretsmanager put-secret-value."
  value       = { for name, secret in aws_secretsmanager_secret.app : name => secret.arn }
}

output "ecr_repository_urls" {
  value = { for name, repo in aws_ecr_repository.app : name => repo.repository_url }
}
