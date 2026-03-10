# MathTrail Observability Stack
# Deployment is managed exclusively by ArgoCD (mathtrail-observability-* Applications).

monitoring_ns := env("MONITORING_NAMESPACE", "monitoring")
app_ns := env("NAMESPACE", "mathtrail")

# Trigger ArgoCD sync for all observability Applications
sync:
    argocd app sync mathtrail-observability-base
    argocd app sync mathtrail-observability-loki mathtrail-observability-tempo mathtrail-observability-mimir
    argocd app sync mathtrail-observability-grafana mathtrail-observability-alloy mathtrail-observability-pyroscope mathtrail-observability-otel-collector

# Show status of all observability Applications
status:
    argocd app list -l app.kubernetes.io/part-of=mathtrail | grep observability

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

# Test OTel Collector endpoint
test-otel:
    #!/usr/bin/env bash
    set -euo pipefail
    kubectl port-forward -n {{monitoring_ns}} svc/otel-collector-opentelemetry-collector 13133:13133 &
    PID=$!
    sleep 2
    curl -s http://localhost:13133/health || true
    kill $PID || true
