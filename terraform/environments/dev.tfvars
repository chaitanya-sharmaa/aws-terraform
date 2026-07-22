# ============================================================
# DEV ENVIRONMENT VARIABLE VALUES
# ============================================================
# This file provides values for the variables defined in variables.tf.
# Use it with:  terraform apply -var-file=environments/dev.tfvars
# ============================================================

project_name = "acme-corp"
environment  = "dev"
aws_region   = "eu-north-1"

# Networking
vpc_cidr = "10.0.0.0/16"

# EKS — t3.small is used because the AWS account restricts non-free-tier/larger instances (t3.medium blocked).
eks_kubernetes_version = "1.30"
eks_node_type          = "t3.micro"
eks_node_desired       = 3
eks_node_min           = 1
eks_node_max           = 3

# EKS API server access — SECURITY: replace with your IP for better protection
# Find your IP: curl ifconfig.me
# Example: eks_public_access_cidrs = ["203.0.113.5/32"]
eks_public_access_cidrs = ["0.0.0.0/0"] # Open for dev convenience

# RDS — no deletion protection in dev (allows `terraform destroy` freely)
rds_deletion_protection = false
