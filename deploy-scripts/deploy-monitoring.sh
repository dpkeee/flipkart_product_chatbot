#!/bin/bash

# Monitoring Stack Deployment Script
# Deploys Prometheus and Grafana to GKE

set -e  # Exit on error

echo "========================================="
echo "Deploy Monitoring Stack (Prometheus + Grafana)"
echo "========================================="
echo ""

# Navigate to project root
cd "$(dirname "$0")/.."

# Check if kubectl is available
command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl is not installed."; exit 1; }

# Check if cluster is accessible
kubectl cluster-info >/dev/null 2>&1 || { echo "Error: Cannot connect to Kubernetes cluster."; exit 1; }

# Deploy Prometheus
echo ""
echo "[1/3] Deploying Prometheus..."
kubectl apply -f k8s/monitoring/prometheus-rbac.yaml
kubectl apply -f k8s/monitoring/prometheus-configmap.yaml
kubectl apply -f k8s/monitoring/prometheus-deployment.yaml

echo "Waiting for Prometheus to be ready..."
kubectl rollout status deployment/prometheus -n monitoring --timeout=5m

# Deploy Grafana
echo ""
echo "[2/3] Deploying Grafana..."
kubectl apply -f k8s/monitoring/grafana-datasource.yaml
kubectl apply -f k8s/monitoring/grafana-dashboards-config.yaml
kubectl apply -f k8s/monitoring/grafana-dashboard.yaml
kubectl apply -f k8s/monitoring/grafana-deployment.yaml

echo "Waiting for Grafana to be ready..."
kubectl rollout status deployment/grafana -n monitoring --timeout=5m

# Show status
echo ""
echo "[3/3] Verifying monitoring stack..."
kubectl get pods -n monitoring
echo ""
kubectl get services -n monitoring
echo ""
kubectl get pvc -n monitoring

echo ""
echo "========================================="
echo "✅ Monitoring stack deployed successfully!"
echo "========================================="
echo ""
echo "Access Prometheus:"
echo "  kubectl port-forward -n monitoring svc/prometheus-service 9090:9090"
echo "  Then visit: http://localhost:9090"
echo ""
echo "Access Grafana:"
echo "  kubectl port-forward -n monitoring svc/grafana-service 3000:3000"
echo "  Then visit: http://localhost:3000"
echo "  Default credentials: admin / admin123"
echo ""
echo "Pre-configured dashboard: 'Flipkart Chatbot Metrics'"
echo ""
