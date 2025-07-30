# Docker Server Configuration

Infrastructure-as-code for personal media server with automated service orchestration.

## Project Structure

```
.
├── compose/                 # Docker Compose configurations
│   ├── docker-compose.bazarr.yml
│   ├── docker-compose.duckdns-kavita-caddy.yml
│   ├── docker-compose.flaresolverr.yml
│   ├── docker-compose.fmd2.yml
│   ├── docker-compose.homeassistant.yml
│   ├── docker-compose.jackett.yml
│   ├── docker-compose.lidarr.yml
│   ├── docker-compose.pihole.yml
│   ├── docker-compose.plex.yml
│   ├── docker-compose.radarr.yml
│   ├── docker-compose.samba.yml
│   ├── docker-compose.sonarr.yml
│   ├── docker-compose.tautulli.yml
│   ├── docker-compose.torrent_stack.yml
│   ├── docker-compose.traefik.yml
│   ├── docker-compose.vpn.yml
│   ├── docker-compose.vscode.yml
│   └── docker-compose.wireguard.yml
├── .env                     # Environment variables (create from .env.example)
├── .env.example            # Example environment configuration
└── README.md
```

## Services Overview

### Media Services
- **Plex** (Port 32400): Media server with hardware transcoding support
- **Radarr** (Port 7878): Movie collection manager
- **Sonarr** (Port 8989): TV show collection manager
- **Lidarr** (Port 8686): Music collection manager
- **Bazarr**: Subtitle management for Radarr and Sonarr
- **Jackett** (Port 9117): Torrent indexer proxy
- **Tautulli**: Plex monitoring and statistics

### Network Services
- **Traefik** (Ports 80, 8080): Reverse proxy and load balancer
- **Pihole** (Port 8081, DNS 53): Network-wide ad blocker
- **Wireguard** (Port 51821): VPN server
- **DuckDNS/Caddy**: Dynamic DNS and HTTPS certificates

### Utility Services
- **HomeAssistant** (Port 8123): Home automation platform
- **Samba** (Ports 139, 445): Network file sharing
- **VSCode Server** (Port 3000): Web-based code editor
- **FlareSolverr**: Cloudflare bypass for web scrapers
- **FMD2**: Manga downloader

### Download Services
- **Torrent Stack** (Port 9091): Complete torrent solution with VPN protection
  - Transmission with web UI
  - Mullvad VPN integration

## Setup

1. Clone repository
2. Copy .env.example to .env:
   ```bash
   cp .env.example .env
   ```
3. Edit .env and configure:
   - **Wireguard VPN**: Update `WIREGUARD_PRIVATE_KEY` and `WIREGUARD_ADDRESSES` from your Mullvad config
   - **Pihole**: Set a secure `PIHOLE_PASSWORD`
   - **Basic Auth**: Generate Base64 encoded credentials for `BASIC_AUTH_HEADER`
   - **Plex**: Update `PLEX_MEDIA_SERVER_USER` and `ADVERTISE_IP`
   - **DuckDNS**: Add your `TOKEN` and `SUBDOMAINS`
   - **Timezone**: Adjust `TZ` as needed
   - **User/Group**: Set appropriate `PUID`/`PGID` for your system

4. Create required volumes:
   ```bash
   docker volume create jackett_data
   # Create other volumes as needed
   ```

5. Deploy services:
   - Individual service: `docker compose -f compose/docker-compose.SERVICE.yml up -d`
   - Or use Portainer for stack management

## Environment Variables

Key environment variables used across services:

| Variable | Description | Default |
|----------|-------------|---------|
| `TZ` | Timezone | America/Los_Angeles |
| `PUID` | User ID | 1000 |
| `PGID` | Group ID | 1000 |
| `WIREGUARD_PRIVATE_KEY` | VPN private key | (required) |
| `WIREGUARD_ADDRESSES` | VPN IP address | (required) |
| `PIHOLE_PASSWORD` | Pihole admin password | (required) |
| `BASIC_AUTH_HEADER` | Base64 auth credentials | (required) |
| `AUTO_UPDATE` | Enable auto-updates | true |

## Port Mappings

| Service | Port(s) | Description |
|---------|---------|-------------|
| Plex | 32400 | Media server (HTTP/HTTPS) |
| Traefik | 80, 443, 8080 | HTTP, HTTPS, Dashboard |
| Pihole | 8081, 53 | Web UI, DNS |
| HomeAssistant | 8123 | Web UI |
| Jackett | 9117 | Web UI |
| Radarr | 7878 | Web UI |
| Sonarr | 8989 | Web UI |
| Lidarr | 8686 | Web UI |
| Tautulli | 8181 | Web UI |
| Transmission | 9091 | Web UI |
| Wireguard | 51821 | VPN |
| Samba | 139, 445 | SMB/CIFS |
| VSCode | 3000 | Web IDE |

## Storage Paths

Default volume mappings:
- Media files: `/storage/media`
- Downloads: `/storage/downloads`
- Docker volumes: `/storage/docker_volumes/[service_name]`
- Plex data: `/storage/docker-volumes/plex_data`

## Usage

### Docker Compose Commands

Start a service:
```bash
docker compose -f compose/docker-compose.SERVICE.yml up -d
```

Stop a service:
```bash
docker compose -f compose/docker-compose.SERVICE.yml down
```

View logs:
```bash
docker compose -f compose/docker-compose.SERVICE.yml logs -f
```

### Service-Specific Notes

#### Plex
- Hardware transcoding enabled (NVIDIA runtime)
- Accessible at: http://192.168.1.227:32400 or https://poile.duckdns.org:32400

#### Wireguard
- Configured for 3 peers: mac, iphone, backup
- Uses Pihole as DNS server (192.168.1.227)

#### Torrent Stack
- Routes all traffic through Mullvad VPN
- Uses Seattle server (usa-sea-wg-001)
- Transmission web UI with custom theme

## Networking

- Proxy network: Used by services behind Traefik
- Default bridge: Direct port exposure
- Host network: For services requiring full network access

## Security Considerations

1. Change all default passwords in .env
2. Use strong, unique passwords for each service
3. Keep VPN credentials secure
4. Regularly update container images
5. Monitor Pihole for suspicious DNS queries
6. Use Traefik for SSL termination when exposing services

## Backup Recommendations

Critical data to backup:
- `/storage/docker_volumes/*` - All service configurations
- `.env` file - Environment variables
- Plex database - `/config/Library/Application Support/Plex Media Server/`

## Requirements

- Docker & Docker Compose
- NVIDIA GPU drivers (for Plex hardware transcoding)
- Terraform >= 1.0.0
- Sufficient storage for media files
- Static IP or dynamic DNS for external access