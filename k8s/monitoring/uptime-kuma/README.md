# Uptime Kuma with AutoKuma

Fully automated uptime monitoring with Uptime Kuma and AutoKuma for GitOps-managed monitor configuration.

## Deployment

This deployment includes:
- **Uptime Kuma**: Self-hosted monitoring tool
- **AutoKuma**: Automated monitor management from Git

### Features
- **Fully Automated**: No manual configuration needed
- **GitOps Managed**: All monitors defined in ConfigMaps
- **Auto-sync**: Changes in Git automatically update monitors
- **Comprehensive Monitoring**: Internal and external endpoints
- **Persistent Storage**: Configuration and history preserved
- **HTTPS Enabled**: Secure access with cert-manager

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

2. Wait for deployments:
   ```bash
   kubectl -n monitoring wait --for=condition=available --timeout=300s deployment/uptime-kuma deployment/autokuma
   ```

3. Access https://uptime.rinzler.cloud
   - Username: `admin`
   - Password: `password` (change this after deployment!)
   
4. All monitors are automatically configured by AutoKuma!

**Note**: The admin account is automatically created by the init container. No manual setup required!

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

### How It Works

1. **Init Container** starts Uptime Kuma temporarily to create database schema
2. **Init Container** injects admin account directly into SQLite database
3. **Uptime Kuma** starts with pre-configured admin account
4. **AutoKuma** waits for Uptime Kuma to be ready
5. **AutoKuma** authenticates using the pre-configured credentials
6. **AutoKuma** reads monitor definitions from ConfigMaps and creates them
7. Any changes to ConfigMaps are automatically synced

### Monitor Management

#### Automated Configuration
AutoKuma automatically manages all monitors based on ConfigMaps:

1. **View current monitors**: Check `autokuma-monitors-configmap.yaml`
2. **Add new monitors**: Edit the appropriate JSON section in the ConfigMap
3. **Deploy changes**: Commit, push, and ArgoCD will sync

Example adding a new monitor:
```json
{
  "name": "My New Service",
  "type": "http",
  "url": "http://my-service.namespace.svc.cluster.local:8080",
  "interval": 60,
  "tags": ["custom", "internal"]
}
```

#### Monitor Organization
Monitors are organized by category in separate JSON files within the ConfigMap:
- `infrastructure.json` - Core cluster services
- `monitoring.json` - Observability stack
- `media.json` - Media streaming services
- `arr-stack.json` - Media automation (*arr apps)
- `download.json` - Download clients and tools
- `network.json` - Network services

#### AutoKuma Logs
To troubleshoot or verify AutoKuma operations:
```bash
kubectl logs -n monitoring deployment/autokuma -f
```