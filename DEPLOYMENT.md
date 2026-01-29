# GKE Deployment Guide - Flipkart Recommender Chatbot

This guide provides step-by-step instructions for deploying the Flipkart Recommender Chatbot to Google Kubernetes Engine (GKE).

## 🚨 CRITICAL: Security Remediation First!

**BEFORE deploying, you MUST address the security issue:**

The `.env` file containing API credentials was previously committed to git. Follow these steps immediately:

### 1. Remove .env from Git History

```bash
cd C:\Deepika\MY_Projects\krishnaik_projects\Flipkart_recommender

# Remove .env from git tracking (but keep local file)
git rm --cached .env

# Verify .gitignore includes .env
cat .gitignore | grep .env

# Commit the change
git add .gitignore
git commit -m "security: Remove .env from version control"

# Push to remote
git push origin main
```

### 2. Rotate ALL API Keys

**You MUST regenerate all API credentials before deployment:**

- **Groq API Key**: https://console.groq.com/keys
- **AstraDB Token**: DataStax Astra console → Settings → Application Tokens
- **HuggingFace Token**: https://huggingface.co/settings/tokens

⚠️ The old keys in the committed .env file are now compromised and must be revoked.

---

## 📋 Prerequisites

### Required Tools

1. **Google Cloud SDK** (gcloud CLI)
   ```bash
   # Install from: https://cloud.google.com/sdk/docs/install
   gcloud --version
   ```

2. **kubectl** (Kubernetes CLI)
   ```bash
   # Install from: https://kubernetes.io/docs/tasks/tools/
   kubectl version --client
   ```

3. **Docker** (for building images)
   ```bash
   docker --version
   ```

4. **Git Bash** (for Windows, to run shell scripts)

### GCP Requirements

- Active GCP account with billing enabled
- Project with sufficient permissions:
  - Kubernetes Engine Admin
  - Compute Admin
  - Storage Admin
  - Service Account User

---

## 🚀 Deployment Steps

### Phase 1: Setup GKE Cluster

**Option A: Using the automated script (Recommended)**

```bash
cd deploy-scripts
chmod +x setup-gke-cluster.sh
./setup-gke-cluster.sh
```

**Option B: Manual setup**

```bash
# Set variables
export PROJECT_ID="your-gcp-project-id"
export CLUSTER_NAME="flipkart-chatbot-cluster"
export REGION="us-central1"
export ZONE="us-central1-a"

# Set project
gcloud config set project $PROJECT_ID

# Enable APIs
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com

# Create Autopilot cluster (Recommended)
gcloud container clusters create-auto $CLUSTER_NAME \
  --region=$REGION \
  --project=$PROJECT_ID

# OR create Standard cluster (more control)
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

# Get credentials
gcloud container clusters get-credentials $CLUSTER_NAME \
  --zone=$ZONE --project=$PROJECT_ID

# Verify
kubectl cluster-info
kubectl get nodes
```

---

### Phase 2: Build and Push Docker Image

**Option A: Using the automated script (Recommended)**

```bash
cd deploy-scripts
chmod +x build-and-push.sh
./build-and-push.sh
```

**Option B: Manual build**

```bash
export PROJECT_ID="your-gcp-project-id"
export VERSION="v1.0.0"

# Configure Docker for GCR
gcloud auth configure-docker

# Build images
docker build -t gcr.io/$PROJECT_ID/flask-app:$VERSION .
docker build -t gcr.io/$PROJECT_ID/flask-app:latest .

# Test locally (optional)
docker run --rm -p 5000:5000 --env-file .env gcr.io/$PROJECT_ID/flask-app:$VERSION
# Test: curl http://localhost:5000/health

# Push to GCR
docker push gcr.io/$PROJECT_ID/flask-app:$VERSION
docker push gcr.io/$PROJECT_ID/flask-app:latest

# Verify
gcloud container images list --repository=gcr.io/$PROJECT_ID
```

---

### Phase 3: Create Kubernetes Secrets

**⚠️ CRITICAL: Use your NEW rotated credentials!**

**Option A: Using the automated script (Recommended)**

```bash
cd deploy-scripts
chmod +x create-secrets.sh
./create-secrets.sh
```

**Option B: Manual creation**

```bash
# Set your NEW rotated credentials
export GROQ_API_KEY="your-new-groq-key"
export ASTRA_DB_TOKEN="your-new-astra-token"
export ASTRA_DB_ENDPOINT="https://your-astra-endpoint"
export HF_TOKEN="your-new-hf-token"

# Create secret
kubectl create secret generic flask-secrets \
  --from-literal=GROQ_API_KEY="$GROQ_API_KEY" \
  --from-literal=ASTRA_DB_APPLICATION_TOKEN="$ASTRA_DB_TOKEN" \
  --from-literal=ASTRA_DB_API_ENDPOINT="$ASTRA_DB_ENDPOINT" \
  --from-literal=HF_TOKEN="$HF_TOKEN" \
  --from-literal=HUGGINGFACEHUB_TOKEN="$HF_TOKEN" \
  --namespace=default

# Verify
kubectl get secret flask-secrets -n default
```

