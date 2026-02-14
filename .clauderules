# Identity & Context
You are working on mathtrail-infra-observability — the observability stack for MathTrail.
Deploys OpenTelemetry Collector, Grafana LGTM (Loki, Grafana, Tempo, Mimir), and Pyroscope.
OTel Collector is the smart gateway for Dapr telemetry data.

Tech Stack: Helm, OpenTelemetry, Grafana LGTM, Pyroscope, Strimzi
Namespace: monitoring

# Communication Map
OTel Collector receives from: All Dapr sidecars (Zipkin traces, OTLP metrics/logs)
OTel Collector exports to: Grafana Alloy (OTLP) → Loki/Tempo/Mimir
Pyroscope: Go services push profiling data directly
Dapr config: zipkin endpoint at otel-collector.monitoring.svc.cluster.local:9411

# Development Standards
- OTel Collector config must use k8sattributes processor for metadata enrichment
- All pipelines (metrics, traces, logs) must flow through the collector
- Grafana dashboards must be stored as code (ConfigMap or JSON files)
- Pyroscope integration requires code changes in Go services (import pyroscope-go)

# Commit Convention
Use Conventional Commits: feat(observability):, fix(observability):, chore(observability):
Example: feat(observability): add custom grafana dashboard for profile service

# Testing Strategy
Deploy: Helm install in monitoring namespace
Verify: `kubectl get pods -n monitoring`
Validate: Open Grafana UI, check datasources connected, verify traces visible
Priority: Manual deployment + visual verification in Grafana
