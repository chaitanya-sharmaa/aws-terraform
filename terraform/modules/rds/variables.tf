variable "cluster_name" {
  description = "Name of the EKS cluster (used for tagging)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the RDS instance will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs for the RDS subnet group (should be private subnets)"
  type        = list(string)
}

variable "eks_nodes_sg_id" {
  description = "Security Group ID of the EKS nodes to allow inbound traffic to RDS"
  type        = string
}

variable "deletion_protection" {
  description = "Prevent accidental deletion of the RDS instance. Set true for production."
  type        = bool
  default     = false
}
