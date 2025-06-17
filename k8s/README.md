# Kubernetes Media Server with Rancher Management

This directory contains Kubernetes manifests to deploy a complete media server infrastructure, replacing the previous Docker Compose setup with a Kubernetes-native approach managed by Rancher.

## 🏗️ Architecture Overview

The setup includes:

### 📺 Media Services
- **Plex**: Media server for streaming movies, TV shows, and music
- **Radarr**: Movie collection manager
- **Sonarr**: TV show collection manager  
- **Lidarr**: Music collection manager
- **Bazarr**: Subtitle manager
- **Jackett**: Torrent indexer aggregator
- **Tautulli**: Plex monitoring and analytics

### 🔒 VPN & Torrent
- **Gluetun**: VPN client container (Mullvad WireGuard)
- **Transmission**: Torrent client (routed through VPN)
- **Flaresolverr**: Cloudflare bypass proxy

### 🌐 Networking & DNS
- **Traefik**: Ingress controller and reverse proxy
- **Pi-hole**: Network-wide ad blocking and DNS filtering

### 📊 Monitoring
- **Prometheus**: Metrics collection and monitoring
- **Grafana**: Visualization and dashboards

### 🔐 Security & Secrets
- **HashiCorp Vault**: Centralized secrets management
- **External Secrets Operator**: Syncs Vault secrets to Kubernetes
- **Data Protection**: Automated backups and retention policies

## 🚀 Quick Start

### Prerequisites

1. **Kubernetes Cluster**: A running Kubernetes cluster (single-node or multi-node)
2. **kubectl**: Configured to connect to your cluster
3. **Helm**: Required for Vault and advanced features (`curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash`)
4. **Rancher**: Installed and configured (see Rancher Setup section)
5. **Storage**: `/storage` directory available on your nodes with existing data

### Deploy Everything

```bash
cd k8s
./deploy.sh
```

This script will:
1. Create namespaces
2. Set up storage classes and persistent volumes with data protection
3. Install Vault and External Secrets Operator (if Helm available)
4. Deploy networking components (Traefik, Pi-hole)
5. Deploy monitoring stack (Prometheus, Grafana)
6. Deploy all media services

## 🔐 Secrets Management with Vault

### Setting Up Vault Secrets

After deployment, configure your secrets securely:

```bash
# Run the interactive secrets setup script
cd k8s
./scripts/setup-vault-secrets.sh
```

This script will:
- Set up port forwarding to Vault
- Prompt for all required secrets (VPN keys, passwords, API keys)
- Store secrets securely in Vault
- Create a reference guide for future use

### Manual Vault Setup

If you prefer manual setup:

1. **Access Vault UI**: `http://your-cluster-ip/vault`
2. **Initialize Vault**: Follow the initialization wizard
3. **Store secrets** at these paths:
   - `secret/vpn/wireguard`: VPN credentials
   - `secret/dns/pihole`: Pi-hole password
   - `secret/media-server/grafana`: Grafana admin password

### External Secrets Integration

The External Secrets Operator automatically syncs Vault secrets to Kubernetes secrets:
- VPN credentials → `vpn-config` secret in `media-server` namespace
- Pi-hole password → `pihole-config` secret in `networking` namespace
- Grafana password → `grafana-config` secret in `monitoring` namespace

## 🛡️ Data Protection Features

### Storage Protection
- **Retain Policy**: All persistent volumes use `Retain` reclaim policy
- **Protected Storage Class**: Special storage class that never deletes data
- **Node Affinity**: Ensures data stays on designated storage nodes

### Automated Backups
- **Daily Backup Job**: Automatically backs up critical data at 2 AM
- **Backup Location**: `/storage/backups` directory
- **Retention**: Configurable backup retention policies

### Terraform Data Protection
The Terraform module includes additional protection:
- Multiple storage classes with different retention policies
- Backup persistent volumes
- Data protection configuration maps
- Automated backup CronJobs

## 🐄 Rancher Setup & Integration

### Installing Rancher

#### Option 1: Rancher on Existing Kubernetes Cluster

```bash
# Add Rancher Helm repository
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update

# Create rancher-system namespace
kubectl create namespace rancher-system

# Install cert-manager (required for Rancher)
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.5.1/cert-manager.crds.yaml
kubectl create namespace cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager --namespace cert-manager --version v1.5.1

# Install Rancher
helm install rancher rancher-stable/rancher \
  --namespace rancher-system \
  --set hostname=rancher.local \
  --set bootstrapPassword=admin
```

#### Option 2: Rancher Desktop (Development)

