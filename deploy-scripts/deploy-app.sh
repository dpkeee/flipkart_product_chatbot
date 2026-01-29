#!/bin/bash

# Application Deployment Script
# Deploys the Flipkart Chatbot to GKE

set -e  # Exit on error

echo "========================================="
echo "Deploy Flipkart Chatbot to GKE"
echo "========================================="
echo ""

# Navigate to project root
cd "$(dirname "$0")/.."

# Check if kubectl is available
command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl is not installed."; exit 1; }

# Check if cluster is accessible
kubectl cluster-info >/dev/null 2>&1 || { echo "Error: Cannot connect to Kubernetes cluster. Run setup-gke-cluster.sh first."; exit 1; }

# Get project ID for image update
read -p "Enter your GCP Project ID: " PROJECT_ID

echo ""
echo "[1/7] Updating deployment.yaml with project ID..."
sed -i.bak "s/YOUR_PROJECT_ID/$PROJECT_ID/g" k8s/deployment.yaml
echo "✅ Updated deployment.yaml"

# Create namespace
echo ""
echo "[2/7] Creating monitoring namespace..."
kubectl apply -f k8s/namespace.yaml

# Create ConfigMap
echo ""
echo "[3/7] Creating ConfigMaps..."
kubectl apply -f k8s/configmap.yaml

# Check if CSV file exists
if [ -f "data/flipkart_product_review.csv" ]; then
    echo "Creating ConfigMap from CSV file..."
    kubectl delete configmap flask-data --namespace=default --ignore-not-found=true
    kubectl create configmap flask-data \
      --from-file=flipkart_product_review.csv=data/flipkart_product_review.csv \
      --namespace=default
    echo "✅ CSV ConfigMap created"
else
    echo "⚠️  Warning: data/flipkart_product_review.csv not found!"
    echo "Application may fail without data file."
    read -p "Continue anyway? (yes/no): " CONTINUE
    if [[ "$CONTINUE" != "yes" ]]; then
        exit 0
    fi
fi

# Check if secrets exist
echo ""
echo "[4/7] Checking for secrets..."
if kubectl get secret flask-secrets --namespace=default >/dev/null 2>&1; then
    echo "✅ Secrets found"
else
    echo "❌ Secrets not found!"
    echo "Run './create-secrets.sh' first to create secrets."
    exit 1
fi

# Deploy application
echo ""
echo "[5/7] Deploying application..."
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/pdb.yaml

echo "Waiting for deployment to be ready..."
kubectl rollout status deployment/flask-app -n default --timeout=5m

# Deploy ingress
echo ""
echo "[6/7] Deploying ingress..."
echo "⚠️  Note: Update the domain in k8s/ingress.yaml before accessing via domain"
kubectl apply -f k8s/ingress.yaml

# Apply network policies
echo ""
echo "[7/7] Applying network policies..."
kubectl apply -f k8s/network-policy.yaml

# Show status
echo ""
echo "========================================="
echo "✅ Application deployed successfully!"
echo "========================================="
echo ""
echo "Deployment status:"
kubectl get pods -n default -l app=flask-app
echo ""
kubectl get service flask-service -n default
echo ""
kubectl get ingress flask-ingress -n default

echo ""
echo "Next steps:"
echo "  1. Wait for ingress to get external IP (may take 5-10 minutes)"
echo "  2. Test health endpoint: curl http://<EXTERNAL-IP>/health"
echo "  3. Deploy monitoring: ./deploy-monitoring.sh"
echo "  4. Configure DNS to point to external IP"
echo "  5. Enable TLS/SSL certificates"
echo ""
echo "To get external IP:"
echo "  kubectl get ingress flask-ingress -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
echo ""
echo "To view logs:"
echo "  kubectl logs -f -l app=flask-app -n default"
echo ""
