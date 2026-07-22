# ============================================================
# ROOT MODULE — MAIN ENTRYPOINT
# ============================================================

# ── Networking Module ─────────────────────────────────────────
module "networking" {
  source = "./modules/networking"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  aws_region   = var.aws_region
}

# ── EKS Module ───────────────────────────────────────────────
module "eks" {
  source = "./modules/eks"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
  vpc_id       = module.networking.vpc_id
  vpc_cidr     = module.networking.vpc_cidr
  subnet_ids   = module.networking.public_subnet_ids

  kubernetes_version      = var.eks_kubernetes_version
  node_type               = var.eks_node_type
  node_desired            = var.eks_node_desired
  node_min                = var.eks_node_min
  node_max                = var.eks_node_max
  eks_public_access_cidrs = var.eks_public_access_cidrs
}




# ── RDS Module ───────────────────────────────────────────────
module "rds" {
  source = "./modules/rds"

  cluster_name        = "${var.project_name}-${var.environment}-db"
  vpc_id              = module.networking.vpc_id
  subnet_ids          = module.networking.private_subnet_ids
  eks_nodes_sg_id     = module.eks.node_security_group_id
  deletion_protection = var.rds_deletion_protection
}

# ── Static App Frontend CloudFront ────────────────────────────────
module "static_app_frontend" {
  source = "./modules/s3-cloudfront"

  project_name     = var.project_name
  environment      = var.environment
  app_name         = "static-app"
  enable_s3_origin = true
  internal_alb_arn = module.eks.internal_alb_arn
}

# ── SRE Dashboard CloudFront ───────────────────────────────────
module "sre_dashboard_cloudfront" {
  source = "./modules/s3-cloudfront"

  project_name     = var.project_name
  environment      = var.environment
  app_name         = "sre-dashboard"
  enable_s3_origin = false
  internal_alb_arn = module.eks.internal_alb_arn
}

# ── AI SRE Agent IRSA ──────────────────────────────────────────
module "ai_sre_irsa" {
  source = "./modules/ai_sre_irsa"

  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
  namespace                 = "sre-system"
  service_account_name      = "ai-sre-agent-sa"
}
