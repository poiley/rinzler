# Port Migration Strategy

## Current Docker Services → K3s Migration

Since we're replacing ALL Docker services with k3s, we need to handle port conflicts during migration.

## Strategy: Parallel Running with Different Ports

### Phase 1: k3s Infrastructure (Different Ports)
During migration, k3s services will use alternate ports:

| Service | Docker Port | k3s Migration Port | Final Port |
|---------|-------------|-------------------|------------|
| Traefik HTTP | 80 | 8880 | 80 |
| Traefik HTTPS | 443 | 8443 | 443 |
| Traefik Dashboard | 8080 | 9080 | 8080 |

### Phase 2: Service Migration Pattern
For each service:
1. Deploy in k3s on alternate port
2. Test functionality
3. Stop Docker container
4. Update k3s service to use original port

Example for Plex:
- Docker: 32400
- k3s (temp): 32401
- k3s (final): 32400

### Phase 3: Cutover Plan
1. **Preparation**:
   - All services running in k3s on alternate ports
   - Fully tested and verified

2. **Cutover** (minimize downtime):
   ```bash
   # Stop all Docker containers
   docker stop $(docker ps -q)
   
   # Update k3s services to original ports
   kubectl apply -f final-configs/
   
   # Verify services
   kubectl get svc -A
   ```

3. **Cleanup**:
   - Remove Docker containers
   - Uninstall Docker (optional)
   - Remove old data

## Service Migration Order

### Priority 1 - Core Infrastructure
1. Traefik (new instance in k3s)
2. DNS/Network services

### Priority 2 - Stateless Services  
1. Flaresolverr
2. Jackett
3. Tautulli

### Priority 3 - Download Stack
1. Gluetun (VPN)
2. Transmission

### Priority 4 - Media Services
1. Sonarr/Radarr/Bazarr
2. Plex (with GPU)

### Priority 5 - Other Apps
1. Home Assistant
2. Remaining services

## Rollback Points
- Keep Docker installed until Phase 3 complete
- Maintain port mappings document
- Test each service before moving to next