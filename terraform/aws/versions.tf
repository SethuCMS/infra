terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Keep state in an encrypted, versioned S3 bucket with locking. Copy backend.hcl.example to backend.hcl,
  # fill it in, and run:  terraform init -backend-config=backend.hcl
  backend "s3" {}
}

provider "aws" {
  region = var.region

  default_tags {
    tags = merge(
      {
        Project     = "sethucms"
        Environment = var.environment
        ManagedBy   = "terraform"
      },
      var.tags,
    )
  }
}
