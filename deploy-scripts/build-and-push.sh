#!/bin/bash

# Docker Build and Push Script
# Builds the Docker image and pushes it to Google Container Registry

set -e  # Exit on error

echo "========================================="
echo "Docker Build and Push to GCR"
echo "========================================="
echo ""

# Get project ID
read -p "Enter your GCP Project ID: " PROJECT_ID

# Version
read -p "Enter version tag [v1.0.0]: " VERSION
VERSION=${VERSION:-v1.0.0}

echo ""
echo "Configuration:"
echo "  Project ID: $PROJECT_ID"
echo "  Image: gcr.io/$PROJECT_ID/flask-app:$VERSION"
echo ""

read -p "Proceed with build? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

# Navigate to project root
cd "$(dirname "$0")/.."

# Configure Docker for GCR
echo ""
echo "[1/4] Configuring Docker authentication..."
gcloud auth configure-docker

# Build Docker image
echo ""
echo "[2/4] Building Docker image..."
docker build -t gcr.io/$PROJECT_ID/flask-app:$VERSION .
docker build -t gcr.io/$PROJECT_ID/flask-app:latest .

# Test image locally (optional)
read -p "Test image locally before pushing? (yes/no): " TEST
if [[ "$TEST" == "yes" ]]; then
    echo ""
    echo "Testing image locally..."
    echo "Starting container on port 5000..."

    # Check if .env file exists
    if [ ! -f .env ]; then
        echo "⚠️  Warning: .env file not found. Container may fail to start."
        read -p "Continue anyway? (yes/no): " CONTINUE
        if [[ "$CONTINUE" != "yes" ]]; then
            exit 0
        fi
    fi

    docker run --rm -d -p 5000:5000 --env-file .env --name flask-test gcr.io/$PROJECT_ID/flask-app:$VERSION

    echo "Waiting for container to start..."
    sleep 10

    echo "Testing health endpoint..."
    curl -f http://localhost:5000/health || echo "Health check failed!"

    echo "Stopping test container..."
    docker stop flask-test

    echo "✅ Local test completed"
fi

# Push to GCR
echo ""
echo "[3/4] Pushing images to GCR..."
docker push gcr.io/$PROJECT_ID/flask-app:$VERSION
docker push gcr.io/$PROJECT_ID/flask-app:latest

# Verify push
echo ""
echo "[4/4] Verifying images in GCR..."
gcloud container images list --repository=gcr.io/$PROJECT_ID

echo ""
echo "========================================="
echo "✅ Images pushed successfully!"
echo "========================================="
echo ""
echo "Images available:"
echo "  - gcr.io/$PROJECT_ID/flask-app:$VERSION"
echo "  - gcr.io/$PROJECT_ID/flask-app:latest"
echo ""
echo "Next steps:"
echo "  1. Update k8s/deployment.yaml with PROJECT_ID"
echo "  2. Run './deploy-app.sh' to deploy to GKE"
echo ""