1. Download and install [Rancher Desktop](https://rancherdesktop.io/)
2. Enable Kubernetes in the settings
3. Access the Rancher UI at `http://localhost:8080`

### Accessing Rancher UI

1. **Get Rancher URL**: `https://rancher.local` (or your configured hostname)
2. **Initial Setup**: Use the bootstrap password set during installation
3. **Import Cluster**: If using external cluster, import it into Rancher

### Managing Services via Rancher

Once Rancher is set up:

1. **Navigate to your cluster** in the Rancher UI
2. **View Workloads**: See all deployments, pods, and services
3. **Monitor Resources**: Check CPU, memory, and storage usage
4. **Manage Storage**: View and manage persistent volumes
5. **Configure Ingress**: Manage Traefik ingress rules
6. **View Logs**: Access container logs directly from the UI
7. **Scale Services**: Easily scale deployments up or down
8. **Manage Secrets**: View and edit Kubernetes secrets

## 🔧 Configuration

### Required Secrets

#### Option 1: Using Vault (Recommended)
Run the secrets setup script:
```bash
./scripts/setup-vault-secrets.sh
```

#### Option 2: Manual Configuration
Update these secrets in the YAML files:

**VPN Configuration** in `manifests/media/torrent-stack.yaml`:
```yaml
stringData:
  WIREGUARD_PRIVATE_KEY: "your-wireguard-private-key"
  WIREGUARD_ADDRESSES: "your-vpn-address/24"
```

**Pi-hole Password** in `manifests/networking/pihole.yaml`:
```yaml
stringData:
  WEBPASSWORD: "your-secure-password"
```

### Storage Configuration

The setup assumes your existing `/storage` directory structure:
```
/storage/
├── docker/          # Configuration data for each service
│   ├── plex/
│   ├── radarr/
│   ├── sonarr/
│   └── ...
├── media/           # Your media files
│   ├── movies/
│   ├── tv/
│   └── music/
├── downloads/       # Download directory
└── backups/         # Automated backups (new)
```

Update the `nodeAffinity` in `manifests/storage/persistent-volumes.yaml` to match your node names:
```yaml
nodeAffinity:
  required:
    nodeSelectorTerms:
    - matchExpressions:
      - key: kubernetes.io/hostname
        operator: In
        values:
        - your-node-name  # Change this to your actual node name
```

## 🌐 Service Access

### Via Ingress (Recommended)
All services are accessible through Traefik ingress:
- Plex: `http://your-cluster-ip/plex` or `http://plex.local`
- Radarr: `http://your-cluster-ip/radarr`
- Sonarr: `http://your-cluster-ip/sonarr`
- Grafana: `http://your-cluster-ip/grafana`
- Vault: `http://your-cluster-ip/vault`
- And so on...

### Via NodePort/LoadBalancer
Some services expose NodePort or LoadBalancer services for direct access:
- Traefik Dashboard: `http://your-cluster-ip:8080`
- Pi-hole DNS: Port 53 (UDP/TCP)

### Via Rancher UI
Access and manage all services directly through the Rancher web interface.

## 📊 Monitoring

### Prometheus Metrics
Prometheus automatically discovers and scrapes metrics from:
- Kubernetes cluster components
- Application pods (with proper annotations)
- Node metrics

### Grafana Dashboards
Access Grafana at `/grafana` to view:
- Kubernetes cluster overview
- Resource utilization
- Application-specific metrics
- Custom dashboards

## 🔍 Troubleshooting

### Check Pod Status
```bash
kubectl get pods --all-namespaces
```

### View Pod Logs
```bash
kubectl logs -f deployment/plex -n media-server
```

### Check Storage
```bash
kubectl get pv,pvc --all-namespaces
```

### Verify Ingress
```bash
kubectl get ingress --all-namespaces
```

### Check Vault Status
```bash
kubectl exec -n vault-system vault-0 -- vault status
```

### Rancher-Specific Troubleshooting
1. **Access Rancher UI** to get visual overview of cluster health
2. **Check Events** in Rancher for any deployment issues
3. **View Resource Metrics** to identify bottlenecks
4. **Use Rancher's kubectl shell** for direct cluster access

## 🔄 Migration from Docker Compose

### Pre-Migration Checklist
1. **Backup configurations**: Copy `/storage/docker/` directory
2. **Export Plex database**: Use Plex's built-in backup feature
3. **Note current settings**: Document any custom configurations
4. **Stop Docker services**: `docker-compose down` on all services

### Migration Process
1. **Deploy Kubernetes**: Run `./deploy.sh`
2. **Configure secrets**: Run `./scripts/setup-vault-secrets.sh`
3. **Verify storage mounts**: Ensure all PVs are bound correctly
4. **Test services**: Access each service web UI
5. **Restore configurations**: Copy any missing config files
6. **Update DNS**: Point clients to new service endpoints

### Post-Migration Cleanup
1. **Verify Kubernetes**: Ensure all services are working properly
2. **Clean up Docker**: Run `./scripts/docker-cleanup.sh`
3. **Monitor via Rancher**: Use Rancher UI for ongoing management
4. **Set up alerts**: Configure Prometheus/Grafana alerts
5. **Scale as needed**: Use Rancher to scale services

## 🧹 Docker Cleanup

After successful migration, clean up your Docker installation:

```bash
# Run the interactive cleanup script
./scripts/docker-cleanup.sh
```

This script provides options to:
- Stop and remove Docker containers
- Remove Docker networks and volumes
- Clean up Docker images
- Remove Docker Compose
- Optionally remove Docker entirely
- Create a cleanup report

**⚠️ Warning**: The cleanup script will verify your Kubernetes deployment is working before allowing destructive operations.

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Rancher Documentation](https://rancher.com/docs/)
- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [External Secrets Operator](https://external-secrets.io/)
- [Traefik Kubernetes Documentation](https://doc.traefik.io/traefik/providers/kubernetes-ingress/)
- [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This project is licensed under the MIT License. 