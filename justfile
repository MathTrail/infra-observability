# MathTrail Observability Stack

# Default recipe
default:
    @just --list

# Deploy observability stack
deploy:
    skaffold run

# Delete observability stack
delete:
    skaffold delete

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
