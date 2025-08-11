# Monitoring Setup

## Stack Components

- **Prometheus**: Metrics collection
- **Grafana**: Dashboards (https://grafana.rinzler.me)
- **Uptime Kuma**: Service uptime monitoring (https://uptime-kuma.rinzler.me)
- **AutoKuma**: Kubernetes CRD-based monitor management

## Uptime Kuma Configuration

### Adding Monitors via CRDs

Create a KumaEntity resource:
```yaml
apiVersion: uptime-kuma.autokuma.io/v1
kind: KumaEntity
metadata:
  name: service-monitor
  namespace: monitoring
spec:
  monitor:
    name: "Service Name"
    url: "https://service.rinzler.me"
    type: "http"
    interval: 60
    retryInterval: 60
    maxretries: 3
    accepted_statuscodes: ["200-299"]
```

Apply: `kubectl apply -f monitor.yaml`

### Monitored Services

All media stack, arr stack, and infrastructure services are monitored automatically via AutoKuma CRDs.

## Alerting

Uptime Kuma triggers alerts on:
- Service down >2 minutes
- SSL certificate expiring <7 days
- Response time >5 seconds
- Multiple consecutive failures

Configure notification channels in Uptime Kuma UI:
- Email, Discord, Slack, Telegram, webhooks

## Troubleshooting

```bash
# Check AutoKuma sync
kubectl logs -n monitoring deployment/autokuma

# List all monitors
kubectl get kumaentities -n monitoring

# Check Uptime Kuma database
kubectl exec -n monitoring deployment/uptime-kuma -it -- \
  sqlite3 /app/data/kuma.db "SELECT * FROM monitor;"
```

Common issues:
- **Monitors not appearing**: Check AutoKuma logs and RBAC permissions
- **False positives**: Increase retry intervals or timeout values
- **High memory**: Adjust AutoKuma memory limits in deployment