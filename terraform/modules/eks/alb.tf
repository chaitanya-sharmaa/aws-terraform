# ============================================================
# INTERNAL APPLICATION LOAD BALANCER
# ============================================================
# This ALB is provisioned entirely by Terraform.
# It will be bound to the Istio Ingress Gateway using the
# TargetGroupBinding CRD from the AWS Load Balancer Controller.
# ============================================================

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "internal_alb" {
  name        = "${var.project_name}-${var.environment}-internal-alb-sg"
  description = "Security group for internal ALB - allows HTTP from within the VPC only"
  vpc_id      = var.vpc_id

  # Allow HTTP only from within the VPC (CloudFront VPC Origin traffic
  # enters via an ENI placed inside the VPC, so this is the correct scope)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # Dynamic — sourced from the networking module output
  }

  # Allow CloudFront VPC Origin traffic
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-internal-alb-sg"
  }
}

resource "aws_lb" "internal" {
  name               = "${var.project_name}-${var.environment}-int-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.internal_alb.id]
  subnets            = var.subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-internal-alb"
  }
}

resource "aws_lb_target_group" "istio_ingress" {
  name        = "${var.project_name}-${var.environment}-istio-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for direct-to-pod routing (AWS Load Balancer Controller)

  health_check {
    path                = "/healthz/ready" # Istio ingress gateway health check path
    port                = "15021"          # Istio health check port
    protocol            = "HTTP"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.istio_ingress.arn
  }
}

resource "aws_security_group_rule" "alb_to_nodes" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.internal_alb.id
  security_group_id        = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  description              = "Allow ALB to communicate with EKS nodes"
}

resource "helm_release" "istio_target_group_binding" {
  name      = "istio-target-group-binding"
  chart     = "${path.module}/tgb-chart"
  namespace = "istio-system"

  set {
    name  = "targetGroupARN"
    value = aws_lb_target_group.istio_ingress.arn
  }

  depends_on = [
    helm_release.aws_load_balancer_controller,
    helm_release.istio_ingress
  ]
}
