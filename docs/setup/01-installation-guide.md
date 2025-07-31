# K3s Media Server Setup Guide

> **Purpose**: This guide provides step-by-step instructions to migrate your Docker-based media server to K3s (lightweight Kubernetes).
>
> **Time Required**: Approximately 2-3 hours
>
> **Skill Level**: Intermediate (familiarity with Linux command line required)

## Prerequisites

### ✅ Already Completed
- [x] Ubuntu 20.04 server with ZFS storage at `/storage`
- [x] NVIDIA drivers installed (nvidia-driver-470 for GTX 750 Ti)
- [x] Existing Docker containers documented
- [x] Storage cleaned up (886GB freed, now at ~90% capacity)
- [x] All K8s manifests created and validated

### ⚠️ Required Before Starting
- [ ] Review [Pre-Deployment Checklist](02-pre-deployment-checklist.md)
- [ ] Ensure you have root/sudo access
- [ ] Back up any critical data
- [ ] Have at least 30 minutes of downtime available

## Setup Procedure

### 1. Install K3s

**What this does**: Installs a lightweight Kubernetes distribution optimized for single-node deployments.

```bash
# Navigate to the project directory
cd /path/to/rinzler

# Run the installation script with sudo
sudo ./scripts/k3s-install.sh
```

**The script will**:
- Download and install K3s v1.28.5
- Configure kubectl (Kubernetes command-line tool)
- Create 6 namespaces for service organization
- Install NVIDIA device plugin for GPU support
- Set up local storage provisioner

**Expected output**:
```
=== Installing K3s ===
[INFO]  Finding release for channel stable
[INFO]  Using v1.28.5+k3s1 as release
...
=== K3s installation complete! ===
```

**Verify installation**:
```bash
# Check if K3s is running
sudo systemctl status k3s

# Check if you can access the cluster
kubectl get nodes
```

### 2. Install ArgoCD for GitOps Management

**What this does**: ArgoCD automatically deploys and manages all your services from this Git repository. No more manual kubectl commands!

```bash
# Run the ArgoCD installation script
./scripts/install-argocd.sh
```

**The script will**:
- Install ArgoCD in the 'argocd' namespace
- Wait for ArgoCD to be ready
- Configure access credentials
- Display the admin password

**Access ArgoCD UI** (optional but recommended):
```bash
# Port-forward to access the UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open https://localhost:8080 in your browser
# Username: admin
# Password: (displayed by the install script)
```

### 3. Configure DNS for .grid Domain

**What this does**: Sets up custom domain names for your services (e.g., `plex.rinzler.grid` instead of `192.168.1.100:32400`).

#### Option A: Using Pi-hole (Recommended)
1. Open Pi-hole admin panel in your browser:
   ```
   http://rinzler:8081/admin
   ```
   - Username: admin
   - Password: password (from your Docker setup)

2. Navigate to **Local DNS → DNS Records**

3. Add the base domain:
   - **Domain**: `rinzler.grid`
   - **IP Address**: Your server's IP (e.g., `192.168.1.227`)
   - Click "Add"

4. Navigate to **Local DNS → CNAME Records**

5. Add the wildcard:
   - **Domain**: `*.rinzler.grid`
   - **Target Domain**: `rinzler.grid`
   - Click "Add"

#### Option B: Using /etc/hosts (For Testing)
Add to your computer's hosts file:
```bash
# On your local machine (not the server)
sudo nano /etc/hosts

# Add these lines (replace with your server IP):
192.168.1.227 plex.rinzler.grid
192.168.1.227 sonarr.rinzler.grid
192.168.1.227 radarr.rinzler.grid
# ... add all services
```

**Test DNS**:
```bash
ping plex.rinzler.grid
```

### 4. Deploy All Services with ArgoCD

**What this does**: Instead of manually applying each service, ArgoCD will automatically deploy and manage everything from your Git repository.

```bash
# Deploy all ArgoCD applications
kubectl apply -f k8s/argocd/applications/
```

**This single command deploys**:
- Infrastructure services (Traefik, DuckDNS)
- Media services (Plex, Tautulli, Kavita)
- Arr stack (Sonarr, Radarr, etc.)
- Download services (Transmission, Jackett)
- Network services (Pi-hole, Samba)
- Home automation (Home Assistant)

**Monitor deployments**:
```bash
# Watch all applications sync
kubectl -n argocd get applications

# Check sync status
kubectl -n argocd get app -o wide
```

**Why ArgoCD?**
- Automatic deployments from Git
- Self-healing (fixes manual changes)
- Easy rollbacks
- No more kubectl commands needed!

### 5. Verify Services and Stop Docker Containers

**Important**: ArgoCD has already deployed all K8s services. Now verify they're working before stopping Docker.

**Important**: Migrate services one at a time to minimize downtime and allow easy rollback.

#### Example: Migrating Plex

1. **Stop the Docker container**:
   ```bash
   docker stop plex
   ```

2. **Verify the K8s version is running** (deployed by ArgoCD):
   ```bash
   kubectl -n media get pods | grep plex
   ```

