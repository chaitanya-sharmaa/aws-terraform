# ============================================================
# EKS MODULE
# ============================================================
#
# WHAT IS EKS?
# EKS (Elastic Kubernetes Service) is AWS's managed Kubernetes.
# AWS manages the control plane (API server, etcd, scheduler).
# You manage the worker nodes (EC2 instances that run your pods).
#
# KEY CONCEPTS:
# - Control Plane: The "brain" of Kubernetes. Handles scheduling,
#   state management, API requests. You don't see or manage these.
# - Worker Nodes: EC2 instances that actually run your containers.
# - Node Group: A group of EC2 instances managed together.
# - Pod: The smallest K8s unit - contains 1+ containers.
# - Service: Exposes pods to network traffic (internal or external).
#
# COST WARNING:
# EKS control plane = $0.10/hour = $72/month ALWAYS
# Worker nodes (EC2) = varies by instance type
# Run `terraform destroy` when not using the cluster!
#
# IAM ROLES IN EKS:
# AWS uses IAM roles to grant permissions to AWS services.
# 1. Cluster Role:   EKS service assumes this to manage AWS resources
# 2. Node Role:      EC2 instances assume this to join cluster & pull images
# ============================================================

locals {
  cluster_name = "${var.project_name}-${var.environment}"
}

# ════════════════════════════════════════════════════════════
# IAM ROLES — Must be created BEFORE the cluster/nodes
# ════════════════════════════════════════════════════════════

# ── IAM Role: EKS Control Plane ──────────────────────────────
# This role is assumed by the EKS service itself (not by you).
# It gives EKS permission to:
#   - Create/manage ENIs (network interfaces) for pods
#   - Call EC2 APIs (describe instances, VPCs, etc.)
#   - Create/manage load balancers
resource "aws_iam_role" "eks_cluster" {
  name = "${local.cluster_name}-cluster-role"

  # Trust policy: WHO can assume this role?
  # Here: only the EKS service (eks.amazonaws.com)
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${local.cluster_name}-cluster-role"
  }
}

# Attach the AWS-managed policy that grants EKS all required permissions.
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# ── IAM Role: EKS Worker Nodes ───────────────────────────────
# This role is assumed by the EC2 instances (worker nodes).
# It gives nodes permission to:
#   - Register with the EKS cluster (AmazonEKSWorkerNodePolicy)
#   - Manage pod IP addresses (AmazonEKS_CNI_Policy)
#   - Pull container images from ECR (AmazonEC2ContainerRegistryReadOnly)
resource "aws_iam_role" "eks_nodes" {
  name = "${local.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${local.cluster_name}-node-role"
  }
}

# These 3 policies are the MINIMUM required for EKS worker nodes:

# 1. Core worker node permissions (join cluster, describe resources)
resource "aws_iam_role_policy_attachment" "eks_worker_node" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

# 2. VPC CNI plugin permissions (assigns pod IPs from the VPC CIDR)
resource "aws_iam_role_policy_attachment" "eks_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

# 3. ECR read-only access (pull container images)
resource "aws_iam_role_policy_attachment" "eks_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

# 4. AWS Load Balancer Controller — Full IAM policy
# Source: https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
# The LBC needs ~30 actions to create/manage ALBs, listeners, target groups, etc.
# Without this complete policy, the controller silently fails to manage load balancers.
resource "aws_iam_role_policy" "aws_lbc_full" {
  name = "${local.cluster_name}-lbc-full-policy"
  role = aws_iam_role.eks_nodes.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoipPoolUsage",
          "ec2:DescribeCoipPools",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags",
          "elasticloadbalancing:DescribeTrustStores"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:GetSubscriptionState",
          "shield:DescribeProtection",
          "shield:CreateProtection",
          "shield:DeleteProtection"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:CreateSecurityGroup"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:CreateTags"]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          StringEquals = { "ec2:CreateAction" = "CreateSecurityGroup" }
          Null         = { "aws:RequestedRegion" = "false" }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          Null = {
            "aws:RequestedRegion"                   = "false"
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DeleteSecurityGroup"
        ]
        Resource = "*"
        Condition = {
          Null = { "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false" }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup"
        ]
        Resource = "*"
        Condition = {
          Null = { "aws:RequestedRegion" = "false" }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
        Condition = {
          Null = {
            "aws:RequestedRegion"                   = "false"
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:DeleteTargetGroup"
        ]
        Resource = "*"
        Condition = {
          Null = { "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false" }
        }
      },
      {
        Effect = "Allow"
        Action = ["elasticloadbalancing:AddTags"]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
        Condition = {
          StringEquals = {
            "elasticloadbalancing:CreateAction" = ["CreateTargetGroup", "CreateLoadBalancer"]
          }
          Null = { "aws:RequestedRegion" = "false" }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ]
        Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:SetWebAcl",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:AddListenerCertificates",
          "elasticloadbalancing:RemoveListenerCertificates",
          "elasticloadbalancing:ModifyRule"
        ]
        Resource = "*"
      }
    ]
  })
}

