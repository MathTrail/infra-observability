# MathTrail Observability Stack

# Ensure namespaces exist (idempotent)
setup:
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace mathtrail --dry-run=client -o yaml | kubectl apply -f -

# Deploy observability stack
deploy: setup
    skaffold run

# Delete observability stack (namespace preserved to avoid finalizer deadlock)
delete:
    skaffold delete
    @echo "Stack removed. Namespace 'monitoring' preserved."

# Full purge: delete stack then remove namespaces
purge: delete
    kubectl delete namespace monitoring --wait --timeout=120s
    @echo "Namespace 'monitoring' deleted."

# Restart OTel Collector
restart-otel:
    kubectl rollout restart deployment/otel-collector-opentelemetry-collector -n monitoring

# Restart LGTM stack
restart-lgtm:
    kubectl rollout restart deployment/lgtm-grafana -n monitoring
    kubectl rollout restart statefulset/loki -n monitoring || true
    kubectl rollout restart statefulset/tempo -n monitoring || true
    kubectl rollout restart statefulset/mimir -n monitoring || true

# Port-forward to Grafana
grafana:
    kubectl port-forward -n monitoring svc/lgtm-grafana 3000:80

# Port-forward to Pyroscope
pyroscope:
    kubectl port-forward -n monitoring svc/pyroscope 4040:4040

# View OTel Collector logs
logs-otel:
    kubectl logs -n monitoring deployment/otel-collector-opentelemetry-collector -f

# View Grafana logs
logs-grafana:
    kubectl logs -n monitoring deployment/lgtm-grafana -f

# Check health
health:
    @echo "=== Pods ==="
    kubectl get pods -n monitoring
    @echo ""
    @echo "=== Services ==="
    kubectl get svc -n monitoring
    @echo ""
    @echo "=== Dapr Configuration ==="
    kubectl get configuration -n mathtrail

# Test OTel Collector endpoint
test-otel:
    #!/usr/bin/env bash
    set -euo pipefail
    kubectl port-forward -n monitoring svc/otel-collector-opentelemetry-collector 13133:13133 &
    PID=$!
    sleep 2
    curl -s http://localhost:13133/health || true
    kill $PID || true
