# ============================================================
# OUTPUTS
# ============================================================




# ── Backend (EKS) ─────────────────────────────────────────────
output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "ecr_repository_url" {
  description = "ECR repository URL base"
  value       = module.eks.ecr_repository_url
}

output "configure_kubectl" {
  description = "Command to connect kubectl to your EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "ai_sre_role_arn" {
  description = "IAM Role ARN for the AI SRE Agent"
  value       = module.ai_sre_irsa.iam_role_arn
}

# ── Database (RDS) ────────────────────────────────────────────
output "db_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = module.rds.db_endpoint
}

output "db_username" {
  description = "The master username for the database"
  value       = module.rds.db_username
}

output "db_password" {
  description = "The generated password for the database"
  value       = module.rds.db_password
  sensitive   = true
}

# ── Cost Reminder ─────────────────────────────────────────────
output "cost_reminder" {
  description = "Cost reminder"
  value       = "⚠️  EKS control plane costs $0.10/hr (~$72/mo). Run 'terraform destroy' when not using the cluster!"
}

output "static_app_bucket_name" {
  description = "The S3 bucket name for the static frontend"
  value       = module.static_app_frontend.bucket_name
}

output "static_app_cloudfront_domain" {
  description = "The CloudFront URL for the static app"
  value       = "https://${module.static_app_frontend.cloudfront_domain}"
}

output "static_app_cloudfront_id" {
  description = "The CloudFront distribution ID"
  value       = module.static_app_frontend.distribution_id
}

output "sre_dashboard_url" {
  description = "The CloudFront URL for the AI SRE Dashboard"
  value       = "https://${module.sre_dashboard_cloudfront.cloudfront_domain}"
}
