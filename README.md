# Docker Server Configuration

Infrastructure-as-code for personal media server running:
- Media: Plex, Sonarr, Radarr, Lidarr, Readarr, Bazarr, Tautulli
- Networking: Traefik, WireGuard, PiHole
- Storage: Samba
- Management: Portainer

## Setup

1. Clone repository
2. Copy .env.example to .env:
   ```bash
   cp .env.example .env
   ```
3. Edit .env and fill in your secure values:
   - Generate a new WireGuard private key
   - Set a secure Pihole password
   - Generate Base64 encoded credentials for Basic Auth
   - Adjust timezone if needed
   - Set appropriate PUID/PGID for your system
4. Deploy stacks using docker-compose or import into Portainer

## Stack Organization
- `media/`: Media server applications
- `networking/`: Reverse proxy and VPN
- `storage/`: File sharing services
- `other/`: Other services

## Future Enhancements
- [ ] Docker Swarm migration
- [ ] Backup/restore procedures
- [ ] Monitoring and alerting
- [ ] CI/CD pipeline
