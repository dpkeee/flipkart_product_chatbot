# Architecture Documentation - Flipkart Recommender Chatbot on GKE

## System Overview

The Flipkart Recommender Chatbot is deployed as a cloud-native application on Google Kubernetes Engine (GKE) with full observability and auto-scaling capabilities.

---

## Architecture Diagram

```
                                    ┌─────────────────────────────────────┐
                                    │          INTERNET                    │
                                    └──────────────┬──────────────────────┘
                                                   │
                                                   │ HTTPS/HTTP
                                                   │
                                    ┌──────────────▼──────────────────────┐
                                    │   Google Cloud Load Balancer        │
                                    │   (GKE Ingress Controller)          │
                                    │   - Health Checks                   │
                                    │   - SSL Termination                 │
                                    │   - Session Affinity                │
                                    └──────────────┬──────────────────────┘
                                                   │
                                                   │ HTTP :80
                                                   │
┌──────────────────────────────────────────────────────────────────────────┐
│                          GKE CLUSTER                                     │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                    DEFAULT NAMESPACE                            │    │
│  │                                                                 │    │
│  │   ┌─────────────────────────────────────────────────────┐     │    │
│  │   │  Service: flask-service (ClusterIP)                 │     │    │
│  │   │  - Port: 80 → 5000                                  │     │    │
│  │   │  - Session Affinity: ClientIP (3h)                  │     │    │
│  │   │  - Selector: app=flask-app                          │     │    │
│  │   └─────────────────┬───────────────────────────────────┘     │    │
│  │                     │                                          │    │
│  │                     │  Load Balanced                           │    │
│  │        ┌────────────┼────────────┬─────────────┐              │    │
│  │        │            │            │             │              │    │
│  │   ┌────▼────┐  ┌───▼─────┐ ┌───▼─────┐  ┌───▼─────┐         │    │
│  │   │ Pod 1   │  │ Pod 2   │ │ Pod 3   │  │ Pod N   │         │    │
│  │   │ (min)   │  │ (min)   │ │ (auto)  │  │ (max:5) │         │    │
│  │   │         │  │         │ │         │  │         │         │    │
│  │   │ ┌─────────────────────────────────────────────┐ │         │    │
│  │   │ │  Container: flask-app                       │ │         │    │
│  │   │ │  Image: gcr.io/PROJECT/flask-app:v1.0.0    │ │         │    │
│  │   │ │  Port: 5000                                 │ │         │    │
│  │   │ │                                             │ │         │    │
│  │   │ │  Resources:                                 │ │         │    │
│  │   │ │    Request: 500m CPU, 512Mi RAM            │ │         │    │
│  │   │ │    Limit: 1000m CPU, 1Gi RAM               │ │         │    │
│  │   │ │                                             │ │         │    │
│  │   │ │  Health Probes:                            │ │         │    │
│  │   │ │    Liveness: /health (60s delay)           │ │         │    │
│  │   │ │    Readiness: /health (30s delay)          │ │         │    │
│  │   │ │                                             │ │         │    │
│  │   │ │  Security:                                  │ │         │    │
│  │   │ │    User: appuser (UID 1000)                │ │         │    │
│  │   │ │    No privilege escalation                 │ │         │    │
│  │   │ │    Capabilities dropped                    │ │         │    │
│  │   │ │                                             │ │         │    │
│  │   │ │  Environment:                              │ │         │    │
│  │   │ │    ├─ Secrets (flask-secrets)              │ │         │    │
│  │   │ │    │   ├─ GROQ_API_KEY                     │ │         │    │
│  │   │ │    │   ├─ ASTRA_DB_APPLICATION_TOKEN       │ │         │    │
│  │   │ │    │   ├─ ASTRA_DB_API_ENDPOINT            │ │         │    │
│  │   │ │    │   └─ HF_TOKEN                         │ │         │    │
│  │   │ │    └─ ConfigMap (flask-config)             │ │         │    │
│  │   │ │        ├─ EMBEDDING_MODEL                  │ │         │    │
│  │   │ │        ├─ RAG_MODEL                        │ │         │    │
│  │   │ │        └─ KEYSPACE_NAME                    │ │         │    │
│  │   │ │                                             │ │         │    │
│  │   │ │  Volumes:                                   │ │         │    │
│  │   │ │    └─ data-volume (ConfigMap)              │ │         │    │
│  │   │ │       └─ flipkart_product_review.csv       │ │         │    │
│  │   │ └─────────────────────────────────────────────┘ │         │    │
│  │   └─────────────────────────────────────────────────┘         │    │
│  │                                                                │    │
│  │   ┌──────────────────────────────────────────────────┐        │    │
│  │   │  HorizontalPodAutoscaler (flask-hpa)            │        │    │
│  │   │  - Min: 2, Max: 5                               │        │    │
│  │   │  - Metric: CPU 70%, Memory 80%                  │        │    │
│  │   │  - Scale Up: Immediate (max 2 pods)             │        │    │
│  │   │  - Scale Down: 5 min wait (max 1 pod)           │        │    │
│  │   └──────────────────────────────────────────────────┘        │    │
│  │                                                                │    │
│  │   ┌──────────────────────────────────────────────────┐        │    │
│  │   │  PodDisruptionBudget (flask-pdb)                │        │    │
│  │   │  - MinAvailable: 1                              │        │    │
│  │   └──────────────────────────────────────────────────┘        │    │
│  │                                                                │    │
│  │   ┌──────────────────────────────────────────────────┐        │    │
│  │   │  NetworkPolicy (flask-app-network-policy)       │        │    │
│  │   │  - Ingress: From ingress controller & monitoring │       │    │
│  │   │  - Egress: To external APIs & DNS               │        │    │
│  │   └──────────────────────────────────────────────────┘        │    │
│  │                                                                │    │
│  └────────────────────────────────────────────────────────────────┘   │
│                                                                        │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │                    MONITORING NAMESPACE                         │   │
│  │                                                                 │   │
│  │   ┌────────────────────────────────────────────────┐           │   │
│  │   │  Prometheus                                    │           │   │
│  │   │  - Port: 9090                                  │           │   │
│  │   │  - Scrape Interval: 15s                        │           │   │
│  │   │  - Retention: 15 days                          │           │   │
│  │   │  - Storage: 10Gi PVC                           │           │   │
│  │   │  - ServiceAccount: prometheus (RBAC)           │           │   │
│  │   │                                                 │           │   │
│  │   │  Scraping:                                      │           │   │
│  │   │    └─> flask-app pods (:5000/metrics)          │           │   │
│  │   └────────────────────────────────────────────────┘           │   │
│  │                     │                                           │   │
│  │                     │ Prometheus Datasource                     │   │
│  │                     ▼                                           │   │
│  │   ┌────────────────────────────────────────────────┐           │   │
│  │   │  Grafana                                       │           │   │
│  │   │  - Port: 3000                                  │           │   │
│  │   │  - User: admin / admin123                     │           │   │
│  │   │  - Storage: 5Gi PVC                            │           │   │
│  │   │                                                 │           │   │
│  │   │  Dashboards:                                    │           │   │
│  │   │    └─ Flipkart Chatbot Metrics                │           │   │
│  │   │       ├─ HTTP Requests                         │           │   │
│  │   │       ├─ Model Predictions                     │           │   │
│  │   │       ├─ CPU/Memory Usage                      │           │   │
│  │   │       ├─ Pod Status                            │           │   │
│  │   │       └─ Auto-scaling Events                   │           │   │
│  │   └────────────────────────────────────────────────┘           │   │
│  │                                                                 │   │
│  └─────────────────────────────────────────────────────────────────┘  │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ External API Calls
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
                    ▼               ▼               ▼
         ┌──────────────┐ ┌─────────────┐ ┌─────────────────┐
         │  AstraDB     │ │  Groq API   │ │  HuggingFace    │
         │  (Vector DB) │ │  (LLM)      │ │  (Embeddings)   │
         │              │ │             │ │                 │
         │  - Product   │ │  - llama    │ │  - MiniLM-L6    │
         │    Reviews   │ │    3.3-70b  │ │    embeddings   │
         │  - 451 docs  │ │             │ │                 │
         └──────────────┘ └─────────────┘ └─────────────────┘
```

