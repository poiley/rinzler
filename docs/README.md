# Documentation Index

## 📋 Directory Structure
```
docs/
├── setup/           # Installation and deployment
├── reference/       # Quick references and structure
├── operations/      # Operational guides
└── *.md             # Planning and architecture docs
```

## 🚀 Setup Documentation
- **[01 - Installation Guide](setup/01-installation-guide.md)** - Step-by-step K3s installation
- **[02 - Pre-Deployment Checklist](setup/02-pre-deployment-checklist.md)** - Final configuration checks
- **[03 - Deployment Workflow](setup/03-deployment-workflow.md)** - Complete deployment process

## 📖 Reference Documentation
- **[Quick Reference](reference/quick-reference.md)** - Common commands and navigation
- **[Repository Structure](reference/repository-structure.md)** - Project organization standards

## 🔧 Operations Documentation
- **[ArgoCD Usage Guide](operations/argocd-usage.md)** - How to use ArgoCD for deployments (READ THIS!)
- **[Secrets Management](operations/secrets-management.md)** - Handling secrets for public repos
- **[Current Secrets](operations/current-secrets.md)** - Current secret values status

## 🏗️ Architecture & Planning
- **[Server Analysis](current-server-analysis.md)** - Hardware specs and current state
- **[Migration Strategy](k3s-migration-strategy.md)** - High-level approach and phases
- **[Migration Status](k8s-migration-status.md)** - Service organization and progress tracking
- **[Port Strategy](migration-ports-strategy.md)** - How port conflicts are resolved
- **[GitOps Architecture](gitops-architecture.md)** - How ArgoCD deployment works

## 🌐 Networking & Configuration
- **[Traefik Networking](traefik-networking.md)** - Ingress controller and .grid domain
- **[Pi-hole DNS Setup](pihole-dns-setup.md)** - Configure .grid domain resolution
- **[K8s Config Validation](k8s-config-validation.md)** - Docker to K8s validation report

## 📚 Glossary

### Terms
- **K3s**: Lightweight Kubernetes distribution optimized for edge/IoT/single-node deployments
- **GitOps**: Using Git as the single source of truth for declarative infrastructure
- **ArgoCD**: Kubernetes controller that continuously monitors Git repos and applies changes
- **Traefik**: Modern reverse proxy with automatic service discovery
- **hostPath**: Direct mount of host filesystem into Kubernetes pods
- **.grid TLD**: Custom top-level domain for local services (Tron reference)

### Namespaces
- **media**: Plex, Tautulli, Kavita - media consumption services
- **arr-stack**: Sonarr, Radarr, Lidarr, etc. - media automation
- **download**: Transmission, Jackett, Gluetun - download services
- **infrastructure**: Traefik, ArgoCD, DuckDNS - core platform
- **network-services**: Pi-hole, Samba - network utilities
- **home**: Home Assistant - home automation

## 🔍 Navigation
- **[← Back to Main README](../README.md)**
- [Scripts Documentation](../scripts/README.md)
- [K8s Manifests](../k8s/)
- [Docker Compose Reference](../compose/)