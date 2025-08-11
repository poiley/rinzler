# Traefik Networking Configuration

## Overview
Traefik has been added as an ingress controller to provide a unified entry point for all services. This replaces the direct NodePort access with hostname-based routing.

## Access URLs
All services are now accessible via hostnames:

### Media Services
- **Plex**: http://plex.rinzler.grid
- **Tautulli**: http://tautulli.rinzler.grid
- **Kavita**: http://kavita.rinzler.grid

### Arr Stack
- **Sonarr**: http://sonarr.rinzler.grid
- **Radarr**: http://radarr.rinzler.grid
- **Lidarr**: http://lidarr.rinzler.grid
- **Bazarr**: http://bazarr.rinzler.grid

### Download Services
- **Jackett**: http://jackett.rinzler.grid
- **Transmission**: http://transmission.rinzler.grid
- **Mylar**: http://mylar.rinzler.grid

### Infrastructure
- **Traefik Dashboard**: http://traefik.rinzler.grid
- **Home Assistant**: http://home.rinzler.grid
- **Pi-hole**: http://pihole.rinzler.grid

## DNS Configuration
You'll need to configure DNS to resolve *.rinzler.grid to your server IP. Options:

1. **Pi-hole DNS**: Add local DNS records in Pi-hole
2. **Local hosts file**: Add entries to /etc/hosts
3. **Router DNS**: Configure your router's local DNS

Example hosts file entries:
```
192.168.1.100 plex.rinzler.grid
192.168.1.100 sonarr.rinzler.grid
192.168.1.100 radarr.rinzler.grid
# ... etc
```

Or use a wildcard DNS entry if your DNS server supports it:
```
*.rinzler.grid → 192.168.1.100
```

## Direct Port Access
Services are still accessible via ports for compatibility:
- Traefik will listen on ports 80 (HTTP) and 443 (HTTPS)
- Individual service ports are no longer exposed directly
- Use Traefik dashboard to monitor routing

## Benefits
1. **Single Entry Point**: All traffic goes through Traefik
2. **Hostname-based Routing**: Cleaner URLs without port numbers
3. **Future SSL Support**: Easy to add HTTPS with Let's Encrypt
4. **Observability**: Traefik dashboard shows all routes and metrics
5. **Middleware Support**: Can add authentication, rate limiting, etc.

## Migration Notes
- Existing bookmarks with ports will need updating to use hostnames
- Services communicate internally via Kubernetes DNS (service.namespace.svc.cluster.local)
- Traefik automatically discovers services via Kubernetes Ingress resources