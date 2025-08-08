# Uptime Kuma

Uptime Kuma is a self-hosted monitoring tool for tracking the uptime of services.

## Deployment

This deployment uses the official Uptime Kuma Helm chart via ArgoCD.

### Features
- Monitors HTTP(s), TCP, DNS, and other protocols
- Status page generation
- Multiple notification channels (Discord, Slack, Email, etc.)
- Persistent storage for configuration and history
- HTTPS enabled with cert-manager

### Access
- Primary URL: https://uptime.rinzler.cloud
- Alternative URL: https://uptime.rinzler.me

### Configuration
- Namespace: `monitoring`
- Storage: 5Gi persistent volume
- Auto-sync enabled via ArgoCD

### Initial Setup
1. Apply the ArgoCD application:
   ```bash
   kubectl apply -f k8s/argocd/applications/uptime-kuma.yaml
   ```

2. Wait for deployment:
   ```bash
   kubectl -n monitoring wait --for=condition=available --timeout=300s deployment/uptime-kuma
   ```

3. Access the web interface and create your admin account on first login

### Monitoring Targets
Suggested services to monitor:
- Internal Services:
  - Plex: http://plex.media.svc.cluster.local:32400
  - Sonarr: http://sonarr.arr-stack.svc.cluster.local:8989
  - Radarr: http://radarr.arr-stack.svc.cluster.local:7878
  - Bazarr: http://bazarr.arr-stack.svc.cluster.local:6767
  - Grafana: http://grafana.monitoring.svc.cluster.local:3000
  - ArgoCD: http://argocd-server.argocd.svc.cluster.local:80
  
- External URLs (via Ingress):
  - https://plex.rinzler.cloud
  - https://sonarr.rinzler.cloud
  - https://radarr.rinzler.cloud
  - https://grafana.rinzler.cloud
  - https://argocd.rinzler.cloud