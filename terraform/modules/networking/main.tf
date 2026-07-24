# ============================================================
# NETWORKING MODULE
# ============================================================
# This module creates the network foundation for everything else.
#
# WHAT IS A VPC?
# A VPC (Virtual Private Cloud) is your own isolated section of
# the AWS cloud. Think of it as your own private data center.
# Resources inside talk to each other; outside traffic is controlled.
#
# SUBNET STRATEGY:
#   Public subnets  (10.0.1.x, 10.0.2.x)  — EKS nodes, ALB
#   Private subnets (10.0.11.x, 10.0.12.x) — RDS database
#
# WHY NO NAT GATEWAY?
# A NAT Gateway allows resources in PRIVATE subnets to initiate
# outbound connections (e.g., download packages from the internet)
# without being directly reachable from the internet.
# Cost: ~$32/month — skipped to save money.
# RDS does NOT need internet access, so private subnets work fine.
#
# ARCHITECTURE:
# Internet ←→ Internet Gateway ←→ Public Subnets  ←→ EKS Nodes
#                                  Private Subnets  ←→ RDS (no internet)
# ============================================================

locals {
  cluster_name = "${var.project_name}-${var.environment}"

  # eu-north-1 availability zones
  # EKS REQUIRES at least 2 subnets in DIFFERENT AZs for HA
  # (Even if you run 1 node, the control plane spans multiple AZs)
  azs = [
    "${var.aws_region}a",
    "${var.aws_region}b",
  ]

  # Public subnets — EKS nodes and ALBs live here
  public_subnet_cidrs = [
    cidrsubnet(var.vpc_cidr, 8, 1), # 10.0.1.0/24
    cidrsubnet(var.vpc_cidr, 8, 2), # 10.0.2.0/24
  ]

  # Private subnets — RDS database lives here (no internet route)
  private_subnet_cidrs = [
    cidrsubnet(var.vpc_cidr, 8, 11), # 10.0.11.0/24
    cidrsubnet(var.vpc_cidr, 8, 12), # 10.0.12.0/24
  ]
}

# ── VPC ──────────────────────────────────────────────────────
# The VPC is your network boundary. All resources go inside here.
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # Both required for EKS to work:
  enable_dns_support   = true # Allows DNS resolution within VPC
  enable_dns_hostnames = true # Gives EC2 instances DNS hostnames

  tags = {
    Name = "${local.cluster_name}-vpc"
  }
}

# ── Internet Gateway ──────────────────────────────────────────
# The IGW is the "door" between your VPC and the internet.
# Without it, nothing in your VPC can reach the internet.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.cluster_name}-igw"
  }
}

# ── Public Subnets ────────────────────────────────────────────
# Subnets are segments of your VPC's IP range.
# PUBLIC = resources here can have public IPs and reach internet.
#
# count = 2 means Terraform creates 2 subnets, one per AZ.
# count.index is 0 for the first, 1 for the second.
resource "aws_subnet" "public" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.public_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  # New EC2 instances in this subnet automatically get a public IP
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.cluster_name}-public-${count.index + 1}"

    # ── EKS-Required Tags ────────────────────────────────────
    # These tags tell the AWS Load Balancer Controller which subnets
    # it can use when creating Load Balancers for Kubernetes Services.
    #
    # "shared" = multiple EKS clusters can use this subnet
    # "owned"  = only this cluster uses this subnet (exclusive)
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1" # For internet-facing LBs
  }

  depends_on = [
    aws_internet_gateway.main
  ]
}

# ── Private Subnets ───────────────────────────────────────────
# PRIVATE = no route to the internet. Resources here are isolated.
# Used for RDS so the database is never directly reachable from outside.
# EKS nodes can still reach RDS because they share the same VPC.
resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  # No public IP — these are private resources
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.cluster_name}-private-${count.index + 1}"

    # Tag for internal load balancers (if ever needed)
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

# ── Public Route Table ────────────────────────────────────────
# A route table contains rules (routes) for network traffic.
# This one says: "send all internet traffic (0.0.0.0/0) to the IGW"
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"                  # All traffic
    gateway_id = aws_internet_gateway.main.id # Goes through IGW
  }

  tags = {
    Name = "${local.cluster_name}-public-rt"
  }
}

# Associate each public subnet with the public route table.
# Without this, subnets use the default "local only" route table.
resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── Private Route Table ───────────────────────────────────────
# Private subnets only have a "local" route — traffic stays in the VPC.
# No route to the IGW = no internet access (by design for RDS).
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # No internet route — local VPC traffic only (implicit)
  tags = {
    Name = "${local.cluster_name}-private-rt"
  }
}

# Associate each private subnet with the private route table.
resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
