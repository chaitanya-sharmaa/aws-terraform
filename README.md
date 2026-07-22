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
- **`/apps`**: Application source code and Kubernetes manifests.
  - **`static-app`**: Contains the `frontend` (deployed to S3), the `backend` (deployed to EKS), and the `k8s` definitions.
- **`/scripts`**: Automation scripts for building and deploying the applications.

## Usage

### 1. Provision Infrastructure

Navigate to the `terraform` directory to deploy your AWS infrastructure. Be sure to select the correct environment variables file.

```bash
cd terraform
terraform init
terraform plan -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars"
```

### 2. Deploy Applications

Once the infrastructure is up, use the automated deployment scripts to build the Docker images, push them to ECR, apply the Kubernetes manifests to EKS, upload the static frontend to S3, and invalidate the CloudFront cache.

**For Windows (PowerShell):**
```powershell
.\scripts\deploy.ps1
```

**For Linux / macOS / WSL (Bash):**
```bash
./scripts/deploy.sh
```