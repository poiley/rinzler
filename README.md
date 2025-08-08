# Rinzler - K3s Media Server

A single-node K3s deployment for a home media server with GitOps, automatic HTTPS, and comprehensive monitoring.

## 🚀 Quick Start

```bash
# 1. Clone repository
git clone https://github.com/poiley/rinzler.git
cd rinzler

# 2. Install K3s
sudo ./scripts/k3s-install.sh

# 3. Generate and apply secrets
./scripts/generate-secrets.sh
./scripts/apply-secrets.sh

# 4. Install ArgoCD
./scripts/install-argocd.sh

# 5. Deploy cert-manager for HTTPS
kubectl apply -f k8s/cert-manager/application.yaml
kubectl apply -f k8s/cert-manager/issuers/application.yaml

# 6. Deploy all applications
kubectl apply -f k8s/namespaces/
kubectl apply -f k8s/*/application.yaml
```

## 🏗️ Architecture

- **Platform**: K3s (lightweight Kubernetes) on Ubuntu 20.04
- **GPU**: NVIDIA GTX 750 Ti for Plex hardware transcoding  
- **Storage**: 43.6TB ZFS pool at `/storage`
- **Networking**: Traefik ingress with automatic HTTPS
- **Certificates**: cert-manager with Let's Encrypt support
- **GitOps**: ArgoCD for automated deployments
- **Monitoring**: Prometheus + Grafana stack

## 📦 Services

### Media Stack
| Service | Purpose | Access URL |
|---------|---------|------------|
| **Plex** | Media server | `https://plex.rinzler.me` |
| **Sonarr** | TV management | `https://sonarr.rinzler.me` |
| **Radarr** | Movie management | `https://radarr.rinzler.me` |
| **Lidarr** | Music management | `https://lidarr.rinzler.me` |
| **Readarr** | Book management | `https://readarr.rinzler.me` |
| **Bazarr** | Subtitle management | `https://bazarr.rinzler.me` |
| **Kavita** | Book/manga reader | `https://kavita.rinzler.me` |
| **Tautulli** | Plex statistics | `https://tautulli.rinzler.me` |

### Infrastructure
| Service | Purpose | Access URL |
|---------|---------|------------|
| **ArgoCD** | GitOps deployment | `https://argocd.rinzler.me` |
| **Grafana** | Monitoring dashboards | `https://grafana.rinzler.me` |
| **Pi-hole** | DNS/Ad blocking | `https://pihole.rinzler.me` |
| **Transmission** | Downloads (VPN) | `https://transmission.rinzler.me` |
| **Home Assistant** | Home automation | `https://home-assistant.rinzler.me` |

## 🔐 HTTPS/SSL Setup

This cluster supports multiple certificate options:
- **Self-signed CA** for internal `.grid` domains
- **Let's Encrypt** for public domains (`.me` and `.cloud`)
- Automatic certificate renewal via cert-manager

For trusted certificates setup, see [MULTI_DOMAIN_SETUP.md](MULTI_DOMAIN_SETUP.md)

## 🗂️ Repository Structure

```
rinzler/
├── k8s/                    # Kubernetes manifests
│   ├── namespaces/        # Namespace definitions
│   ├── infrastructure/    # Core infrastructure (ArgoCD, Traefik)
│   ├── cert-manager/      # SSL/TLS certificate management
│   ├── media/            # Media services (Plex, Kavita, Tautulli)
│   ├── arr-stack/        # *arr applications
│   ├── download/         # Download clients
│   ├── monitoring/       # Prometheus + Grafana
│   ├── home/            # Home automation
│   └── network-services/ # Network utilities
├── scripts/              # Automation scripts
│   ├── k3s-install.sh   # K3s installation
│   ├── install-argocd.sh # ArgoCD setup
│   ├── generate-secrets.sh # Secret generation
│   └── setup-cloudflare-secret.sh # Cloudflare API setup
└── docs/                 # Documentation
    ├── MULTI_DOMAIN_SETUP.md # Let's Encrypt setup guide
    └── SECURITY.md       # Security best practices
```

## 🔧 Management Scripts

- `generate-secrets.sh` - Generate secure passwords for all services
- `apply-secrets.sh` - Apply secrets to Kubernetes
- `setup-cloudflare-secret.sh` - Configure Cloudflare API token for Let's Encrypt
- `verify-ssl-setup.sh` - Verify SSL/DNS configuration
- `server-diagnostics.sh` - System health check
- `storage-cleanup.sh` - Clean up storage and unused resources
- `k3s-install.sh` - Install K3s cluster
- `install-argocd.sh` - Install and configure ArgoCD
- `nvidia-install.sh` - Install NVIDIA drivers and container runtime

## 🔒 Security

- Secrets managed via Kubernetes secrets (not committed to git)
- VPN protection for download clients via Gluetun
- Network isolation with namespaces
- Automatic HTTPS for all services
- Pi-hole for network-wide ad blocking

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details.