---

## Component Details

### 1. Ingress Layer

**Component**: GKE Ingress Controller (GCE Load Balancer)

**Responsibilities**:
- External traffic routing
- SSL/TLS termination
- Health checks
- Session persistence (ClientIP)
- DDoS protection (via Cloud Armor)

**Configuration**:
```yaml
Type: GCE Load Balancer
Health Check: /health endpoint
Timeout: 30s
Session Affinity: ClientIP (3 hours)
```

---

### 2. Application Layer

**Component**: Flask Application Pods

**Technology Stack**:
- **Framework**: Flask 3.1.2
- **LLM**: Groq (llama-3.3-70b-versatile)
- **Vector Store**: AstraDB
- **Embeddings**: HuggingFace (all-MiniLM-L6-v2)
- **Agent Framework**: LangChain + LangGraph

**Pod Specifications**:
```yaml
Replicas: 2-5 (auto-scaled)
Resources:
  Requests: 500m CPU, 512Mi RAM
  Limits: 1000m CPU, 1Gi RAM
Security:
  User: appuser (UID 1000)
  Capabilities: All dropped
  Privilege Escalation: Disabled
```

**Endpoints**:
- `/` - Main application (HTML interface)
- `/get` - POST endpoint for chatbot queries
- `/health` - Health check (returns 200 OK)
- `/metrics` - Prometheus metrics

