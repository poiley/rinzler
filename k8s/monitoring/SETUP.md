# Rinzler Grid Monitoring Setup

## Overview
This monitoring dashboard provides a unified view of all your media services, download clients, and infrastructure components without requiring Prometheus or Grafana.

## Features
- Real-time health monitoring of all services
- API-based data collection for detailed metrics
- Dark-themed web dashboard with auto-refresh
- No external dependencies or databases
- Lightweight Go backend with embedded HTML frontend

## Prerequisites
1. Docker installed for building the image
2. kubectl configured to access your cluster
3. API keys from your services (see below)

## Getting API Keys

### Plex
1. Sign in to Plex Web App
2. Browse to any media item
3. Click "..." and select "Get Info"
4. Click "View XML"
5. Look for `X-Plex-Token` in the URL

### Radarr/Sonarr/Readarr/Lidarr
1. Open the web UI
2. Go to Settings → General
3. Copy the API Key

### Bazarr
1. Open the web UI
2. Go to Settings → General
3. Copy the API Key under "Security"

### Jackett
1. Open the web UI
2. API Key is displayed in the top right corner

### Tautulli
1. Open the web UI
2. Go to Settings → Web Interface
3. Copy the API Key

### ArgoCD
```bash
# Login to ArgoCD first
argocd login argocd-server.argocd.svc.cluster.local

# Generate token
argocd account generate-token
```

### Transmission
If you have authentication enabled:
- Username and password from your settings.json

## Installation

1. **Configure API Keys**
   Add your API keys to the `.env.secrets` file in the root of the repository:
   ```bash
   cd /home/poile/repos/rinzler
   cp .env.secrets.example .env.secrets
   # Edit .env.secrets and add your API keys
   ```

2. **Apply Secrets**
   ```bash
   ./scripts/apply-secrets.sh
   ```

3. **Build and Deploy**
   ```bash
   cd k8s/monitoring
   ./build-and-deploy.sh
   ```

4. **Access the Dashboard**
   Open http://monitoring.rinzler.grid in your browser

## Dashboard Features

### Service Cards
Each service displays:
- Health status (green = healthy, red = unhealthy)
- Service type (media, arr-stack, download, infrastructure)
- Current status message
- Service-specific metrics (when available)
- Last check timestamp

### Metrics Displayed
- **Plex**: Server version
- **Radarr/Sonarr**: Queue size, health issues, version
- **ArgoCD**: Total apps, synced/out-of-sync/degraded counts
- **Tautulli**: Active streams
- **Bazarr**: Version
- **Others**: Basic health status

### Auto-Refresh
The dashboard automatically refreshes every 30 seconds, with a countdown timer displayed at the top.

## Troubleshooting

### Service Shows "No API key configured"
- Verify the API key is set in `.env.secrets` file
- Reapply secrets: `./scripts/apply-secrets.sh`
- Restart the collector: `kubectl rollout restart deployment/monitoring-collector -n monitoring`

### Service Shows "Connection error"
- Check the service URL in `collector-deployment.yaml`
- Verify the service is running: `kubectl get pods -A`
- Check network connectivity from the monitoring pod

### Dashboard Not Loading
- Check pod status: `kubectl get pods -n monitoring`
- View logs: `kubectl logs -n monitoring deployment/monitoring-collector`
- Verify ingress: `kubectl get ingress -n monitoring`

## Customization

### Change Refresh Interval
Edit `main.go` line with `time.Sleep(30 * time.Second)` to adjust backend polling frequency.

### Add New Services
1. Add configuration in the `Config` struct
2. Add environment variables in `loadConfig()`
3. Create a check function like `checkServiceHealth()`
4. Add the check to `collectMetrics()`
5. Update deployment and secrets YAML files

### Modify Dashboard Style
The dashboard HTML/CSS is embedded in `main.go` in the `dashboardHTML` constant. Edit and rebuild to customize appearance.

## Maintenance

### View Logs
```bash
kubectl logs -n monitoring deployment/monitoring-collector -f
```

### Restart Collector
```bash
kubectl rollout restart deployment/monitoring-collector -n monitoring
```

### Update Image
```bash
# Make changes to main.go
cd collector
docker build -t rinzler/monitoring-collector:latest .
docker save rinzler/monitoring-collector:latest | sudo k3s ctr images import -
kubectl rollout restart deployment/monitoring-collector -n monitoring
```