---

### Phase 4: Deploy Application

**Option A: Using the automated script (Recommended)**

```bash
cd deploy-scripts
chmod +x deploy-app.sh
./deploy-app.sh
```

**Option B: Manual deployment**

```bash
export PROJECT_ID="your-gcp-project-id"

# Update deployment.yaml with your project ID
sed -i "s/YOUR_PROJECT_ID/$PROJECT_ID/g" k8s/deployment.yaml

# Create namespace
kubectl apply -f k8s/namespace.yaml

# Create ConfigMaps
kubectl apply -f k8s/configmap.yaml

kubectl create configmap flask-data \
  --from-file=flipkart_product_review.csv=data/flipkart_product_review.csv \
  --namespace=default

# Deploy application
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/pdb.yaml

# Wait for deployment
kubectl rollout status deployment/flask-app -n default

# Deploy ingress
kubectl apply -f k8s/ingress.yaml

# Apply network policies
kubectl apply -f k8s/network-policy.yaml

# Check status
kubectl get pods -n default -l app=flask-app
kubectl get svc flask-service -n default
kubectl get ingress flask-ingress -n default
```

---

### Phase 5: Deploy Monitoring Stack

**Option A: Using the automated script (Recommended)**

```bash
cd deploy-scripts
chmod +x deploy-monitoring.sh
./deploy-monitoring.sh
```

**Option B: Manual deployment**

```bash
# Deploy Prometheus
kubectl apply -f k8s/monitoring/prometheus-rbac.yaml
kubectl apply -f k8s/monitoring/prometheus-configmap.yaml
kubectl apply -f k8s/monitoring/prometheus-deployment.yaml

kubectl rollout status deployment/prometheus -n monitoring

# Deploy Grafana
kubectl apply -f k8s/monitoring/grafana-datasource.yaml
kubectl apply -f k8s/monitoring/grafana-dashboards-config.yaml
kubectl apply -f k8s/monitoring/grafana-dashboard.yaml
kubectl apply -f k8s/monitoring/grafana-deployment.yaml

kubectl rollout status deployment/grafana -n monitoring

# Check status
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

---

## ✅ Verification and Testing

### 1. Check Pod Status

```bash
# Application pods
kubectl get pods -n default -l app=flask-app
kubectl logs -f -l app=flask-app -n default

# Monitoring pods
kubectl get pods -n monitoring
```

### 2. Get External IP

```bash
# Wait for external IP (may take 5-10 minutes)
kubectl get ingress flask-ingress -n default --watch