**Health Checks**:
- **Liveness**: Checks if container is alive
  - Path: `/health`
  - Initial Delay: 60s
  - Period: 30s
  - Timeout: 5s

- **Readiness**: Checks if ready to serve traffic
  - Path: `/health`
  - Initial Delay: 30s
  - Period: 10s
  - Timeout: 5s

---

### 3. Auto-scaling Layer

**Component**: Horizontal Pod Autoscaler (HPA)

**Configuration**:
```yaml
Min Replicas: 2
Max Replicas: 5

Metrics:
  CPU: 70% of requests
  Memory: 80% of requests

Behavior:
  Scale Up:
    Stabilization: 0s (immediate)
    Max Increase: 2 pods or 100%

  Scale Down:
    Stabilization: 300s (5 minutes)
    Max Decrease: 1 pod or 50%
```

**Scaling Logic**:
1. Monitor CPU and memory metrics
2. If either exceeds threshold for 30s → Scale up
3. If both below threshold for 5 min → Scale down
4. Always maintain min 2 replicas for HA

---

### 4. High Availability Layer

**Component**: Pod Disruption Budget (PDB)

**Configuration**:
```yaml
MinAvailable: 1
```

**Purpose**:
- Ensures at least 1 pod is always available during:
  - Node upgrades
  - Cluster maintenance
  - Voluntary disruptions
  - Deployments

---

### 5. Network Security Layer

**Component**: Network Policies

**Ingress Rules** (What can reach flask-app):
- Ingress controller pods
- Pods in same namespace
- Monitoring namespace (for scraping)

**Egress Rules** (What flask-app can reach):
- DNS servers (port 53)
- HTTPS endpoints (port 443) - for external APIs
- HTTP endpoints (port 80)

**Monitoring Namespace**:
- Can scrape metrics from all namespaces
- Internal communication allowed
- DNS resolution allowed

---

### 6. Configuration Management

**Component**: ConfigMaps and Secrets

**ConfigMap** (flask-config):
```yaml
EMBEDDING_MODEL: sentence-transformers/all-MiniLM-L6-v2
RAG_MODEL: llama-3.3-70b-versatile
KEYSPACE_NAME: default_keyspace
COLLECTION_NAME: flipkart_products
FLASK_ENV: production
LOG_LEVEL: INFO
```

**ConfigMap** (flask-data):
- Contains: flipkart_product_review.csv (451 reviews, 144KB)
- Mounted at: /app/data

