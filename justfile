# MathTrail Observability Stack

monitoring_ns := env("MONITORING_NAMESPACE", "monitoring")
app_ns := env("NAMESPACE", "mathtrail")

# Deploy observability stack
deploy:
    skaffold run

# Delete observability stack and namespace
delete:
    skaffold delete
    kubectl delete namespace {{monitoring_ns}} --wait --timeout=120s
    @echo "Waiting for namespace to fully terminate..."
    kubectl wait --for=delete namespace/{{monitoring_ns}} --timeout=120s 2>/dev/null || true

# Port-forward to Grafana
grafana:
    kubectl port-forward -n {{monitoring_ns}} svc/lgtm-grafana 3000:80

# Port-forward to Pyroscope
pyroscope:
    kubectl port-forward -n {{monitoring_ns}} svc/pyroscope 4040:4040

# View OTel Collector logs
logs-otel:
    kubectl logs -n {{monitoring_ns}} deployment/otel-collector-opentelemetry-collector -f

# View Grafana logs
logs-grafana:
    kubectl logs -n {{monitoring_ns}} deployment/lgtm-grafana -f

# Check health
health:
    @echo "=== Pods ==="
    kubectl get pods -n {{monitoring_ns}}
    @echo ""
    @echo "=== Services ==="
    kubectl get svc -n {{monitoring_ns}}
    @echo ""
    @echo "=== Dapr Configuration ==="
    kubectl get configuration -n {{app_ns}}

# Test OTel Collector endpoint
test-otel:
    #!/usr/bin/env bash
    set -euo pipefail
    kubectl port-forward -n {{monitoring_ns}} svc/otel-collector-opentelemetry-collector 13133:13133 &
    PID=$!
    sleep 2
    curl -s http://localhost:13133/health || true
    kill $PID || true
