# Rinzler Grid Monitoring Dashboard

## Architecture Overview

A simple, self-contained monitoring dashboard that:
1. **Backend API** - Polls service APIs and stores recent metrics in memory
2. **Frontend Dashboard** - Real-time web UI with auto-refresh
3. **No external dependencies** - No Prometheus, Grafana, or databases required

## Monitored Services & Metrics

### Media Services
- **Plex**
  - Server status and capabilities
  - Recently added media count
  - Active streams
  - Library statistics
  
- **Tautulli**
  - Plex watch statistics
  - User activity

### Arr Stack
- **Radarr/Sonarr/Readarr/Lidarr**
  - Health status (download client connectivity)
  - Queue status
  - Missing/wanted items
  - Recent downloads
  - Indexer status
  
- **Bazarr**
  - Subtitle download statistics
  - Provider health

### Download Services
- **Transmission**
  - Active torrents
  - Download/upload speeds
  - VPN connection status (via Gluetun)
  
- **Jackett**
  - Indexer health
  - Query statistics

### Infrastructure
- **ArgoCD**
  - Application sync status
  - Repository connection health
  - Out-of-sync applications
  - Failed deployments
  
- **Traefik**
  - Request statistics
  - Service health
  - Certificate status

## API Endpoints Summary

| Service | Health Endpoint | Auth Method |
|---------|----------------|-------------|
| Plex | `http://plex:32400/?X-Plex-Token=TOKEN` | X-Plex-Token |
| Radarr | `http://radarr:7878/api/v3/health?apiKey=KEY` | API Key |
| Sonarr | `http://sonarr:8989/api/v3/health?apiKey=KEY` | API Key |
| ArgoCD | `http://argocd-server:8080/api/v1/session` | JWT Token |
| Transmission | `http://transmission:9091/transmission/rpc` | Basic Auth |

## Implementation Plan

1. Create monitoring namespace
2. Deploy collector service with embedded dashboard
3. Configure API credentials via secrets
4. Access dashboard at http://monitoring.rinzler.grid

## Deployment

```bash
# Edit monitoring-secrets.yaml with your API keys
# Then run:
./build-and-deploy.sh
```