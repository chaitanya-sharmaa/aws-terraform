$ErrorActionPreference = "Stop"

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host " Deploying Static App (Backend + Frontend) " -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan

# 0. Set working directory to repository root
$REPO_ROOT = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $REPO_ROOT

# 1. Go to Terraform folder and get outputs
Write-Host "`nFetching Terraform outputs..." -ForegroundColor Yellow
Push-Location terraform
$REGION = try { terraform output -raw aws_region 2>$null } catch { "eu-north-1" }
if (-not $REGION) { $REGION = "eu-north-1" }
$CLUSTER_NAME = terraform output -raw eks_cluster_name
$ECR_URL = terraform output -raw ecr_repository_url
$BUCKET_NAME = terraform output -raw static_app_bucket_name
$CLOUDFRONT_ID = terraform output -raw static_app_cloudfront_id
$CLOUDFRONT_DOMAIN = terraform output -raw static_app_cloudfront_domain
$DB_ENDPOINT = terraform output -raw db_endpoint
$DB_USERNAME = terraform output -raw db_username
$DB_PASSWORD = terraform output -raw db_password
Pop-Location

if ([string]::IsNullOrWhiteSpace($ECR_URL) -or [string]::IsNullOrWhiteSpace($BUCKET_NAME)) {
    Write-Host "Error: Could not retrieve Terraform outputs. Have you run 'terraform apply'?" -ForegroundColor Red
    exit 1
}

Write-Host "Region: $REGION"
Write-Host "Cluster: $CLUSTER_NAME"
Write-Host "ECR URL: $ECR_URL"
Write-Host "Bucket: $BUCKET_NAME"

# 2. Extract ECR domain from URL
$ECR_DOMAIN = $ECR_URL.Split('/')[0]

# 3. Authenticate Docker with AWS ECR
Write-Host "`nAuthenticating Docker with ECR..." -ForegroundColor Yellow
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_DOMAIN

# 4. Build, Tag, and Push Backend Image
$IMAGE_TAG = try { git rev-parse --short HEAD 2>$null } catch { "latest" }
if (-not $IMAGE_TAG) { $IMAGE_TAG = "latest" }
$FULL_IMAGE_URI = "${ECR_URL}:${IMAGE_TAG}"

Write-Host "`nBuilding backend image..." -ForegroundColor Yellow
docker build -t static-app-backend:$IMAGE_TAG ./apps/static-app/backend

Write-Host "Tagging and pushing image: $FULL_IMAGE_URI" -ForegroundColor Yellow
docker tag static-app-backend:$IMAGE_TAG $FULL_IMAGE_URI
docker push $FULL_IMAGE_URI

# 5. Deploy to EKS
Write-Host "`nConfiguring kubectl..." -ForegroundColor Yellow
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

Write-Host "Updating Kubernetes manifests with new image..." -ForegroundColor Yellow
Push-Location apps/static-app/k8s

$Kustomization = @"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml
  - istio.yaml

images:
  - name: static-app-backend
    newName: $ECR_URL
    newTag: $IMAGE_TAG
"@
Set-Content -Path kustomization.yaml -Value $Kustomization

Write-Host "Applying Kubernetes manifests..." -ForegroundColor Yellow
kubectl apply -f ../../../k8s/gateway.yaml
kubectl apply -k .

Write-Host "Injecting Database Credentials..." -ForegroundColor Yellow
$DATABASE_URL = "postgresql://${DB_USERNAME}:${DB_PASSWORD}@${DB_ENDPOINT}/acmecorp"
kubectl create secret generic static-app-secrets --from-literal=DATABASE_URL="${DATABASE_URL}" --namespace static-app --dry-run=client -o yaml | kubectl apply -f -

Pop-Location

# 6. Upload Frontend to S3
Write-Host "`nUploading frontend to S3..." -ForegroundColor Yellow
aws s3 sync ./apps/static-app/frontend/ s3://${BUCKET_NAME}/ --delete

# 7. Invalidate CloudFront Cache
Write-Host "`nInvalidating CloudFront cache..." -ForegroundColor Yellow
aws cloudfront create-invalidation --distribution-id $CLOUDFRONT_ID --paths "/*" | Out-Null

Write-Host "`n===========================================" -ForegroundColor Green
Write-Host " Deployment Complete! " -ForegroundColor Green
Write-Host " App is live at: $CLOUDFRONT_DOMAIN " -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Green
