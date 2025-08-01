# Quick Reference Guide

## 🚦 Where to Start
1. **New to the project?** → Read [README.md](README.md)
2. **Ready to install?** → Follow [01-installation-guide.md](01-installation-guide.md)
3. **Fresh deployment?** → See [03-deployment-workflow.md](03-deployment-workflow.md)
4. **Need to check settings?** → See [02-pre-deployment-checklist.md](02-pre-deployment-checklist.md)
5. **Managing secrets?** → Read [SECRETS-MANAGEMENT.md](SECRETS-MANAGEMENT.md)
6. **Looking for docs?** → Browse [docs/README.md](docs/README.md)

## ⚡ IMPORTANT: Use ArgoCD for ALL Changes!
**Never use kubectl apply directly!** All deployments and changes should go through ArgoCD.
See: [ArgoCD Usage Guide](../operations/argocd-usage.md)

## 🎯 Common Tasks

### "I want to install K3s"
```bash
sudo ./scripts/k3s-install.sh
```
See: [01-installation-guide.md](01-installation-guide.md) Section 1

### "I want to check my server specs"
```bash
./scripts/server-diagnostics.sh
```
See: [scripts/README.md](scripts/README.md)

### "I want to access a service"
After setup, use these URLs:
- Plex: http://plex.rinzler.grid
- Sonarr: http://sonarr.rinzler.grid
- Radarr: http://radarr.rinzler.grid
- Traefik Dashboard: http://traefik.rinzler.grid

See: [docs/traefik-networking.md](docs/traefik-networking.md)

### "I want to configure DNS"
See: [docs/pihole-dns-setup.md](docs/pihole-dns-setup.md)

### "I want to update a service"
```bash
# Edit the YAML file
vim k8s/<namespace>/<service>/deployment.yaml

# Commit and push to Git
git add -A && git commit -m "Update service" && git push

# ArgoCD automatically applies the change!
```

### "I want to restart a service"
```bash
# Best practice: Update deployment to trigger restart
vim k8s/<namespace>/<service>/deployment.yaml
# Add/update an annotation like: kubectl.kubernetes.io/restartedAt: "2024-01-15T10:00:00Z"
git add -A && git commit -m "Restart <service>" && git push

# Emergency only (avoid this!):
kubectl rollout restart deployment/<service> -n <namespace>
```

## 📁 Directory Map

```
rinzler/
├── README.md                    # Start here
├── 01-installation-guide.md              # Installation steps
├── 02-pre-deployment-checklist.md # Final checks
├── SECRETS-CONFIGURED.md       # Current secrets
├── QUICK-REFERENCE.md          # This file
│
├── k8s/                        # Kubernetes configs
│   ├── argocd/                 # ArgoCD applications (DEPLOY THESE!)
│   │   └── applications/       # One file per service stack
│   ├── media/                  # Plex, Tautulli, Kavita
│   ├── arr-stack/              # Sonarr, Radarr, etc.
│   ├── download/               # Transmission, Jackett
│   ├── infrastructure/         # Traefik, ArgoCD
│   ├── network-services/       # Pi-hole, Samba
│   └── home/                   # Home Assistant
│
├── scripts/                    # Automation
│   ├── README.md              # Script documentation
│   ├── k3s-install.sh         # Main installer
│   └── server-diagnostics.sh  # System info
│
├── docs/                       # Detailed docs
│   ├── README.md              # Doc index
│   ├── *-strategy.md          # Planning docs
│   └── *.md                   # Config guides
│
```

## 🔍 Finding Information

### By Topic
- **Hardware/Server Info** → [docs/current-server-analysis.md](docs/current-server-analysis.md)
- **Migration Strategy** → [docs/k3s-migration-strategy.md](docs/k3s-migration-strategy.md)
- **Networking/Domains** → [docs/traefik-networking.md](docs/traefik-networking.md)
- **GitOps/ArgoCD** → [docs/gitops-architecture.md](docs/gitops-architecture.md)
- **HOW TO USE ARGOCD** → [docs/operations/argocd-usage.md](docs/operations/argocd-usage.md) ⭐

### By Service
Each service has its configs in `k8s/<namespace>/<service>/`:
- `deployment.yaml` - Main application config
- `service.yaml` - Network exposure
- `ingress.yaml` - Web access via Traefik
- `pvc.yaml` - Storage (if using new volumes)

## ⚠️ Important Files
- `k8s/argocd/applications/*.yaml` - ArgoCD apps (deploy these!)
- `k8s/*/deployment.yaml` - Service configurations (edit these, push to Git)
- `scripts/k3s-install.sh` - Installation script
- `scripts/install-argocd.sh` - ArgoCD installation

## 🆘 Troubleshooting

### "Service won't start"
```bash
kubectl -n <namespace> describe pod <pod-name>
kubectl -n <namespace> logs <pod-name>
```

### "Can't access service URL"
1. Check DNS: `nslookup service.rinzler.grid`
2. Check service: `kubectl -n <namespace> get svc`
3. Check ingress: `kubectl -n <namespace> get ingress`

### "Need to see all pods"
```bash
kubectl get pods --all-namespaces
```

## 📞 Getting Help
1. Check relevant documentation
2. Run diagnostics: `./scripts/server-diagnostics.sh`
3. Check service logs
4. Review [01-installation-guide.md](01-installation-guide.md) troubleshooting section