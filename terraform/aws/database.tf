# The control-plane database: the CMS's own metadata (tenants, connections, permissions, audit log).
# It is not where customer content lives; that stays in the customers' own databases.

resource "aws_db_subnet_group" "main" {
  name       = local.name
  subnet_ids = aws_subnet.database[*].id
}

resource "aws_security_group" "database" {
  name        = "${local.name}-database"
  description = "PostgreSQL from the Kubernetes nodes only"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "database_from_nodes" {
  security_group_id            = aws_security_group.database.id
  description                  = "PostgreSQL from the Kubernetes nodes"
  referenced_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_db_parameter_group" "main" {
  name   = local.name
  family = "postgres16"

  # Refuse connections that are not encrypted.
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "immediate"
  }
  parameter {
    name  = "log_connections"
    value = "1"
  }
  parameter {
    name  = "log_disconnections"
    value = "1"
  }
  parameter {
    name  = "log_statement"
    value = "ddl"
  }
}

resource "aws_db_instance" "control_plane" {
  identifier     = "${local.name}-control-plane"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  db_name  = "sethucms"
  username = "sethucms_admin"

  # AWS creates the admin password, keeps it in Secrets Manager and rotates it. It never appears in Terraform state or files.
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.data.arn

  allocated_storage     = var.db_allocated_storage_gb
  max_allocated_storage = var.db_max_allocated_storage_gb
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.data.arn

  multi_az               = var.db_multi_az
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = false
  parameter_group_name   = aws_db_parameter_group.main.name

  iam_database_authentication_enabled = true
  auto_minor_version_upgrade          = true

  backup_retention_period = var.db_backup_retention_days
  backup_window           = "02:00-03:00"
  maintenance_window      = "sun:03:30-sun:04:30"
  copy_tags_to_snapshot   = true

  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.data.arn
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.name}-control-plane-final"

  depends_on = [aws_kms_key_policy.data]
}
