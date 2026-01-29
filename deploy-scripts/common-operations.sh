#!/bin/bash

# Common Operations Script
# Quick access to frequently used commands

set -e

echo "========================================="
echo "Common GKE Operations Menu"
echo "========================================="
echo ""
echo "Select an operation:"
echo ""
echo "Status & Monitoring:"
echo "  1) View application status"
echo "  2) View application logs"
echo "  3) View monitoring status"
echo "  4) Access Prometheus"
echo "  5) Access Grafana"
echo ""
echo "Testing:"
echo "  6) Test health endpoint"
echo "  7) Test chatbot API"
echo "  8) Load test application"
echo ""
echo "Management:"
echo "  9) Scale deployment manually"
echo "  10) Restart pods"
echo "  11) Update image"
echo "  12) Rollback deployment"
echo ""
echo "Debugging:"
echo "  13) Get pod shell"
echo "  14) View pod events"
echo "  15) Check resource usage"
echo "  16) View HPA status"
echo ""
echo "Information:"
echo "  17) Get external IP"
echo "  18) View all resources"
echo "  19) Export logs"
echo ""
echo "  0) Exit"
echo ""

read -p "Enter your choice [0-19]: " choice

case $choice in
  1)
    echo "Application Status:"
    kubectl get pods -n default -l app=flask-app
    echo ""
    kubectl get svc flask-service -n default
    echo ""
    kubectl get ingress flask-ingress -n default
    echo ""
    kubectl get hpa flask-hpa -n default
    ;;

  2)
    echo "Showing application logs (Ctrl+C to exit)..."
    kubectl logs -f -l app=flask-app -n default --tail=50
    ;;

  3)
    echo "Monitoring Stack Status:"
    kubectl get pods -n monitoring
    echo ""
    kubectl get svc -n monitoring
    echo ""
    kubectl get pvc -n monitoring
    ;;

  4)
    echo "Starting Prometheus port-forward..."
    echo "Access at: http://localhost:9090"
    echo "Press Ctrl+C to stop"
    kubectl port-forward -n monitoring svc/prometheus-service 9090:9090
    ;;

  5)
    echo "Starting Grafana port-forward..."
    echo "Access at: http://localhost:3000"
    echo "Login: admin / admin123"
    echo "Press Ctrl+C to stop"
    kubectl port-forward -n monitoring svc/grafana-service 3000:3000
    ;;

  6)
    EXTERNAL_IP=$(kubectl get ingress flask-ingress -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [ -z "$EXTERNAL_IP" ]; then
      echo "External IP not yet assigned. Using port-forward instead..."
      echo "Testing via port-forward..."
      kubectl port-forward svc/flask-service 8080:80 -n default &
      PF_PID=$!
      sleep 3
      curl -f http://localhost:8080/health
      kill $PF_PID
    else
      echo "Testing health endpoint at $EXTERNAL_IP..."
      curl -f http://$EXTERNAL_IP/health
    fi
    ;;

  7)
    EXTERNAL_IP=$(kubectl get ingress flask-ingress -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [ -z "$EXTERNAL_IP" ]; then
      echo "External IP not yet assigned."
      exit 1
    fi
    read -p "Enter your question: " QUESTION
    echo "Sending request..."
    curl -X POST http://$EXTERNAL_IP/get \
      -d "msg=$QUESTION" \
      -H "Content-Type: application/x-www-form-urlencoded"
    echo ""
    ;;

  8)
    EXTERNAL_IP=$(kubectl get ingress flask-ingress -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [ -z "$EXTERNAL_IP" ]; then
      echo "External IP not yet assigned."
      exit 1
    fi
    echo "Running load test..."
    echo "Watch HPA in another terminal: kubectl get hpa flask-hpa -n default --watch"
    read -p "Number of requests [1000]: " REQUESTS
    REQUESTS=${REQUESTS:-1000}
    read -p "Concurrent requests [10]: " CONCURRENT
    CONCURRENT=${CONCURRENT:-10}

    command -v ab >/dev/null 2>&1 || { echo "Apache Bench (ab) not installed. Install with: apt install apache2-utils"; exit 1; }
    ab -n $REQUESTS -c $CONCURRENT http://$EXTERNAL_IP/
    ;;

  9)
    read -p "Enter desired number of replicas: " REPLICAS
    echo "Scaling deployment to $REPLICAS replicas..."
    kubectl scale deployment/flask-app --replicas=$REPLICAS -n default
    kubectl get pods -n default -l app=flask-app
    ;;

  10)
    echo "Restarting pods..."
    kubectl rollout restart deployment/flask-app -n default
    kubectl rollout status deployment/flask-app -n default
    ;;

  11)
    read -p "Enter GCP Project ID: " PROJECT_ID
    read -p "Enter new image tag [latest]: " TAG
    TAG=${TAG:-latest}
    echo "Updating deployment to use gcr.io/$PROJECT_ID/flask-app:$TAG..."
    kubectl set image deployment/flask-app \
      flask-app=gcr.io/$PROJECT_ID/flask-app:$TAG \
      -n default
    kubectl rollout status deployment/flask-app -n default
    ;;

  12)
    echo "Rolling back deployment..."
    kubectl rollout undo deployment/flask-app -n default
    kubectl rollout status deployment/flask-app -n default
    echo "Rollback complete!"
    ;;

  13)
    POD=$(kubectl get pods -n default -l app=flask-app -o jsonpath='{.items[0].metadata.name}')
    echo "Opening shell in pod: $POD"
    kubectl exec -it $POD -n default -- /bin/sh
    ;;

  14)
    echo "Recent events:"
    kubectl get events -n default --sort-by='.lastTimestamp' | grep flask-app
    ;;

  15)
    echo "Resource Usage:"
    echo ""
    echo "Nodes:"
    kubectl top nodes
    echo ""
    echo "Pods:"
    kubectl top pods -n default
    echo ""
    kubectl top pods -n monitoring
    ;;

  16)
    echo "HPA Status:"
    kubectl get hpa -n default
    echo ""
    kubectl describe hpa flask-hpa -n default
    ;;

  17)
    EXTERNAL_IP=$(kubectl get ingress flask-ingress -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [ -z "$EXTERNAL_IP" ]; then
      echo "External IP not yet assigned. Waiting..."
      kubectl get ingress flask-ingress -n default --watch
    else
      echo "External IP: $EXTERNAL_IP"
      echo ""
      echo "Health endpoint: http://$EXTERNAL_IP/health"
      echo "Metrics endpoint: http://$EXTERNAL_IP/metrics"
      echo "Application: http://$EXTERNAL_IP/"
    fi
    ;;

  18)
    echo "All Resources:"
    echo ""
    echo "=== Default Namespace ==="
    kubectl get all -n default
    echo ""
    echo "=== Monitoring Namespace ==="
    kubectl get all -n monitoring
    echo ""
    echo "=== ConfigMaps ==="
    kubectl get configmap -n default
    echo ""
    echo "=== Secrets ==="
    kubectl get secrets -n default
    echo ""
    echo "=== PVCs ==="
    kubectl get pvc -n monitoring
    ;;

  19)
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    echo "Exporting logs to logs_$TIMESTAMP.txt..."
    kubectl logs -l app=flask-app -n default --tail=1000 > logs_$TIMESTAMP.txt
    echo "Logs exported to: logs_$TIMESTAMP.txt"
    ;;

  0)
    echo "Exiting..."
    exit 0
    ;;

  *)
    echo "Invalid choice. Please select 0-19."
    exit 1
    ;;
esac

echo ""
echo "Operation completed!"
echo ""