3. **Monitor the deployment**:
   ```bash
   # Watch the pod come up (press Ctrl+C to exit)
   kubectl -n media get pods -w
   
   # You should see:
   # NAME                    READY   STATUS    RESTARTS   AGE
   # plex-xxxxxxxxxx-xxxxx   0/1     Pending   0          0s
   # plex-xxxxxxxxxx-xxxxx   0/1     ContainerCreating   0   2s
   # plex-xxxxxxxxxx-xxxxx   1/1     Running   0          30s
   ```

4. **Test the service**:
   - Open http://plex.rinzler.grid in your browser
   - Log in and verify your libraries are visible
   - Test playing a video

5. **If successful, remove Docker container**:
   ```bash
   docker rm plex
   ```

6. **If issues occur, rollback**:
   ```bash
   # Stop K8s deployment
   kubectl delete -f k8s/media/plex/
   
   # Restart Docker container
   docker start plex
   ```

**Repeat this process for each service**

### 6. Managing Services with ArgoCD

**All services are already deployed!** ArgoCD handles everything automatically.

**Check service status**:
```bash
# View all ArgoCD applications
kubectl -n argocd get applications

# Check specific stack
kubectl -n argocd get app media
kubectl -n argocd get app arr-stack
kubectl -n argocd get app download
```

**Make changes**:
1. Edit the YAML files in this repository
2. Commit and push to Git
3. ArgoCD automatically applies changes!

**Force sync if needed**:
```bash
# Sync a specific application
kubectl -n argocd patch app media --type merge -p '{"operation": {"initiatedBy": {"username": "admin"}, "sync": {"revision": "HEAD"}}}'
```

### 7. Verify Services
Check all services are running:
```bash
kubectl get pods --all-namespaces
kubectl get ingress --all-namespaces
```

Access services via .grid URLs:
- Traefik Dashboard: http://traefik.rinzler.grid
- Plex: http://plex.rinzler.grid
- Sonarr: http://sonarr.rinzler.grid (no /sonarr suffix!)
- etc.

### 8. Configure ArgoCD for Continuous Deployment

**ArgoCD is already installed and managing your services!**

**To make future changes**:
1. Edit YAML files in the `k8s/` directory
2. Commit changes: `git commit -m "Update service X"`
3. Push to repository: `git push`
4. ArgoCD automatically detects and applies changes

**Enable auto-sync** (optional):
```bash
# Enable automatic syncing for all apps
for app in media arr-stack download infrastructure network-services home; do
  kubectl -n argocd patch app $app --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
done
```

### 9. Monitor Resource Usage
```bash
# Check K3s memory usage vs Docker
kubectl top nodes
kubectl top pods --all-namespaces
```

## Rollback Plan

If issues occur:
1. Scale down K8s deployment: `kubectl scale deployment <name> --replicas=0`
2. Start Docker container: `docker start <container-name>`
3. Debug and fix K8s manifest
4. Try migration again

## Service URLs Reference

| Service | Old Docker URL | New K8s URL |
|---------|---------------|-------------|
| Plex | http://rinzler:32400 | http://plex.rinzler.grid |
| Sonarr | http://rinzler:8989 | http://sonarr.rinzler.grid |
| Radarr | http://rinzler:7878 | http://radarr.rinzler.grid |
| Lidarr | http://rinzler:8686 | http://lidarr.rinzler.grid |
| Transmission | http://rinzler:9091 | http://transmission.rinzler.grid |
| Home Assistant | http://rinzler:8123 | http://home.rinzler.grid |
| Pi-hole | http://rinzler:8081 | http://pihole.rinzler.grid |
| Traefik | N/A | http://traefik.rinzler.grid |

## Important Notes

- **DO NOT USE kubectl apply DIRECTLY** - Let ArgoCD manage all deployments
- All services use existing Docker volumes via hostPath - no data migration needed
- Services are configured identically to Docker deployments
- GPU support enabled for Plex transcoding
- Clean URLs without suffixes (no more /sonarr, /radarr, etc.)
- Can run K8s and Docker side-by-side during migration

## GitOps Best Practices

### \u2705 DO:
- Make changes by editing YAML files and pushing to Git
- Use ArgoCD UI to monitor sync status
- Let ArgoCD handle all deployments
- Use Git history for rollbacks

### \u274c DON'T:
- Run `kubectl apply -f k8s/service/` manually
- Edit resources directly with `kubectl edit`
- Delete resources with `kubectl delete` 
- Make changes outside of Git

## Next Steps

1. Set up monitoring with Prometheus/Grafana
2. Configure Uptime Kuma for availability monitoring
3. Set up automated backups
4. Configure ArgoCD for automatic deployments from Git

## Troubleshooting

See individual documentation:
- `docs/current-server-analysis.md` - Server specifications
- `docs/k3s-migration-strategy.md` - Migration approach
- `docs/traefik-networking.md` - Networking setup
- `docs/k8s-config-validation.md` - Configuration validation