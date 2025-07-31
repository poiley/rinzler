# Rinzler - K3s Media Server

A single-node K3s deployment for a home media server with GitOps, migrated from Docker/Portainer.

## 🚀 Quick Start

```bash
# 1. Clone repository
git clone https://github.com/yourusername/rinzler.git
cd rinzler

# 2. Set up secrets (see docs/setup/03-deployment-workflow.md)
cp .env.secret.example .env.secret
nano .env.secret

# 3. Install K3s
sudo ./scripts/k3s-install.sh

# 4. Install ArgoCD and deploy all services
./scripts/install-argocd.sh

# 5. Apply ArgoCD applications (deploys everything automatically)
kubectl apply -f k8s/argocd/applications/
```

## 📚 Documentation

All documentation is organized in the `/docs` directory:

- **[Setup Guide](docs/setup/01-installation-guide.md)** - Complete installation instructions
- **[Quick Reference](docs/reference/quick-reference.md)** - Common commands and tasks
- **[Documentation Index](docs/README.md)** - Full documentation listing

## 🏗️ Architecture

- **Platform**: K3s (lightweight Kubernetes) on Ubuntu 20.04
- **GPU**: NVIDIA GTX 750 Ti for Plex hardware transcoding  
- **Storage**: 43.6TB ZFS pool at `/storage`
- **Networking**: Traefik ingress with `.grid` domain
- **GitOps**: ArgoCD for automated deployments

## 📦 Services

| Service | Purpose | Access URL |
|---------|---------|------------|
| **Plex** | Media server | `plex.rinzler.grid` |
| **Sonarr** | TV management | `sonarr.rinzler.grid` |
| **Radarr** | Movie management | `radarr.rinzler.grid` |
| **Transmission** | Downloads (VPN) | `transmission.rinzler.grid` |
| **Pi-hole** | DNS/Ad blocking | `pihole.rinzler.grid` |
| **Traefik** | Reverse proxy | `traefik.rinzler.grid` |

[Full service list →](docs/reference/quick-reference.md#service-access)

## 🗂️ Repository Structure

```
rinzler/
├── k8s/           # Kubernetes manifests
├── scripts/       # Installation and maintenance scripts  
├── docs/          # All documentation
├── compose/       # Original Docker files (reference)
└── .env.secret.example  # Secrets template
```

See [Repository Structure](docs/reference/repository-structure.md) for details.

## 🔒 Security

This repository is designed to be public-friendly:
- Real secrets go in `.env.secret` (git-ignored)
- Example values provided for all configurations
- See [Secrets Management](docs/operations/secrets-management.md)

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details.