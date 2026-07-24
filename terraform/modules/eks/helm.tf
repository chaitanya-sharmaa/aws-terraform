# ============================================================
# HELM RELEASES — Infrastructure add-ons
# ============================================================
# All chart versions are pinned to ensure deterministic deploys.
# To upgrade, change the version here and run `terraform apply`.
# ============================================================

# ── AWS Load Balancer Controller ─────────────────────────────
# Required to use TargetGroupBinding with our internal ALB.
# The node IAM role has the full recommended LBC policy attached.
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1" # Pinned — update deliberately

  set {
    name  = "clusterName"
    value = aws_eks_cluster.main.name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "replicaCount"
    value = "1"
  }

  wait = true

  depends_on = [aws_eks_node_group.main]
}

# ── Istio Base ──────────────────────────────────────────────
# Installs the Istio CRDs (Gateway, VirtualService, etc.)
resource "helm_release" "istio_base" {
  name             = "istio-base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "base"
  namespace        = "istio-system"
  version          = "1.22.2" # Pinned — update deliberately
  create_namespace = true
  wait             = true

  depends_on = [helm_release.aws_load_balancer_controller]
}

# ── Istiod (Istio Control Plane) ─────────────────────────────
# The Istio control plane — manages sidecar injection and traffic policy.
resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  namespace  = "istio-system"
  version    = "1.22.2" # Pinned — must match istio_base version

  # Force lower resource requests so it can schedule on a t3.small (Free Tier constrained)
  set {
    name  = "pilot.resources.requests.memory"
    value = "128Mi"
  }
  set {
    name  = "pilot.resources.requests.cpu"
    value = "10m"
  }

  set {
    name  = "pilot.autoscaleEnabled"
    value = "false"
  }

  set {
    name  = "pilot.replicaCount"
    value = "1"
  }

  wait = true

  depends_on = [helm_release.istio_base]
}

# ── Istio Ingress Gateway ─────────────────────────────────────
# The actual ingress gateway pod that receives traffic from the ALB.
# Without this, the Gateway CRD exists but no pod serves traffic.
# The TargetGroupBinding will register this pod's IP in the ALB target group.
resource "helm_release" "istio_ingress" {
  name       = "istio-ingress"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  namespace  = "istio-system"
  version    = "1.22.2" # Pinned — must match istiod version

  # Run the gateway as a LoadBalancer=ClusterIP to avoid auto-provisioning
  # an AWS NLB. Our ALB (managed by Terraform) binds to this pod via
  # TargetGroupBinding instead.
  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  set {
    name  = "autoscaling.enabled"
    value = "false"
  }

  set {
    name  = "replicaCount"
    value = "1"
  }

  set {
    name  = "resources.requests.cpu"
    value = "10m"
  }

  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }

  wait = true

  depends_on = [helm_release.istiod]
}

# ── Metrics Server ────────────────────────────────────────────
# Required for `kubectl top pods` and `kubectl top nodes` functionality.
# Used by our AI SRE agent to detect memory leaks and high CPU usage.
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.1" # Pinned

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  set {
    name  = "replicas"
    value = "1"
  }

  set {
    name  = "resources.requests.cpu"
    value = "10m"
  }

  set {
    name  = "resources.requests.memory"
    value = "50Mi"
  }

  wait = true

  depends_on = [aws_eks_node_group.main, helm_release.aws_load_balancer_controller]
}