# Get IP
EXTERNAL_IP=$(kubectl get ingress flask-ingress -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo $EXTERNAL_IP
```

### 3. Test Health Endpoint

```bash
curl http://$EXTERNAL_IP/health
# Expected: {"status": "healthy"}
```

### 4. Test Metrics Endpoint

```bash
curl http://$EXTERNAL_IP/metrics
# Expected: Prometheus format metrics
```

### 5. Test Chatbot API

```bash
curl -X POST http://$EXTERNAL_IP/get \
  -d "msg=What are the best Bluetooth headphones?" \
  -H "Content-Type: application/x-www-form-urlencoded"
```

### 6. Test Auto-scaling

```bash
# Generate load
ab -n 1000 -c 10 http://$EXTERNAL_IP/

# Watch HPA scale
kubectl get hpa flask-hpa -n default --watch
```

### 7. Access Prometheus

```bash
kubectl port-forward -n monitoring svc/prometheus-service 9090:9090
# Visit: http://localhost:9090
# Check targets: http://localhost:9090/targets
```

### 8. Access Grafana

```bash
kubectl port-forward -n monitoring svc/grafana-service 3000:3000
# Visit: http://localhost:3000
# Login: admin / admin123
# Dashboard: "Flipkart Chatbot Metrics"
```

---

## 🔧 Post-Deployment Configuration

### 1. Configure DNS

Point your domain to the ingress external IP:

```bash
# Get external IP
kubectl get ingress flask-ingress -n default

# Add A record in your DNS provider:
# flipkart-chatbot.example.com → <EXTERNAL_IP>
```

### 2. Enable TLS/SSL

Update `k8s/ingress.yaml` to uncomment the managed certificate section, then:

```bash
# Reserve static IP
gcloud compute addresses create flask-app-ip --global --project=$PROJECT_ID

# Update ingress.yaml with your domain
# Then apply
kubectl apply -f k8s/ingress.yaml

# Wait for certificate provisioning (can take 15-30 minutes)
kubectl get managedcertificate -n default --watch
```

### 3. Configure Monitoring Alerts

Access Grafana and configure alerts for:
- High error rates
- High CPU/memory usage
- Pod restarts
- Low replica count

### 4. Enable Pod Security Standards

```bash
kubectl label namespace default pod-security.kubernetes.io/enforce=baseline
kubectl label namespace monitoring pod-security.kubernetes.io/enforce=restricted
```

---

## 📊 Monitoring and Maintenance

### View Logs

```bash
# Application logs
kubectl logs -f -l app=flask-app -n default

# Prometheus logs
kubectl logs -f -l app=prometheus -n monitoring

# Grafana logs
kubectl logs -f -l app=grafana -n monitoring
```

### Check Resource Usage

```bash
# Pod metrics
kubectl top pods -n default
kubectl top nodes

# HPA status
kubectl get hpa -n default
```

### Update Deployment

```bash
# Build new version
docker build -t gcr.io/$PROJECT_ID/flask-app:v1.1.0 .
docker push gcr.io/$PROJECT_ID/flask-app:v1.1.0

# Update deployment
kubectl set image deployment/flask-app flask-app=gcr.io/$PROJECT_ID/flask-app:v1.1.0 -n default

# Watch rollout
kubectl rollout status deployment/flask-app -n default

# Rollback if needed
kubectl rollout undo deployment/flask-app -n default
```

### Backup and Restore

```bash
# Backup PVCs
kubectl get pvc -n monitoring

# Create snapshots
gcloud compute disks snapshot <disk-name> --snapshot-names=backup-$(date +%Y%m%d)

# Export configurations
kubectl get all -n default -o yaml > backup-default.yaml
kubectl get all -n monitoring -o yaml > backup-monitoring.yaml
```

---

## 🧹 Cleanup

**Option A: Using the automated script**

```bash
cd deploy-scripts
chmod +x cleanup.sh
./cleanup.sh
```

**Option B: Manual cleanup**

```bash
# Delete application
kubectl delete -f k8s/ingress.yaml
kubectl delete -f k8s/pdb.yaml
kubectl delete -f k8s/hpa.yaml
kubectl delete -f k8s/service.yaml
kubectl delete -f k8s/deployment.yaml
kubectl delete configmap flask-config flask-data -n default
kubectl delete secret flask-secrets -n default

# Delete monitoring
kubectl delete -f k8s/monitoring/grafana-deployment.yaml
kubectl delete -f k8s/monitoring/prometheus-deployment.yaml
kubectl delete namespace monitoring

# Delete cluster
gcloud container clusters delete $CLUSTER_NAME \
  --zone=$ZONE --project=$PROJECT_ID
```

---

## 🐛 Troubleshooting

### Pods Not Starting

```bash
kubectl describe pod <pod-name> -n default
kubectl logs <pod-name> -n default
```

**Common causes:**
- Missing secrets → Run `create-secrets.sh`
- Image pull errors → Check GCR permissions
- Insufficient resources → Adjust resource requests/limits

### HPA Not Scaling

```bash
kubectl describe hpa flask-hpa -n default
kubectl top pods -n default
```

**Common causes:**
- Metrics server not installed
- Resource requests not set
- CPU/memory thresholds not reached

### Prometheus Not Scraping

```bash
kubectl port-forward -n monitoring svc/prometheus-service 9090:9090
# Visit http://localhost:9090/targets
```

**Common causes:**
- Network policies blocking access
- Incorrect annotations on pods
- Service discovery not configured

### Application Errors

```bash
kubectl logs -l app=flask-app -n default | grep -i error
```

**Common causes:**
- Invalid API credentials
- Missing environment variables
- AstraDB connection issues
- Data file not mounted

---

## 💰 Cost Optimization

### Autopilot Cluster
- Pay only for pod resources
- Automatic node management
- ~$100-150/month for this workload

### Standard Cluster
- 3 x e2-standard-2 nodes: ~$150/month
- Storage: ~$10/month
- Load Balancer: ~$20/month
- Total: ~$180/month

### Tips to Reduce Costs
1. Use Autopilot for variable workloads
2. Set appropriate resource limits
3. Use preemptible nodes (Standard cluster)
4. Enable cluster autoscaler
5. Delete unused resources
6. Use Cloud Storage for data instead of PVCs

---

## 📚 Additional Resources

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)
- [Grafana Documentation](https://grafana.com/docs/)

---

## 🔒 Security Best Practices

1. ✅ Rotate API keys immediately
2. ✅ Never commit secrets to git
3. ✅ Use Kubernetes secrets or GCP Secret Manager
4. ✅ Enable network policies
5. ✅ Run containers as non-root
6. ✅ Use TLS/SSL for external access
7. ✅ Implement pod security standards
8. ✅ Regular security audits
9. ✅ Monitor for suspicious activity
10. ✅ Keep images and dependencies updated

---

## 📝 Checklist

- [ ] API keys rotated
- [ ] .env removed from git
- [ ] GKE cluster created
- [ ] Docker image built and pushed
- [ ] Secrets created in Kubernetes
- [ ] Application deployed
- [ ] Monitoring stack deployed
- [ ] Health checks passing
- [ ] Metrics being collected
- [ ] DNS configured
- [ ] TLS/SSL enabled
- [ ] Network policies applied
- [ ] Backups configured
- [ ] Alerts configured
- [ ] Documentation updated

---

**Need help?** Create an issue in the repository or contact the development team.
