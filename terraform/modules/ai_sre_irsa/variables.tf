variable "cluster_oidc_provider_arn" {
  description = "The OIDC provider ARN for the EKS cluster (e.g. arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE)"
  type        = string
}

variable "namespace" {
  description = "The Kubernetes namespace where the SRE agent is deployed"
  type        = string
  default     = "sre-system"
}

variable "service_account_name" {
  description = "The Kubernetes service account name for the SRE agent"
  type        = string
  default     = "ai-sre-agent-sa"
}
