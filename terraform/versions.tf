# ============================================================
# TERRAFORM & PROVIDER VERSIONS
# ============================================================
# Pinning versions ensures your infrastructure is reproducible.
# Always commit this file to git - it's the contract that says
# "this project works with THESE exact versions".
# ============================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    # AWS provider - the main one we use for all AWS resources
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # ~> means ">= 5.0.0, < 6.0.0"
    }

    # Random provider - used to generate unique S3 bucket name suffix
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }

  # Remote state backend (S3 + native state locking)
  backend "s3" {
    # Replace this with the exact bucket name output by the bootstrap module
    bucket       = "acme-corp-terraform-state-e31e6482"
    key          = "acme-corp/dev/terraform.tfstate"
    region       = "eu-north-1"
    use_lockfile = true
    encrypt      = true
  }
}

# ── AWS Provider Configuration ────────────────────────────────
provider "aws" {
  region = var.aws_region

  # Default tags applied to EVERY resource automatically
  # This is a best practice - makes cost tracking and cleanup easy
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      # You can add more tags like Team, CostCenter, etc.
    }
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    command     = "aws"
  }
}
