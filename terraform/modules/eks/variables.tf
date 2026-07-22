variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where EKS will be deployed"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC — used to scope the internal ALB security group ingress rule"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for EKS nodes (must be in 2+ different AZs)"
  type        = list(string)
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.30"
}

variable "node_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.micro"
}

variable "node_desired" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 1
}

variable "node_min" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 2
}

variable "eks_public_access_cidrs" {
  description = <<-EOT
    List of CIDR blocks allowed to reach the EKS public API server endpoint.
    SECURITY: Restrict to your IP in production, e.g. ["203.0.113.5/32"].
    Default ["0.0.0.0/0"] keeps it open (acceptable for dev, not prod).
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "eks_admin_arns" {
  type    = list(string)
  default = []
}

