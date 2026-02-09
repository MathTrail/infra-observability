# mathtrail-infrastructure-observability
Observability infrastructure for the MathTrail platform — includes OpenTelemetry configuration, monitoring, logging, and dashboards for tracking system performance and user activity.

OpenTelemetry + OpenTelemetry Collector + Grafana LGTM + Grafana Pyroscope (with Dapr integration)

OpenTelemetry Collector остается «умным шлюзом» для Dapr, но теперь он будет пересылать данные не в разрозненные чарты, а в единую точку входа нового стека.

1. Добавляем репозитории
Bash
используем mathtrail-charts
helm repo update

2. Конфигурация OTel Collector (otel-collector-values.yaml)
В этом стеке Коллектор работает как прокси: он принимает «грязный» трафик от Dapr, обогащает его метаданными Kubernetes и отправляет в Grafana Alloy (внутри k8s-monitoring).

YAML
mode: deployment

config:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318
    zipkin: # Для Dapr
      endpoint: 0.0.0.0:9411

  processors:
    k8sattributes: # Обогащаем данные именами подов и пространств имен
      auth_type: "kubeconfig"
      passthrough: false
      extract:
        metadata: [k8s.pod.name, k8s.namespace.name, k8s.node.name]

  exporters:
    # Отправляем всё в Grafana Alloy (входную точку k8s-monitoring)
    otlp/alloy:
      endpoint: "lgtm-alloy-receiver.monitoring.svc.cluster.local:4317"
      tls:
        insecure: true

  service:
    pipelines:
      metrics:
        receivers: [otlp]
        processors: [k8sattributes]
        exporters: [otlp/alloy]
      traces:
        receivers: [otlp, zipkin]
        processors: [k8sattributes]
        exporters: [otlp/alloy]
      logs:
        receivers: [otlp]
        processors: [k8sattributes]
        exporters: [otlp/alloy]
3. Интеграция с Dapr
Dapr по-прежнему использует протокол Zipkin для отправки трасс в коллектор.

YAML
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: dapr-observability
spec:
  tracing:
    samplingRate: "1" 
    zipkin:
      endpointAddress: "http://otel-collector.monitoring.svc.cluster.local:9411/v1/spans"
  metric:
    enabled: true
4. Pyroscope (Continuous Profiling)
Pyroscope теперь интегрируется в Grafana бесшовно. В коде на Go ничего не меняется, но данные теперь можно смотреть прямо в дашбордах Grafana рядом с логами.

Go
import "github.com/grafana/pyroscope-go"

func main() {
    pyroscope.Start(pyroscope.Config{
        ApplicationName: "profile-service",
        ServerAddress:   "http://pyroscope.monitoring.svc.cluster.local:4040",
        // В 2026 году Pyroscope поддерживает OTLP-профилирование
    })
    // ...
}
5. Обновленный порядок установки (Helm)
Теперь мы устанавливаем k8s-monitoring как сердце системы.

Устанавливаем основной стек (LGTM):

Bash
helm install lgtm grafana/k8s-monitoring \
  --namespace monitoring --create-namespace \
  --set cluster.name=pangolin-cluster \
  --set loki.enabled=true \
  --set tempo.enabled=true \
  --set mimir.enabled=true \
  --set grafana.enabled=true
Устанавливаем Pyroscope:

Bash
helm install pyroscope grafana/pyroscope --namespace monitoring
Устанавливаем OTel Collector:

Bash
helm install otel-collector open-telemetry/opentelemetry-collector \
  --namespace monitoring \
  -f otel-collector-values.yaml