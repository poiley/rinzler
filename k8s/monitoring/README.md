# Rinzler Grid Monitoring

## Overview

Comprehensive monitoring solution using Prometheus and Grafana, managed by ArgoCD.

## Components

### Monitoring Stack
- **Prometheus** - Metrics collection and storage
- **Grafana** - Visualization and dashboards
- **Node Exporter** - System metrics
- **Exportarr** - Detailed *arr service metrics
- **Tautulli Exporter** - Plex/Tautulli metrics

### Services Monitored

| Service | Metrics Source | Dashboard |
|---------|---------------|-----------|
| System/Hardware | Node Exporter | Import ID: 1860 |
| Kubernetes | Prometheus | Import ID: 6417 |
| ArgoCD | Native metrics | Import ID: 14584 |
| Radarr/Sonarr/Lidarr | Exportarr | Custom dashboard |
| Plex/Tautulli | Tautulli Exporter | Custom dashboard |
| Traefik | Native metrics | Import ID: 11462 |

## Access

- **Grafana**: http://grafana.rinzler.grid
  - Username: admin
  - Password: admin

## ArgoCD Management

This monitoring stack is fully managed by ArgoCD:

```bash
# View monitoring applications
kubectl get applications -n argocd | grep monitoring

# Sync manually if needed
kubectl patch application monitoring-base -n argocd --type merge \
  -p '{"operation": {"initiatedBy": {"username": "admin"}, "sync": {}}}'
```

## Adding API Keys

All API keys are managed through the centralized secrets system:

1. Edit `.env.secrets` in the repository root
2. Run `./scripts/apply-secrets.sh`
3. ArgoCD will automatically sync the changes

## Custom Dashboards

Pre-configured dashboards are available in the `dashboards/` directory:
- `rinzler-services-dashboard.json` - Overall service health
- `arr-services-dashboard.json` - Detailed *arr metrics

To import:
1. Go to Grafana → Dashboards → Import
2. Upload the JSON file
3. Select Prometheus as the data source