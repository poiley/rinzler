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

3. Access the web interface at https://uptime.rinzler.cloud
4. Create your admin account on first login
5. Add monitors via the web UI (see suggested monitors below)

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

### Monitor Configuration

#### Manual Setup (Recommended for initial deployment)
Use the Uptime Kuma web UI to add monitors. This is the simplest approach and allows you to:
- Test connectivity before saving
- Configure notifications interactively
- Set up status pages visually

#### Future Automation Options
If you need to automate monitor creation later, consider:

1. **Uptime Kuma API** - Write scripts using the REST API
2. **AutoKuma** - For Docker label-based discovery (complex setup)
3. **Terraform Provider** - If using Terraform for infrastructure

See `monitors-example.yaml` for a template of monitors to add.