**Secret** (flask-secrets):
```yaml
GROQ_API_KEY: <encrypted>
ASTRA_DB_APPLICATION_TOKEN: <encrypted>
ASTRA_DB_API_ENDPOINT: <encrypted>
HF_TOKEN: <encrypted>
HUGGINGFACEHUB_TOKEN: <encrypted>
```

---

### 7. Monitoring Layer

**Component**: Prometheus + Grafana

**Prometheus**:
- Scrapes metrics every 15s
- Stores data for 15 days
- Persistent storage: 10Gi PVC
- Auto-discovers pods via annotations
- RBAC: Full cluster read access

**Grafana**:
- Visualizes Prometheus data
- Pre-configured datasource
- Persistent storage: 5Gi PVC
- Default credentials: admin/admin123

**Metrics Collected**:
- `http_requests_total` - Total HTTP requests
- `model_predictions_total` - Total predictions
- Container CPU usage
- Container memory usage
- Pod status
- Network traffic

**Pre-built Dashboard**: "Flipkart Chatbot Metrics"
- Request rate graphs
- Prediction counts
- Resource utilization
- Active pod count
- Pod restart history

---

## Data Flow

### User Request Flow

```
1. User → Load Balancer
   - User sends HTTP request
   - Load balancer performs health check
   - SSL termination (if configured)

2. Load Balancer → Service
   - Routes to flask-service ClusterIP
   - Session affinity based on ClientIP
   - Distributes across healthy pods

3. Service → Pod
   - Selects pod based on load
   - Forwards to port 5000
   - Pod readiness check passed

4. Pod → Application
   - Flask receives request
   - Increments REQUEST_COUNT metric
   - Processes request

5. Application → RAG Agent
   - Extracts user query
   - Creates LangChain message
   - Invokes RAG agent with thread_id

6. RAG Agent → Vector Store
   - Generates embeddings (HuggingFace)
   - Queries AstraDB for similar reviews
   - Retrieves top K relevant documents

7. RAG Agent → LLM
   - Constructs prompt with context
   - Calls Groq API (llama 3.3-70b)
   - Gets response

8. Application → User
   - Formats response
   - Increments PREDICTION_COUNT metric
   - Returns to user

9. Prometheus Scraping (async)
   - Scrapes /metrics endpoint every 15s
   - Stores in time-series database
   - Available for Grafana visualization
```

### Metrics Collection Flow

```
1. Application exposes metrics at /metrics

2. Prometheus discovers pod:
   - Kubernetes service discovery
   - Checks for annotation: prometheus.io/scrape=true
   - Identifies port and path from annotations

3. Prometheus scrapes metrics:
   - HTTP GET /metrics every 15s
   - Parses Prometheus format
   - Stores in TSDB

4. Grafana queries Prometheus:
   - Uses PromQL queries
   - Renders dashboards
   - Updates every refresh interval
```

### Auto-scaling Flow

```
1. Metrics Server collects resource usage

2. HPA checks metrics every 30s:
   - Calculates current CPU/memory utilization
   - Compares against targets (70% CPU, 80% mem)

3. If above threshold:
   - Calculate desired replicas
   - Wait for stabilization (0s for scale up)
   - Increase pods (max 2 or 100%)
   - Update deployment

4. If below threshold:
   - Wait for stabilization (5 min)
   - Decrease pods (max 1 or 50%)
   - Ensure minReplicas (2) not violated
   - Update deployment

5. Kubernetes scheduler:
   - Finds nodes with capacity
   - Schedules new pods
   - Pulls image if not cached
   - Starts containers

6. Readiness probes pass:
   - Service adds pod to endpoints
   - Load balancer includes in pool
   - Pod receives traffic
```

---

## External Dependencies

### AstraDB (Vector Database)
- **Purpose**: Store and query product review embeddings
- **Type**: Managed Cassandra with vector search
- **Data**: 451 product reviews (144KB)
- **Access**: Via ASTRA_DB_API_ENDPOINT with token auth
- **Latency**: ~50-100ms per query

