# Kubernetes Configuration Validation Report

## Changes Made to Match Docker Deployments

### 1. Storage Volume Corrections
**Issue**: Services were using new PVCs instead of existing Docker volumes
**Fixed Services**:
- Sonarr: `/var/lib/docker/volumes/sonarr_data/_data`
- Radarr: `/var/lib/docker/volumes/radarr_data/_data`
- Lidarr: `/var/lib/docker/volumes/lidarr_data/_data`
- Tautulli: `/var/lib/docker/volumes/tautulli_data/_data`
- Jackett: `/var/lib/docker/volumes/jackett_data/_data`
- Mylar: `/var/lib/docker/volumes/mylar_data/_data`
- Transmission: `/var/lib/docker/volumes/transmission_data/_data`

**Removed**: All unnecessary PVC files

### 2. Missing Environment Variables
**Plex**: Added all missing env vars:
- DEBIAN_FRONTEND, LANG, LANGUAGE
- LSIO_FIRST_PARTY
- S6_CMD_WAIT_FOR_SERVICES_MAXTIME
- S6_STAGE2_HOOK, S6_VERBOSITY
- TERM, TMPDIR, VIRTUAL_ENV

**Arr Apps**: Added URL base configurations:
- Sonarr: SONARR__URLBASE=/sonarr
- Radarr: RADARR__URLBASE=/radarr
- Lidarr: LIDARR__URLBASE=/lidarr

**Pi-hole**: Added RATE_LIMIT=0/0

### 3. Services Verified as Correct
- Home Assistant: Properly configured with privileged mode and host network
- Bazarr: Using correct hostPath volume
- Kavita: Correct volume mounts
- DuckDNS: Correct configuration
- Samba: Proper volume setup
- Gluetun+Transmission: Correct multi-container pod setup

### 4. Port Mappings
All services maintain their original ports:
- Plex: 32400 (TCP/UDP)
- Sonarr: 8989
- Radarr: 7878
- Lidarr: 8686
- Readarr: 8787
- Bazarr: 6767
- Jackett: 9117
- Tautulli: 8181
- Transmission: 9091
- Home Assistant: 8123
- Pi-hole: 53 (DNS), 80 (Web)
- Samba: 139, 445

### 5. Special Configurations Preserved
- **GPU Access**: Plex with nvidia.com/gpu resource
- **Privileged Mode**: Home Assistant
- **Host Network**: Home Assistant
- **Network Namespace Sharing**: Gluetun+Transmission in same pod
- **Security Context**: FMD2 with seccomp:Unconfined

## Validation Summary
✅ All services now use existing Docker volumes
✅ All environment variables match Docker compose
✅ All port mappings preserved
✅ Special security/network requirements maintained
✅ Resource limits appropriate for each service

## Migration Notes
- Services will use exact same data/config as Docker
- No data migration needed
- Can run side-by-side during testing (using different ports)
- Rollback is simple - just stop k8s and restart Docker