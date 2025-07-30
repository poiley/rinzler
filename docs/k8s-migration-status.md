# Kubernetes Manifests Migration Status

## ✅ Completed Manifests - Organized by Function

### Media Services (`media` namespace)
Services for media consumption and organization:
- **Plex** - Media server with GPU support for transcoding
- **Tautulli** - Plex statistics and monitoring
- **Kavita** - Ebook and manga reader

### Arr Stack (`arr-stack` namespace)
Automated media management suite that works together:
- **Sonarr** - TV show management
- **Radarr** - Movie management
- **Lidarr** - Music management
- **Readarr** - Book/audiobook management
- **Bazarr** - Subtitle management for Sonarr/Radarr

### Download Services (`download` namespace)
All downloading, indexing, and content acquisition:
- **Transmission + Gluetun** - BitTorrent with VPN protection
- **Jackett** - Torrent indexer proxy
- **Flaresolverr** - Cloudflare bypass for indexers
- **Mylar** - Comic book downloader
- **FMD2** - Manga downloader

### Infrastructure (`infrastructure` namespace)
Core cluster services:
- **Traefik** - Ingress controller (using k3s built-in)
- **DuckDNS** - Dynamic DNS updater
- **ArgoCD** - GitOps deployment (to be deployed)

### Network Services (`network-services` namespace)
Network-level services:
- **Pi-hole** - DNS server and ad blocker
- **Samba** - SMB/CIFS file sharing

### Home Automation (`home` namespace)
Standalone complex applications:
- **Home Assistant** - Home automation platform

## Architecture Benefits

### Logical Grouping
- **Media**: User-facing media consumption apps
- **Arr Stack**: Tightly integrated automation tools
- **Download**: All acquisition and indexing tools
- **Infrastructure**: Cluster-wide services
- **Network Services**: Network-level functionality
- **Home**: Standalone complex applications

### Security & Resource Benefits
- Better RBAC possibilities per namespace
- Resource quotas can be set per functional area
- Network policies can isolate namespaces
- Easier to monitor resource usage by function

### Operational Benefits
- Clear separation of concerns
- Easier troubleshooting
- Logical service discovery
- Better GitOps organization

## Service Interactions

```
Internet → Infrastructure (Traefik) → All Services
         → Network Services (Pi-hole) → DNS Resolution

Download (Jackett/Transmission) ← Arr Stack (Sonarr/Radarr/etc)
                               ↓
                          Media Storage
                               ↓
                          Media (Plex/Kavita)
```

## Migration Notes

### Storage Paths
All services maintain their original storage paths:
- `/storage/media` - Media library
- `/storage/downloads` - Download directory
- `/storage/docker_volumes/*` - Existing config directories

### Network Configuration
- Services within same namespace can communicate by service name
- Cross-namespace communication uses `service.namespace.svc.cluster.local`
- Ingress routes handle external access

### Next Steps
1. Install k3s on the server
2. Apply namespaces in order
3. Deploy infrastructure services first
4. Deploy network services
5. Deploy download stack
6. Deploy arr stack
7. Deploy media services
8. Deploy home automation