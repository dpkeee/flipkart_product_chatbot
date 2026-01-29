#!/bin/bash

# Kubernetes Secrets Creation Script
# CRITICAL: This script creates secrets from environment variables
# NEVER commit actual API keys to git!

set -e  # Exit on error

echo "========================================="
echo "Kubernetes Secrets Creation"
echo "========================================="
echo ""
echo "⚠️  SECURITY WARNING:"
echo "This script will create Kubernetes secrets with your API credentials."
echo "Make sure you have ROTATED all API keys before proceeding!"
echo ""
echo "Required credentials:"
echo "  - Groq API Key (regenerate at https://console.groq.com/keys)"
echo "  - AstraDB Application Token (regenerate in DataStax console)"
echo "  - AstraDB API Endpoint"
echo "  - HuggingFace Token (regenerate at https://huggingface.co/settings/tokens)"
echo ""

read -p "Have you rotated ALL API keys? (yes/no): " ROTATED
if [[ "$ROTATED" != "yes" ]]; then
    echo "❌ Please rotate all API keys first!"
    exit 1
fi

echo ""
echo "Enter your credentials (they will be hidden):"
echo ""

# Read credentials securely
read -sp "Groq API Key: " GROQ_API_KEY
echo ""
read -sp "AstraDB Application Token: " ASTRA_DB_TOKEN
echo ""
read -p "AstraDB API Endpoint: " ASTRA_DB_ENDPOINT
read -sp "HuggingFace Token: " HF_TOKEN
echo ""

# Validate inputs
if [[ -z "$GROQ_API_KEY" || -z "$ASTRA_DB_TOKEN" || -z "$ASTRA_DB_ENDPOINT" || -z "$HF_TOKEN" ]]; then
    echo "❌ Error: All fields are required!"
    exit 1
fi

# Check if kubectl is available
command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl is not installed."; exit 1; }

# Check if cluster is accessible
kubectl cluster-info >/dev/null 2>&1 || { echo "Error: Cannot connect to Kubernetes cluster. Run setup-gke-cluster.sh first."; exit 1; }

echo ""
echo "Creating Kubernetes secret..."

# Delete existing secret if present
kubectl delete secret flask-secrets --namespace=default --ignore-not-found=true

# Create new secret
kubectl create secret generic flask-secrets \
  --from-literal=GROQ_API_KEY="$GROQ_API_KEY" \
  --from-literal=ASTRA_DB_APPLICATION_TOKEN="$ASTRA_DB_TOKEN" \
  --from-literal=ASTRA_DB_API_ENDPOINT="$ASTRA_DB_ENDPOINT" \
  --from-literal=HF_TOKEN="$HF_TOKEN" \
  --from-literal=HUGGINGFACEHUB_TOKEN="$HF_TOKEN" \
  --namespace=default

# Verify secret was created
echo ""
echo "Verifying secret..."
kubectl get secret flask-secrets --namespace=default

echo ""
echo "========================================="
echo "✅ Secrets created successfully!"
echo "========================================="
echo ""
echo "⚠️  SECURITY REMINDER:"
echo "  - Never commit the .env file to git"
echo "  - Never commit k8s/secret.yaml to git"
echo "  - Rotate keys regularly"
echo ""
echo "Next step:"
echo "  Run './deploy-app.sh' to deploy the application"
echo ""
