# ============================================================
# PRODUCTION ENVIRONMENT VARIABLE VALUES
# ============================================================
# Use with:  terraform apply -var-file=environments/prod.tfvars
#
# Production differences vs dev:
#   - Larger node instance (t3.large for more headroom)
#   - EKS endpoint locked to specific CIDRs
#   - RDS deletion protection enabled
#   - Multi-AZ layout (inherent via 2 private subnets in different AZs)
# ============================================================

project_name = "acme-corp"
environment  = "prod"
aws_region   = "eu-north-1"

# Networking
vpc_cidr = "10.0.0.0/16"

# EKS — larger nodes for production load and Istio overhead
eks_kubernetes_version = "1.30"
eks_node_type          = "t3.large" # 2 vCPU, 8GB RAM
eks_node_desired       = 2          # At least 2 nodes for availability
eks_node_min           = 2
eks_node_max           = 4

# EKS API server access — LOCKED to specific CIDRs in production
# Replace with your office/home/VPN IP addresses
# Example: eks_public_access_cidrs = ["203.0.113.5/32", "198.51.100.0/24"]
eks_public_access_cidrs = ["0.0.0.0/0"] # TODO: Replace with your IP before applying!

# RDS — deletion protection ON in production
# To destroy prod RDS: first set this to false and apply, THEN destroy
rds_deletion_protection = true