# ════════════════════════════════════════════════════════════
# EKS CLUSTER — The Kubernetes Control Plane
# ════════════════════════════════════════════════════════════
resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids = var.subnet_ids

    # Allow kubectl access from specified CIDRs (see eks_public_access_cidrs variable).
    # SECURITY: Set to your IP in dev.tfvars, e.g. ["203.0.113.5/32"]
    endpoint_public_access  = true
    endpoint_private_access = false
    public_access_cidrs     = var.eks_public_access_cidrs
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Enable API and audit logs for security visibility (~$1-2/month).
  # "api"           — all requests to the Kubernetes API server
  # "audit"         — who did what (crucial for security incident response)
  # "authenticator" — IAM auth events
  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  # Cluster must wait for IAM role to be fully configured
  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]

  tags = {
    Name = local.cluster_name
  }
}

# ── EKS Addons (VPC CNI) ─────────────────────────────────────
# We must explicitly manage the VPC CNI addon to enable Prefix Delegation.
# Without this, t3.micro nodes can only run a maximum of 4 pods due to ENI IP limits.
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  configuration_values = jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
    }
  })
}

# ════════════════════════════════════════════════════════════
# EKS NODE GROUP — Your Worker Nodes (EC2 Instances)
# ════════════════════════════════════════════════════════════

data "aws_ssm_parameter" "eks_ami" {
  name = "/aws/service/eks/optimized-ami/${var.kubernetes_version}/amazon-linux-2/recommended/image_id"
}

resource "aws_launch_template" "main" {
  name_prefix = "${local.cluster_name}-node-"
  image_id    = data.aws_ssm_parameter.eks_ami.value

  user_data = base64encode(<<-EOF
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
/etc/eks/bootstrap.sh ${aws_eks_cluster.main.name} \
  --b64-cluster-ca '${aws_eks_cluster.main.certificate_authority[0].data}' \
  --apiserver-endpoint '${aws_eks_cluster.main.endpoint}' \
  --use-max-pods false \
  --kubelet-extra-args '--max-pods=110'
--==MYBOUNDARY==--\
  EOF
  )
}

# A managed node group is the recommended way to run worker nodes.
# AWS handles: node provisioning, patching, AMI updates, drain/cordon.
resource "aws_eks_node_group" "main" {
  cluster_name           = aws_eks_cluster.main.name
  node_group_name_prefix = "${local.cluster_name}-nodes-"
  node_role_arn          = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.subnet_ids

  # EC2 instance type for worker nodes
  # t3.medium: 2 vCPU, 4GB RAM — recommended for Dynamic App + Istio
  # Memory Breakdown (approx):
  # Kube-system daemons:    ~400MB
  # Dynamic App backend:    ~512MB
  # Available headroom:     ~3GB
  instance_types = [var.node_type]

  # Autoscaling configuration
  scaling_config {
    desired_size = var.node_desired
    min_size     = var.node_min
    max_size     = var.node_max
  }

  launch_template {
    id      = aws_launch_template.main.id
    version = aws_launch_template.main.latest_version
  }

  # How to update nodes (ROLLING_UPDATE = update one at a time)
  update_config {
    max_unavailable = 1
  }

  # IMPORTANT: Node group must wait for IAM policies to be attached
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node,
    aws_iam_role_policy_attachment.eks_cni,
    aws_iam_role_policy_attachment.eks_ecr,
  ]

  tags = {
    Name = "${local.cluster_name}-node-group"
  }
}

# ════════════════════════════════════════════════════════════
# ECR REPOSITORY — Docker Image Registry
# ════════════════════════════════════════════════════════════
# ECR (Elastic Container Registry) is AWS's private Docker registry.
# You push your Docker images here, and EKS pulls them to run pods.
#
# Free tier: 500MB/month of storage, 50GB/month of data transfer
resource "aws_ecr_repository" "api" {
  name                 = "${local.cluster_name}/api"
  image_tag_mutability = "MUTABLE" # Allows git-SHA tags to be pushed freely
  force_delete         = true

  # Scan images for known CVEs on push (free, highly recommended)
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${local.cluster_name}-api"
  }
}

# Lifecycle policy: keeps only the last 10 images to save storage.
# With git SHA tagging, images accumulate quickly — keep enough for rollbacks.
resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images for rollback capability"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

# ════════════════════════════════════════════════════════════
# OIDC PROVIDER — For IAM Roles for Service Accounts (IRSA)
# ════════════════════════════════════════════════════════════
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# ════════════════════════════════════════════════════════════
# EKS ACCESS ENTRIES (Fixes "Not authorized" in AWS Console)
# ════════════════════════════════════════════════════════════
data "aws_caller_identity" "current" {}

locals {
  # Only create explicit access entries for EXTRA admins provided in var.eks_admin_arns.
  # The Terraform runner (creator) already gets an entry automatically because 
  # bootstrap_cluster_creator_admin_permissions = true.
  admin_arns = toset(var.eks_admin_arns)
}

resource "aws_eks_access_entry" "admins" {
  for_each      = local.admin_arns
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admins" {
  for_each      = local.admin_arns
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_eks_access_entry.admins[each.key].principal_arn

  access_scope {
    type = "cluster"
  }
}
