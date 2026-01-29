# Quick Start Guide - GKE Deployment

This is a simplified quick start guide. For detailed instructions, see [DEPLOYMENT.md](DEPLOYMENT.md).

## 🚨 CRITICAL: Security First!

**Before deployment, rotate ALL API keys immediately!**

The `.env` file was previously committed to git. All keys are now compromised.

```bash
# 1. Remove .env from git
git rm --cached .env
git commit -m "security: Remove .env from version control"

# 2. Regenerate ALL keys:
# - Groq: https://console.groq.com/keys
# - AstraDB: DataStax console → Settings → Tokens
# - HuggingFace: https://huggingface.co/settings/tokens
```

---

## 🚀 Quick Deploy (5 Steps)

### Prerequisites
- Google Cloud SDK installed
- kubectl installed
- Docker installed
- Active GCP project with billing

### Step 1: Create GKE Cluster

```bash
cd deploy-scripts
chmod +x setup-gke-cluster.sh
./setup-gke-cluster.sh
```

### Step 2: Build and Push Image

```bash
chmod +x build-and-push.sh
./build-and-push.sh
```

### Step 3: Create Secrets

```bash
chmod +x create-secrets.sh
./create-secrets.sh
# Enter your NEW rotated credentials when prompted
```

### Step 4: Deploy Application

```bash
chmod +x deploy-app.sh
./deploy-app.sh
```

### Step 5: Deploy Monitoring

```bash
chmod +x deploy-monitoring.sh
./deploy-monitoring.sh
```

---

## ✅ Verify Deployment

### Check Status

```bash
# Check pods
kubectl get pods -n default -l app=flask-app

# Get external IP (may take 5-10 minutes)
kubectl get ingress flask-ingress -n default
```

### Test Endpoints

```bash
EXTERNAL_IP=$(kubectl get ingress flask-ingress -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Health check
curl http://$EXTERNAL_IP/health

# Metrics
curl http://$EXTERNAL_IP/metrics

# Chatbot
curl -X POST http://$EXTERNAL_IP/get \
  -d "msg=What are the best Bluetooth headphones?" \
  -H "Content-Type: application/x-www-form-urlencoded"
```

### Access Monitoring

```bash
# Prometheus
kubectl port-forward -n monitoring svc/prometheus-service 9090:9090
# Visit: http://localhost:9090

# Grafana (admin/admin123)
kubectl port-forward -n monitoring svc/grafana-service 3000:3000
# Visit: http://localhost:3000
```

---

## 📋 Useful Commands

```bash
# View logs
kubectl logs -f -l app=flask-app -n default

# Check resource usage
kubectl top pods -n default

# Watch auto-scaling
kubectl get hpa flask-hpa -n default --watch

# Update deployment
kubectl set image deployment/flask-app flask-app=gcr.io/$PROJECT_ID/flask-app:v1.1.0 -n default

# Rollback deployment
kubectl rollout undo deployment/flask-app -n default
```

---

## 🧹 Cleanup

```bash
cd deploy-scripts
chmod +x cleanup.sh
./cleanup.sh
```

---

## 📚 Next Steps

1. Configure DNS to point to external IP
2. Enable TLS/SSL certificates
3. Set up Grafana alerts
4. Configure backup strategy
5. Review security settings

For detailed instructions, see [DEPLOYMENT.md](DEPLOYMENT.md).

---

## 🆘 Troubleshooting

### Pods not starting?
```bash
kubectl describe pod <pod-name> -n default
kubectl logs <pod-name> -n default
```

### Can't access application?
```bash
# Check ingress
kubectl get ingress flask-ingress -n default
kubectl describe ingress flask-ingress -n default

# Check service
kubectl get svc flask-service -n default

# Check pods
kubectl get pods -n default -l app=flask-app
```

### Need more help?
See detailed troubleshooting in [DEPLOYMENT.md](DEPLOYMENT.md).

---

## 📊 Architecture

```
Internet → Ingress → Service → Deployment (2-5 pods) → External APIs
                                    ↓
                             Prometheus ← Grafana
```

- **Min replicas**: 2
- **Max replicas**: 5
- **Auto-scaling**: CPU 70%, Memory 80%
- **Resources**: 500m-1 CPU, 512Mi-1Gi memory per pod

---

## 💰 Estimated Costs

- **Autopilot**: ~$100-150/month
- **Standard (3 nodes)**: ~$180/month
- **External services**: Based on usage

---

## 🔒 Security Checklist

- [ ] All API keys rotated
- [ ] .env removed from git
- [ ] Secrets created in Kubernetes (not committed)
- [ ] Network policies applied
- [ ] Non-root containers
- [ ] TLS/SSL enabled
- [ ] Regular security audits

---

**Ready to deploy? Start with Step 1!**
