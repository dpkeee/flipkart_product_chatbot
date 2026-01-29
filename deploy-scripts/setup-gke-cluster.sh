#!/bin/bash

# GKE Cluster Setup Script
# This script creates a GKE cluster for the Flipkart Chatbot application

set -e  # Exit on error

echo "========================================="
echo "GKE Cluster Setup for Flipkart Chatbot"
echo "========================================="
echo ""

# Check if required tools are installed
command -v gcloud >/dev/null 2>&1 || { echo "Error: gcloud CLI is not installed. Install from https://cloud.google.com/sdk/docs/install"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl is not installed. Install from https://kubernetes.io/docs/tasks/tools/"; exit 1; }

# Variables (customize these)
read -p "Enter your GCP Project ID: " PROJECT_ID
read -p "Enter cluster name [flipkart-chatbot-cluster]: " CLUSTER_NAME
CLUSTER_NAME=${CLUSTER_NAME:-flipkart-chatbot-cluster}

read -p "Enter region [us-central1]: " REGION
REGION=${REGION:-us-central1}

read -p "Enter zone [us-central1-a]: " ZONE
ZONE=${ZONE:-us-central1-a}

echo ""
echo "Configuration:"
echo "  Project ID: $PROJECT_ID"
echo "  Cluster Name: $CLUSTER_NAME"
echo "  Region: $REGION"
echo "  Zone: $ZONE"
echo ""

read -p "Proceed with cluster creation? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

# Set project
echo ""
echo "[1/5] Setting GCP project..."
gcloud config set project $PROJECT_ID

# Enable required APIs
echo ""
echo "[2/5] Enabling required GCP APIs..."
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com

# Choose cluster type
echo ""
echo "Choose cluster type:"
echo "  1) Autopilot (Recommended - Managed, cost-effective)"
echo "  2) Standard (More control, requires node management)"
read -p "Enter choice [1]: " CLUSTER_TYPE
CLUSTER_TYPE=${CLUSTER_TYPE:-1}

# Create cluster
echo ""
echo "[3/5] Creating GKE cluster..."
if [[ "$CLUSTER_TYPE" == "1" ]]; then
    echo "Creating Autopilot cluster..."
    gcloud container clusters create-auto $CLUSTER_NAME \
        --region=$REGION \
        --project=$PROJECT_ID
else
    echo "Creating Standard cluster..."
    gcloud container clusters create $CLUSTER_NAME \
        --zone=$ZONE \
        --num-nodes=3 \
        --machine-type=e2-standard-2 \
        --enable-autoscaling \
        --min-nodes=2 \
        --max-nodes=5 \
        --enable-autorepair \
        --enable-autoupgrade \
        --project=$PROJECT_ID
fi

# Get credentials
echo ""
echo "[4/5] Getting cluster credentials..."
if [[ "$CLUSTER_TYPE" == "1" ]]; then
    gcloud container clusters get-credentials $CLUSTER_NAME \
        --region=$REGION --project=$PROJECT_ID
else
    gcloud container clusters get-credentials $CLUSTER_NAME \
        --zone=$ZONE --project=$PROJECT_ID
fi

# Verify cluster
echo ""
echo "[5/5] Verifying cluster..."
kubectl cluster-info
kubectl get nodes

echo ""
echo "========================================="
echo "✅ GKE Cluster created successfully!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Run './create-secrets.sh' to create Kubernetes secrets"
echo "  2. Run './deploy-app.sh' to deploy the application"
echo ""