### Groq API (LLM)
- **Purpose**: Generate chatbot responses
- **Model**: llama-3.3-70b-versatile
- **Access**: Via GROQ_API_KEY
- **Rate Limits**: Per Groq account
- **Latency**: ~1-3s per request

### HuggingFace (Embeddings)
- **Purpose**: Generate text embeddings for vector search
- **Model**: sentence-transformers/all-MiniLM-L6-v2
- **Access**: Model downloaded at startup (cached)
- **Token**: HF_TOKEN for authentication
- **Local Inference**: Runs in-pod (no external API call)

---

## Security Architecture

### Defense in Depth

**Layer 1: Network Perimeter**
- GCP Load Balancer with DDoS protection
- Optional: Cloud Armor WAF rules

**Layer 2: Network Policies**
- Restrict pod-to-pod communication
- Whitelist external API endpoints
- Isolate monitoring namespace

**Layer 3: Pod Security**
- Non-root user (UID 1000)
- Read-only root filesystem support
- Capabilities dropped
- No privilege escalation
- Security context constraints

**Layer 4: Secret Management**
- Kubernetes secrets (base64 encoded at rest)
- Not committed to git
- Mounted as environment variables
- Recommendation: Migrate to GCP Secret Manager

**Layer 5: RBAC**
- Service accounts with minimal permissions
- ClusterRole for Prometheus (read-only)
- Namespace isolation

**Layer 6: Application Security**
- Input validation in Flask
- HTTPS for external APIs
- No hardcoded credentials
- Environment-based configuration

---

## Failure Modes and Resilience

### Pod Failure
- **Detection**: Liveness probe fails 3 times
- **Action**: Kubernetes restarts pod
- **Impact**: Minimal (other replicas continue serving)
- **Recovery**: ~60s (startup + readiness)

### Node Failure
- **Detection**: Node becomes unready
- **Action**: Pods rescheduled to healthy nodes
- **Impact**: Temporary capacity reduction
- **Recovery**: ~5 minutes (scheduling + startup)

### AstraDB Unavailable
- **Detection**: Connection timeout
- **Impact**: Queries fail with error
- **User Experience**: Error message displayed
- **Mitigation**: Retry logic (implement in future)

### Groq API Unavailable
- **Detection**: API returns 5xx
- **Impact**: Response generation fails
- **User Experience**: Error message displayed
- **Mitigation**: Fallback to cached responses (implement in future)

### Load Balancer Failure
- **Detection**: Health checks fail
- **Action**: GCP creates new load balancer
- **Impact**: Temporary unavailability (~5 min)
- **Recovery**: Automatic

### Cluster Failure
- **Detection**: Control plane unresponsive
- **Action**: GCP repairs or recreates cluster
- **Impact**: Full outage
- **Recovery**: Varies (typically <1 hour)
- **Mitigation**: Multi-region deployment (future enhancement)

---

## Performance Characteristics

### Expected Latency
- Health check: <50ms
- Chatbot query (cached embeddings): 1-3s
- Chatbot query (cold start): 3-5s
- Metrics endpoint: <10ms

### Throughput
- **Single pod**: ~10-20 req/s (limited by LLM API)
- **2 pods (min)**: ~20-40 req/s
- **5 pods (max)**: ~50-100 req/s

### Resource Usage
- **Per pod**: 500m-1 CPU, 512Mi-1Gi RAM
- **Cluster (3 nodes)**: 6 CPUs, 12Gi RAM total
- **Storage**: 15Gi (Prometheus 10Gi + Grafana 5Gi)

### Scaling Characteristics
- **Scale up**: <2 minutes (pod startup)
- **Scale down**: 5 minutes (stabilization window)
- **Cold start**: ~30s (model loading)

---

## Cost Model

### Compute Costs
- **Autopilot**: $0.10/vCPU-hour, $0.011/GiB-hour
- **Standard (e2-standard-2)**: ~$50/node/month
- **3 nodes**: ~$150/month

