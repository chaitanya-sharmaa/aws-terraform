#!/bin/bash
set -e

echo "==========================================="
echo " Deploying Static App (Backend + Frontend) "
echo "==========================================="

# 0. Set working directory to repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$REPO_ROOT"

# 1. Go to Terraform folder and get outputs
echo "Fetching Terraform outputs..."
cd terraform
REGION=$(terraform output -raw aws_region 2>/dev/null || echo "eu-north-1")
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
ECR_URL=$(terraform output -raw ecr_repository_url)
BUCKET_NAME=$(terraform output -raw static_app_bucket_name)
CLOUDFRONT_ID=$(terraform output -raw static_app_cloudfront_id)
CLOUDFRONT_DOMAIN=$(terraform output -raw static_app_cloudfront_domain)
DB_ENDPOINT=$(terraform output -raw db_endpoint)
DB_USERNAME=$(terraform output -raw db_username)
DB_PASSWORD=$(terraform output -raw db_password)
cd ..

if [ -z "$ECR_URL" ] || [ -z "$BUCKET_NAME" ]; then
    echo "Error: Could not retrieve Terraform outputs. Have you run 'terraform apply'?"
    exit 1
fi

echo "Region: $REGION"
echo "Cluster: $CLUSTER_NAME"
echo "ECR URL: $ECR_URL"
echo "Bucket: $BUCKET_NAME"

# 2. Extract ECR domain from URL
ECR_DOMAIN=$(echo $ECR_URL | cut -d'/' -f1)

# 3. Authenticate Docker with AWS ECR
echo "Authenticating Docker with ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_DOMAIN

# 4. Build, Tag, and Push Backend Image
IMAGE_TAG=$(git rev-parse --short HEAD 2>/dev/null || echo "latest")
FULL_IMAGE_URI="${ECR_URL}:${IMAGE_TAG}"

echo "Building backend image..."
docker build -t static-app-backend:$IMAGE_TAG ./apps/static-app/backend

echo "Tagging and pushing image: $FULL_IMAGE_URI"
docker tag static-app-backend:$IMAGE_TAG $FULL_IMAGE_URI
docker push $FULL_IMAGE_URI

# 5. Deploy to EKS
echo "Configuring kubectl..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

echo "Updating Kubernetes manifests with new image..."
cd apps/static-app/k8s

cat <<EOF > kustomization.yaml
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
EOF

echo "Applying Kubernetes manifests..."
kubectl apply -f ../../../k8s/gateway.yaml
kubectl apply -k .

echo "Injecting Database Credentials..."
DATABASE_URL="postgresql://${DB_USERNAME}:${DB_PASSWORD}@${DB_ENDPOINT}/acmecorp"
kubectl create secret generic static-app-secrets --from-literal=DATABASE_URL="${DATABASE_URL}" --namespace static-app --dry-run=client -o yaml | kubectl apply -f -

cd ../../..

# 6. Upload Frontend to S3
echo "Uploading frontend to S3..."
aws s3 sync ./apps/static-app/frontend/ s3://${BUCKET_NAME}/ --delete

# 7. Invalidate CloudFront Cache
echo "Invalidating CloudFront cache..."
aws cloudfront create-invalidation --distribution-id $CLOUDFRONT_ID --paths "/*"

echo "==========================================="
echo " Deployment Complete! "
echo " App is live at: $CLOUDFRONT_DOMAIN "
echo "==========================================="
