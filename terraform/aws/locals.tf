data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name       = "sethucms-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  azs        = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # The /16 is cut into sixteen /20 pieces: public subnets, then private (application) subnets, then database subnets.
  public_subnet_cidrs   = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, 4 + i)]
  database_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, 8 + i)]

  # Secrets for the application are kept under this prefix in Secrets Manager.
  secrets_prefix = "sethucms/${var.environment}"
}
