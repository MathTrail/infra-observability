# MathTrail Observability Stack

Observability infrastructure for the MathTrail platform — includes OpenTelemetry Collector, Grafana LGTM stack (Loki, Tempo, Mimir, Grafana), and Pyroscope for continuous profiling.

## Architecture

```
Dapr Sidecars → Zipkin (9411) → OTel Collector → k8sattributes → OTLP → Grafana Alloy → LGTM Stack
Services → OTLP (4317/4318) → OTel Collector → k8sattributes → OTLP → Grafana Alloy → LGTM Stack
Go Services → Pyroscope SDK → Pyroscope (4040) → Grafana
```

**Components:**
- **OpenTelemetry Collector**: Smart gateway receiving Zipkin traces from Dapr, OTLP from services
- **Grafana LGTM**: Loki (logs), Tempo (traces), Mimir (metrics), Grafana (visualization)
- **Pyroscope**: Continuous profiling for Go services
- **Namespace**: monitoring

## Quick Start

```bash
# Deploy observability stack
skaffold run

# Or use automation
just deploy

# Access Grafana
just grafana
# Open http://localhost:3000 (admin/mathtrail)

# Access Pyroscope
just pyroscope
# Open http://localhost:4040

# Check health
just health
```

## Deployment from Root

```bash
cd d:\Projects\MathTrail\core

# Deploy only observability
skaffold run -p infra-observability

# Deploy all infrastructure (including observability)
skaffold run -p all-infra

# Deploy everything
skaffold run
```

## Service Integration

### Dapr Tracing

Services with Dapr sidecars automatically send traces once the Dapr Configuration is applied. The configuration points Dapr to the OTel Collector:

```yaml
# manifests/dapr-configuration.yaml
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: mathtrail-observability
spec:
  tracing:
    samplingRate: "1"
    zipkin:
      endpointAddress: "http://otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:9411/api/v2/spans"
```

### Pyroscope Profiling (Go Services)

Add the Pyroscope SDK to Go services:

```go
import "github.com/grafana/pyroscope-go"

func main() {
    pyroscope.Start(pyroscope.Config{
        ApplicationName: "profile-api",
        ServerAddress:   "http://pyroscope.monitoring.svc.cluster.local:4040",
        ProfileTypes: []pyroscope.ProfileType{
            pyroscope.ProfileCPU,
            pyroscope.ProfileAllocObjects,
            pyroscope.ProfileAllocSpace,
            pyroscope.ProfileInuseObjects,
            pyroscope.ProfileInuseSpace,
        },
    })
    // Application code...
}
```

## DNS Service Names

| Service | DNS | Port | Usage |
|---------|-----|------|-------|
| OTel Collector | `otel-collector-opentelemetry-collector.monitoring.svc.cluster.local` | 9411 | Dapr Zipkin traces |
| OTel Collector | `otel-collector-opentelemetry-collector.monitoring.svc.cluster.local` | 4317 | OTLP gRPC |
| OTel Collector | `otel-collector-opentelemetry-collector.monitoring.svc.cluster.local` | 4318 | OTLP HTTP |
| Grafana | `lgtm-grafana.monitoring.svc.cluster.local` | 80 | Dashboard UI |
| Pyroscope | `pyroscope.monitoring.svc.cluster.local` | 4040 | Profile push |
| Loki | `loki.monitoring.svc.cluster.local` | 3100 | Log queries |
| Tempo | `tempo.monitoring.svc.cluster.local` | 3200 | Trace queries |
| Mimir | `mimir.monitoring.svc.cluster.local` | 9009 | Metric queries |

## Verification

### Check Pods

```bash
kubectl get pods -n monitoring

# Expected:
# - lgtm-alloy-receiver-*
# - lgtm-alloy-logs-* (DaemonSet)
# - lgtm-alloy-metrics-* (DaemonSet)
# - lgtm-grafana-*
# - loki-*
# - tempo-*
# - mimir-*
# - pyroscope-*
# - otel-collector-opentelemetry-collector-*
```

### Test OTel Collector

```bash
# Check health endpoint
kubectl port-forward -n monitoring svc/otel-collector-opentelemetry-collector 13133:13133
curl http://localhost:13133/health

# Check metrics
kubectl port-forward -n monitoring svc/otel-collector-opentelemetry-collector 8888:8888
curl http://localhost:8888/metrics | grep otelcol_receiver
```

### Verify in Grafana

Open http://localhost:3000 (after running `just grafana`), login with `admin`/`mathtrail`:

1. **Datasources**: Configuration → Data Sources → Verify Loki, Tempo, Mimir, Pyroscope all green
2. **Logs**: Explore → Loki → Query `{namespace="mathtrail"}`
3. **Traces**: Explore → Tempo → Search for service traces
4. **Metrics**: Explore → Mimir → Query `up{job="otel-collector"}`
5. **Profiling**: Explore → Pyroscope → Query for service names

## Troubleshooting

### OTel Collector Issues

```bash
# Check logs
kubectl logs -n monitoring deployment/otel-collector-opentelemetry-collector

# Common issues:
# - LGTM Alloy not ready: kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy-receiver
# - RBAC missing: kubectl get clusterrole otel-collector
# - Config error: Review values/otel-collector-values.yaml
```

### Dapr Not Sending Traces

```bash
# Check configuration
kubectl get configuration -n mathtrail
kubectl describe configuration mathtrail-observability -n mathtrail

# Test connectivity from mathtrail namespace
kubectl run -n mathtrail -it --rm debug --image=busybox --restart=Never -- sh
# Inside pod:
nslookup otel-collector-opentelemetry-collector.monitoring.svc.cluster.local
wget -O- http://otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:9411
```

### No Logs in Loki

```bash
# Check Alloy logs collector
kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy-logs
kubectl logs -n monitoring daemonset/lgtm-alloy-logs
```

## Production Considerations

- **Resources**: Increase CPU/memory for OTel Collector (4 CPU, 8Gi), storage (100Gi)
- **Sampling**: Reduce trace sampling to 10% (`samplingRate: "0.1"`)
- **Retention**: Configure Loki/Tempo/Mimir retention (7-30 days)
- **HA**: Increase replicas for OTel Collector (3), Alloy receiver (3)
- **Storage**: Use S3-compatible storage for Loki, Tempo, Pyroscope

## Documentation

- Architecture: [core/docs/architecture/observability.md](../core/docs/architecture/observability.md)
- Implementation Plan: [C:\Users\Alexander\.claude\plans\bubbly-toasting-kernighan.md](C:\Users\Alexander\.claude\plans\bubbly-toasting-kernighan.md)

## License

Apache 2.0
