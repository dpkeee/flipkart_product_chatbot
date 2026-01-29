# GKE Deployment Checklist

Use this checklist to track your deployment progress.

---

## 🚨 Phase 0: Security Remediation (CRITICAL - DO FIRST!)

- [ ] Remove .env from git tracking
  ```bash
  git rm --cached .env
  git add .gitignore
  git commit -m "security: Remove .env from version control"
  git push origin main
  ```

- [ ] Rotate ALL API keys
  - [ ] Groq API key → https://console.groq.com/keys
  - [ ] AstraDB token → DataStax console → Settings
  - [ ] HuggingFace token → https://huggingface.co/settings/tokens

- [ ] Verify .gitignore includes
  - [ ] `.env`
  - [ ] `.env.local`
  - [ ] `k8s/secret.yaml`
  - [ ] `**/secret*.yaml`

- [ ] Update local .env with NEW credentials (don't commit!)

---

## Phase 1: Prerequisites

### Local Tools
- [ ] Google Cloud SDK installed (`gcloud --version`)
- [ ] kubectl installed (`kubectl version --client`)
- [ ] Docker installed (`docker --version`)
- [ ] Git Bash (Windows only)

### GCP Account
- [ ] GCP account created
- [ ] Billing enabled
- [ ] Project created
- [ ] Sufficient IAM permissions
  - [ ] Kubernetes Engine Admin
  - [ ] Compute Admin
  - [ ] Storage Admin

---

## Phase 2: GKE Cluster Setup

- [ ] Choose cluster type (Autopilot or Standard)
- [ ] Enable required GCP APIs
  - [ ] Container API
  - [ ] Compute API

- [ ] Create GKE cluster
  ```bash
  cd deploy-scripts
  chmod +x setup-gke-cluster.sh
  ./setup-gke-cluster.sh
  ```

- [ ] Verify cluster access
  ```bash
  kubectl cluster-info
  kubectl get nodes
  ```

- [ ] Note cluster details
  - Project ID: ________________
  - Cluster Name: ________________
  - Region/Zone: ________________

---

## Phase 3: Container Image

- [ ] Review Dockerfile
- [ ] Review .dockerignore

- [ ] Build and push image
  ```bash
  cd deploy-scripts
  chmod +x build-and-push.sh
  ./build-and-push.sh
  ```

- [ ] Verify image in GCR
  ```bash
  gcloud container images list --repository=gcr.io/PROJECT_ID
  ```

- [ ] Test image locally (optional)
  ```bash
  docker run --rm -p 5000:5000 --env-file .env \
    gcr.io/PROJECT_ID/flask-app:v1.0.0
  curl http://localhost:5000/health
  ```

---

## Phase 4: Kubernetes Secrets

- [ ] Have NEW rotated credentials ready
- [ ] Create secrets (NEVER commit secret.yaml!)
  ```bash
  cd deploy-scripts
  chmod +x create-secrets.sh
  ./create-secrets.sh
  ```

- [ ] Verify secrets created
  ```bash
  kubectl get secret flask-secrets -n default
  ```

---

## Phase 5: Application Deployment

- [ ] Update deployment.yaml with PROJECT_ID
- [ ] Review all manifests in k8s/ directory
- [ ] Verify CSV data file exists (data/flipkart_product_review.csv)

- [ ] Deploy application
  ```bash
  cd deploy-scripts
  chmod +x deploy-app.sh
  ./deploy-app.sh
  ```

- [ ] Wait for deployment
  ```bash
  kubectl rollout status deployment/flask-app -n default
  ```

- [ ] Verify pods running
  ```bash
  kubectl get pods -n default -l app=flask-app
  ```

- [ ] Check pod logs
  ```bash
  kubectl logs -l app=flask-app -n default --tail=50
  ```

---

## Phase 6: Monitoring Deployment

- [ ] Deploy Prometheus
- [ ] Deploy Grafana

  ```bash
  cd deploy-scripts
  chmod +x deploy-monitoring.sh
  ./deploy-monitoring.sh
  ```

- [ ] Verify monitoring pods
  ```bash
  kubectl get pods -n monitoring
  ```

- [ ] Access Prometheus
  ```bash
  kubectl port-forward -n monitoring svc/prometheus-service 9090:9090
  # Visit http://localhost:9090/targets
  ```

- [ ] Access Grafana
  ```bash
  kubectl port-forward -n monitoring svc/grafana-service 3000:3000
  # Visit http://localhost:3000
  # Login: admin / admin123
  ```

---

## Phase 7: Verification

### Application Health
- [ ] Pods are running (2 replicas minimum)
- [ ] Health endpoint responds
  ```bash
  # Get external IP
  kubectl get ingress flask-ingress -n default

  # Test health (wait for IP to be assigned)
  curl http://<EXTERNAL-IP>/health
  ```

- [ ] Metrics endpoint works
  ```bash
  curl http://<EXTERNAL-IP>/metrics
  ```

- [ ] Chatbot API responds
  ```bash
  curl -X POST http://<EXTERNAL-IP>/get \
    -d "msg=What are the best Bluetooth headphones?" \
    -H "Content-Type: application/x-www-form-urlencoded"
  ```

### Auto-scaling
- [ ] HPA is active
  ```bash
  kubectl get hpa flask-hpa -n default
  ```

- [ ] Load test triggers scaling
  ```bash
  ab -n 1000 -c 10 http://<EXTERNAL-IP>/
  kubectl get hpa flask-hpa -n default --watch
  ```

### Monitoring
- [ ] Prometheus scraping flask-app
- [ ] Grafana dashboard shows data
- [ ] All metrics graphs populated

### Networking
- [ ] Ingress has external IP
- [ ] Service is accessible
- [ ] Network policies applied

---

## Phase 8: Post-Deployment Configuration

### DNS Configuration
- [ ] Reserve static IP address
  ```bash
  gcloud compute addresses create flask-app-ip --global
  ```

- [ ] Get static IP
  ```bash
  gcloud compute addresses describe flask-app-ip --global
  ```

- [ ] Update DNS A record
  - Domain: ________________
  - IP: ________________

- [ ] Update ingress.yaml with domain
- [ ] Reapply ingress
  ```bash
  kubectl apply -f k8s/ingress.yaml
  ```

### TLS/SSL Setup
- [ ] Uncomment ManagedCertificate in ingress.yaml
- [ ] Update domain in certificate spec
- [ ] Apply certificate
  ```bash
  kubectl apply -f k8s/ingress.yaml
  ```

- [ ] Wait for certificate provisioning (15-30 min)
  ```bash
  kubectl get managedcertificate -n default --watch
  ```

- [ ] Verify HTTPS access
  ```bash
  curl https://your-domain.com/health
  ```

### Security Hardening
- [ ] Apply pod security standards
  ```bash
  kubectl label namespace default \
    pod-security.kubernetes.io/enforce=baseline
  ```

- [ ] Review network policies
- [ ] Verify non-root containers
- [ ] Check RBAC permissions

### Monitoring Configuration
- [ ] Change Grafana admin password
- [ ] Set up alert rules
  - [ ] High error rate
  - [ ] High latency
  - [ ] Pod crashes
  - [ ] Low replica count

- [ ] Configure notification channels
  - [ ] Email
  - [ ] Slack
  - [ ] PagerDuty

### Backup Configuration
- [ ] Schedule PVC snapshots
  ```bash
  # Create snapshot schedule
  gcloud compute resource-policies create snapshot-schedule \
    prometheus-backup --region=us-central1 \
    --max-retention-days=30 \
    --on-source-disk-delete=keep-auto-snapshots \
    --daily-schedule --start-time=02:00
  ```

- [ ] Export Kubernetes configs to git
  ```bash
  kubectl get all -n default -o yaml > backup-default.yaml
  kubectl get all -n monitoring -o yaml > backup-monitoring.yaml
  ```

---

## Phase 9: Documentation

- [ ] Update README with deployment info
- [ ] Document custom domain and endpoints
- [ ] Create runbook for operations team
- [ ] Document rollback procedures
- [ ] Add troubleshooting guide
- [ ] Create architecture diagram

---

## Phase 10: Testing

### Functional Testing
- [ ] Health check endpoint
- [ ] Metrics endpoint
- [ ] Chatbot query responses
- [ ] Static file serving
- [ ] Error handling

### Performance Testing
- [ ] Load testing (ab, wrk, or k6)
- [ ] Latency measurement
- [ ] Throughput testing
- [ ] Auto-scaling verification

### Security Testing
- [ ] Port scanning (authorized)
- [ ] SSL certificate validation
- [ ] Secrets not exposed
- [ ] Network policy enforcement

### Disaster Recovery Testing
- [ ] Pod failure recovery
- [ ] Node failure recovery
- [ ] Deployment rollback
- [ ] Backup restoration

---

## Phase 11: Production Readiness

### Monitoring & Alerting
- [ ] Prometheus scraping all targets
- [ ] Grafana dashboards configured
- [ ] Alert rules created
- [ ] Notification channels tested
- [ ] On-call rotation setup

### Logging
- [ ] Application logs flowing
- [ ] Log retention configured
- [ ] Log aggregation setup (optional)
- [ ] Log-based alerts (optional)

### Documentation
- [ ] Deployment guide reviewed
- [ ] Architecture documented
- [ ] Runbook created
- [ ] Contact information updated

### Training
- [ ] Team trained on operations
- [ ] Troubleshooting procedures reviewed
- [ ] Monitoring dashboards explained
- [ ] Escalation paths defined

---

## Phase 12: Go-Live

### Pre-Launch
- [ ] Final security review
- [ ] Load testing completed
- [ ] Monitoring verified
- [ ] Backup tested
- [ ] Rollback plan ready

### Launch
- [ ] Update DNS (if applicable)
- [ ] Announce to users
- [ ] Monitor closely for first 24 hours
- [ ] Be ready for quick rollback

### Post-Launch
- [ ] Monitor metrics
- [ ] Check error rates
- [ ] Review logs
- [ ] Gather user feedback
- [ ] Document lessons learned

---

## Ongoing Maintenance

### Daily
- [ ] Check monitoring dashboards
- [ ] Review error logs
- [ ] Verify auto-scaling working

### Weekly
- [ ] Review resource usage
- [ ] Check for security updates
- [ ] Review cost reports
- [ ] Test backup restoration

### Monthly
- [ ] Security audit
- [ ] Performance review
- [ ] Capacity planning
- [ ] Update documentation

### Quarterly
- [ ] Disaster recovery drill
- [ ] Security penetration test
- [ ] Architecture review
- [ ] Team training update

---

## Troubleshooting Quick Reference

### Pods Not Starting
```bash
kubectl describe pod <pod-name> -n default
kubectl logs <pod-name> -n default
```

### No External IP
```bash
kubectl describe ingress flask-ingress -n default
# Wait 5-10 minutes for provisioning
```

### HPA Not Scaling
```bash
kubectl describe hpa flask-hpa -n default
kubectl top pods -n default
```

### High Latency
```bash
kubectl top pods -n default
kubectl logs -l app=flask-app -n default | grep -i error
```

### Application Errors
```bash
kubectl logs -l app=flask-app -n default --tail=100
kubectl exec -it <pod-name> -n default -- /bin/sh
```

---

## Cleanup (When Needed)

- [ ] Back up important data
- [ ] Export configurations
- [ ] Delete application
  ```bash
  cd deploy-scripts
  chmod +x cleanup.sh
  ./cleanup.sh
  ```
- [ ] Delete GKE cluster (if prompted)
- [ ] Release static IP
- [ ] Delete DNS records

---

## Notes and Issues

Use this space to track any issues or notes during deployment:

```
Date: ___________
Issue: _________________________________________
Solution: ______________________________________

Date: ___________
Issue: _________________________________________
Solution: ______________________________________

Date: ___________
Issue: _________________________________________
Solution: ______________________________________
```

---

## Sign-off

- [ ] Deployment completed by: ________________ Date: ___________
- [ ] Reviewed by: ________________ Date: ___________
- [ ] Approved for production by: ________________ Date: ___________

---

**Next Steps After Completion:**
1. Schedule post-deployment review meeting
2. Update project documentation
3. Communicate endpoints to stakeholders
4. Set up monitoring alerts
5. Plan for future enhancements

---

**Estimated Total Time**: 4-6 hours for first-time deployment

**Checklist Version**: 1.0
**Last Updated**: 2026-01-29
