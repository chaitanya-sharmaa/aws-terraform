# aws-terraform

This repository manages AWS infrastructure and Kubernetes deployments using Terraform and Istio.

## Repository Structure

- **`/terraform`**: Contains the core infrastructure definitions.
  - **`/bootstrap`**: Initial Terraform setup and state backend configuration.
  - **`/modules`**: Reusable infrastructure components:
    - `eks`: Elastic Kubernetes Service (EKS) cluster and node groups.
    - `networking`: VPC, subnets, and routing infrastructure.
    - `rds`: Relational Database Service.
    - `s3-cloudfront`: S3 buckets and CloudFront distributions (e.g., SRE dashboard).
  - **`/environments`**: Environment-specific variable definitions (`dev.tfvars`, `prod.tfvars`).
- **`/k8s`**: Global Kubernetes configurations, including the Istio Ingress `Gateway` (`gateway.yaml`).
- **`/apps`**: Application-specific deployments and configurations.
  - **`dynamic-app`**: Contains `backend` and `k8s` definitions.
  - **`static-app`**: Contains `frontend`, `backend`, and `k8s` definitions.
  - **`istio-tgb.yaml`**: AWS TargetGroupBinding connecting the Istio ingress service to an AWS ALB Target Group.

## Usage

### 1. Provision Infrastructure

Navigate to the `terraform` directory to deploy your AWS infrastructure. Be sure to select the correct environment variables file.

```bash
cd terraform
terraform init
terraform plan -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars"
```

### 2. Deploy Kubernetes Resources

Once the EKS cluster is up and your `kubeconfig` is configured, apply the global and application-specific manifests:

```bash
# Apply global Istio Gateway
kubectl apply -f k8s/gateway.yaml

# Apply the Ingress TargetGroupBinding
kubectl apply -f apps/istio-tgb.yaml

# (Optional) Deploy specific applications from apps/
```