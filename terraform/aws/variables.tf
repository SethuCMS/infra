variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Name of this deployment."
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be \"staging\" or \"production\"."
  }
}

variable "tags" {
  description = "Extra tags for every resource."
  type        = map(string)
  default     = {}
}

# ---- network -------------------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "Address range of the VPC. Must be a /16."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && endswith(var.vpc_cidr, "/16")
    error_message = "vpc_cidr must be a valid /16 range such as 10.0.0.0/16."
  }
}

variable "az_count" {
  description = "How many availability zones to use (2 for staging, 3 for production)."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "enable_vpc_endpoints" {
  description = "Private connections to KMS, SQS, STS, Secrets Manager and ECR, so that traffic to them never leaves the VPC."
  type        = bool
  default     = true
}

# ---- kubernetes ----------------------------------------------------------------------------------

variable "kubernetes_version" {
  description = "EKS version."
  type        = string
  default     = "1.30"
}

variable "cluster_endpoint_public_access" {
  description = "Whether the Kubernetes API is reachable from the internet (restricted to cluster_public_access_cidrs). Off means you need a VPN or bastion."
  type        = bool
  default     = false
}

variable "cluster_public_access_cidrs" {
  description = "Who may reach the Kubernetes API when public access is on. Never use 0.0.0.0/0."
  type        = list(string)
  default     = []

  validation {
    condition     = !contains(var.cluster_public_access_cidrs, "0.0.0.0/0")
    error_message = "Do not open the Kubernetes API to the whole internet."
  }
}

variable "node_instance_types" {
  description = "Machine types for worker nodes."
  type        = list(string)
  default     = ["t3.large"]
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 6
}

variable "node_desired_size" {
  type    = number
  default = 2
}

# ---- control-plane database ----------------------------------------------------------------------

variable "db_instance_class" {
  type    = string
  default = "db.t4g.medium"
}

variable "db_engine_version" {
  description = "PostgreSQL version."
  type        = string
  default     = "16.4"
}

variable "db_allocated_storage_gb" {
  type    = number
  default = 50
}

variable "db_max_allocated_storage_gb" {
  description = "Storage grows automatically up to this size."
  type        = number
  default     = 200
}

variable "db_multi_az" {
  description = "Keep a standby copy in another zone. Turn on for production."
  type        = bool
  default     = false
}

variable "db_backup_retention_days" {
  type    = number
  default = 14
}

variable "deletion_protection" {
  description = "Refuse to delete the database and keys by accident. Turn off only to tear down a throwaway environment."
  type        = bool
  default     = true
}

# ---- access to customer clouds -------------------------------------------------------------------

variable "customer_role_name_prefix" {
  description = "Customers create a role whose name starts with this prefix and trust the worker role, with an external id. The worker may assume only roles with this prefix."
  type        = string
  default     = "sethucms-access-"
}

variable "kubernetes_namespace" {
  description = "Namespace the application runs in (must match k8s/base/namespace.yaml)."
  type        = string
  default     = "sethucms"
}