### Storage Costs
- **SSD PVCs**: $0.17/GiB/month
- **15Gi total**: ~$10/month

### Network Costs
- **Load Balancer**: ~$20/month
- **Egress**: $0.12/GiB (first 1TB)

### External Services
- **Groq API**: Variable (based on usage)
- **AstraDB**: Free tier or paid ($0.25/million reads)
- **HuggingFace**: Free (model downloads)

### Total Estimated Cost
- **Autopilot**: $110-150/month
- **Standard**: $180/month

---

## Deployment Topology

### Single-Region Deployment (Current)

```
Region: us-central1
Zone: us-central1-a (or auto for Autopilot)

Cluster: 3 nodes (or managed for Autopilot)
  Node 1: 2 CPUs, 4Gi RAM
  Node 2: 2 CPUs, 4Gi RAM
  Node 3: 2 CPUs, 4Gi RAM

Workload Distribution:
  - flask-app pods: Spread across nodes
  - Prometheus: Single pod (stateful)
  - Grafana: Single pod (stateful)
```

### Multi-Region Deployment (Future)

```
Region 1: us-central1
  - Primary cluster
  - Active traffic

Region 2: us-east1
  - Secondary cluster
  - Standby/failover

Load Balancer:
  - Global load balancing
  - Health-based routing
  - Automatic failover
```

---

## Monitoring and Observability

### Metrics
- **Application Metrics**: Request count, prediction count, latency
- **System Metrics**: CPU, memory, network, disk
- **Kubernetes Metrics**: Pod status, HPA events, node health

### Logs
- **Application Logs**: stdout/stderr captured by Kubernetes
- **Access Logs**: Load balancer logs
- **Audit Logs**: GKE audit logs (optional)

### Traces (Future Enhancement)
- **OpenTelemetry**: Distributed tracing
- **Cloud Trace**: GCP-native tracing

### Alerts (Recommended)
- High error rate (>5%)
- High latency (>5s p95)
- Low replica count (<2)
- High resource usage (>90%)
- Pod crash loops
- Node unavailability

---

## Disaster Recovery

### Backup Strategy
- **Application Code**: Git repository
- **Kubernetes Configs**: Git repository
- **Persistent Data**: PVC snapshots
- **Secrets**: Stored in password manager

### Recovery Procedures

**Scenario 1: Single Pod Failure**
- No action needed (auto-restart)

**Scenario 2: Deployment Corruption**
```bash
kubectl rollout undo deployment/flask-app -n default
```

**Scenario 3: Cluster Failure**
```bash
# Restore from backup
./deploy-scripts/setup-gke-cluster.sh
./deploy-scripts/create-secrets.sh
./deploy-scripts/deploy-app.sh
./deploy-scripts/deploy-monitoring.sh
```

**Scenario 4: Data Loss (PVCs)**
```bash
# Restore from snapshot
gcloud compute disks create prometheus-disk-restored \
  --source-snapshot=prometheus-backup-YYYYMMDD
```

### RTO/RPO Targets
- **RTO** (Recovery Time Objective): 1 hour
- **RPO** (Recovery Point Objective): 24 hours (daily snapshots)

---

## Future Enhancements

### Short-term (1-3 months)
- [ ] Redis for distributed session storage
- [ ] Cloud Logging integration
- [ ] Grafana alerting rules
- [ ] TLS/SSL certificates
- [ ] Custom domain setup

### Medium-term (3-6 months)
- [ ] Multi-region deployment
- [ ] Cloud CDN for static assets
- [ ] Rate limiting and quotas
- [ ] Advanced monitoring (APM)
- [ ] Security scanning in CI/CD

### Long-term (6-12 months)
- [ ] Service mesh (Istio)
- [ ] Blue-green deployments
- [ ] Canary releases
- [ ] A/B testing framework
- [ ] ML model versioning

---

## References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [Flask Production Deployment](https://flask.palletsprojects.com/en/latest/deploying/)

---

**Document Version**: 1.0
**Last Updated**: 2026-01-29
**Author**: Claude Code
