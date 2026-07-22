# ============================================================
# INPUT VARIABLES
# ============================================================
# Variables make your Terraform reusable across environments.
# Values come from: CLI flags, .tfvars files, or env vars.
#
# Priority order (highest to lowest):
# 1. -var flag:      terraform apply -var="project_name=foo"
# 2. .tfvars file:   terraform apply -var-file=dev.tfvars
# 3. TF_VAR_ env:    export TF_VAR_project_name=foo
# 4. Default value:  defined below
# ============================================================

# ── Project Identity ──────────────────────────────────────────
variable "project_name" {
  description = "Project name, used as a prefix for all resource names (e.g. acme-corp-dev-vpc)"
  type        = string
  default     = "acme-corp"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,20}$", var.project_name))
    error_message = "project_name must be 2-20 lowercase letters, numbers, or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment. Used in resource names and tags."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region to deploy all resources"
  type        = string
  default     = "eu-north-1" # Stockholm
}

# ── Networking ────────────────────────────────────────────────
variable "vpc_cidr" {
  description = <<-EOT
    CIDR block for the VPC.
    10.0.0.0/16 gives you 65,536 IP addresses.
    Public subnets  (/24 = 256 IPs): 10.0.1.x, 10.0.2.x  — EKS nodes
    Private subnets (/24 = 256 IPs): 10.0.11.x, 10.0.12.x — RDS
  EOT
  type        = string
  default     = "10.0.0.0/16"
}

# ── EKS Cluster ───────────────────────────────────────────────
variable "eks_kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.30"
}

variable "eks_node_type" {
  description = <<-EOT
    EC2 instance type for EKS worker nodes.
    t3.medium = 2 vCPU, 4GB RAM — recommended minimum for Dynamic App + Istio sidecars.
    Kubernetes system pods use ~400MB, Istio ~128MB/pod, Dynamic App ~512MB.
    t3.micro (1GB) will OOM with Istio enabled.
  EOT
  type        = string
  default     = "t3.micro"
}

variable "eks_node_desired" {
  description = "Desired number of EKS worker nodes (what it tries to maintain)"
  type        = number
  default     = 2
}

variable "eks_node_min" {
  description = "Minimum number of EKS worker nodes (autoscaler won't go below this)"
  type        = number
  default     = 1
}

variable "eks_node_max" {
  description = "Maximum number of EKS worker nodes (autoscaler won't go above this)"
  type        = number
  default     = 2
}

variable "eks_public_access_cidrs" {
  description = <<-EOT
    CIDRs allowed to reach the EKS public API endpoint (kubectl).
    SECURITY: Restrict to your IP address in non-dev environments.
    Example: ["203.0.113.5/32"]
    Default: ["0.0.0.0/0"] — open to all (acceptable for dev only).
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ── RDS Database ──────────────────────────────────────────────
variable "rds_deletion_protection" {
  description = "Prevent accidental deletion of the RDS instance. Set true for production."
  type        = bool
  default     = false
}

variable "eks_admin_arns" {
  type    = list(string)
  default = []
}

