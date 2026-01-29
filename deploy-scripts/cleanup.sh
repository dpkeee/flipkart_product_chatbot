#!/bin/bash

# Cleanup Script
# Deletes all Kubernetes resources and optionally the GKE cluster

set -e  # Exit on error

echo "========================================="
echo "⚠️  CLEANUP WARNING"
echo "========================================="
echo ""
echo "This script will DELETE:"
echo "  - All application deployments"
echo "  - All monitoring resources"
echo "  - All ConfigMaps and Secrets"
echo "  - All PersistentVolumeClaims (data will be lost!)"
echo "  - Optionally: The entire GKE cluster"
echo ""

read -p "Are you sure you want to continue? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

# Navigate to project root
cd "$(dirname "$0")/.."

# Check if kubectl is available
command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl is not installed."; exit 1; }

echo ""
echo "[1/4] Deleting application resources..."
kubectl delete -f k8s/ingress.yaml --ignore-not-found=true
kubectl delete -f k8s/pdb.yaml --ignore-not-found=true
kubectl delete -f k8s/hpa.yaml --ignore-not-found=true
kubectl delete -f k8s/service.yaml --ignore-not-found=true
kubectl delete -f k8s/deployment.yaml --ignore-not-found=true
kubectl delete configmap flask-config flask-data --namespace=default --ignore-not-found=true
kubectl delete secret flask-secrets --namespace=default --ignore-not-found=true

echo ""
echo "[2/4] Deleting monitoring resources..."
kubectl delete -f k8s/monitoring/grafana-deployment.yaml --ignore-not-found=true
kubectl delete -f k8s/monitoring/grafana-dashboard.yaml --ignore-not-found=true
kubectl delete -f k8s/monitoring/grafana-dashboards-config.yaml --ignore-not-found=true
kubectl delete -f k8s/monitoring/grafana-datasource.yaml --ignore-not-found=true
kubectl delete -f k8s/monitoring/prometheus-deployment.yaml --ignore-not-found=true
kubectl delete -f k8s/monitoring/prometheus-configmap.yaml --ignore-not-found=true
kubectl delete -f k8s/monitoring/prometheus-rbac.yaml --ignore-not-found=true

echo ""
echo "[3/4] Deleting network policies..."
kubectl delete -f k8s/network-policy.yaml --ignore-not-found=true

echo ""
echo "[4/4] Deleting namespaces..."
kubectl delete namespace monitoring --ignore-not-found=true

echo ""
echo "✅ All Kubernetes resources deleted"

# Optionally delete GKE cluster
echo ""
read -p "Delete the GKE cluster as well? (yes/no): " DELETE_CLUSTER
if [[ "$DELETE_CLUSTER" == "yes" ]]; then
    read -p "Enter your GCP Project ID: " PROJECT_ID
    read -p "Enter cluster name: " CLUSTER_NAME
    read -p "Is this an Autopilot cluster? (yes/no): " IS_AUTOPILOT

    if [[ "$IS_AUTOPILOT" == "yes" ]]; then
        read -p "Enter region: " REGION
        echo "Deleting Autopilot cluster..."
        gcloud container clusters delete $CLUSTER_NAME \
            --region=$REGION \
            --project=$PROJECT_ID \
            --quiet
    else
        read -p "Enter zone: " ZONE
        echo "Deleting Standard cluster..."
        gcloud container clusters delete $CLUSTER_NAME \
            --zone=$ZONE \
            --project=$PROJECT_ID \
            --quiet
    fi

    echo "✅ GKE cluster deleted"
fi

echo ""
echo "========================================="
echo "✅ Cleanup completed!"
echo "========================================="
echo ""
