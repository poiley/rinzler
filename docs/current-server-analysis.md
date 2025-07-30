# Current Server Analysis - Portainer to K3s Migration

## What We Know So Far

### Storage Architecture
- **ZFS Pool**: Manually created and managed via zfs/zpool CLI
- **Mount Point**: `/storage` on Ubuntu host
- **Structure**:
  ```
  /storage/
  ├── docker_volumes/     # Container configuration data
  ├── media/              # Media libraries
  │   ├── movies/
  │   └── tv/
  ├── downloads/          # Download directory
  └── repos/              # Code repositories
  ```

### Current Services (from Portainer backup)
1. **Media Services**:
   - Plex (using NVIDIA GPU via `runtime: nvidia`)
   - Sonarr, Radarr, Bazarr (subtitle management)
   - Lidarr (music), Readarr (books)
   - Tautulli (Plex stats), Jackett (indexer)
   - Mylar (comics), Kavita (reading server)

2. **Download Services**:
   - Transmission (BitTorrent client)
   - Gluetun (VPN container with Mullvad)

3. **Infrastructure**:
   - Traefik (reverse proxy)
   - Portainer (current container management)
   - VSCode Server
   - Home Assistant (requires privileged mode)

4. **Supporting Services**:
   - Flaresolverr (Cloudflare bypass)
   - Kaizoku (manga) with PostgreSQL + Redis
   - Samba (file sharing)
   - Organizr (dashboard)

### Key Technical Requirements
- **GPU Access**: Plex needs NVIDIA GPU access
- **Privileged Mode**: Home Assistant requires privileged container
- **Network Modes**: Some services use host networking
- **VPN Networking**: Transmission routes through Gluetun container

## Server Specifications (from diagnostics)

### System Information
- **Hostname**: rinzler
- **OS**: Ubuntu 20.04.6 LTS
- **Kernel**: 5.4.0-212-generic
- **Architecture**: x86_64
- **Docker**: v28.0.2 (latest stable)

### Hardware
- **CPU**: Intel Core i7-9700K @ 3.60GHz (8 cores, 8 threads)
- **RAM**: 16GB total (12GB used, 2.3GB available)
- **GPU**: NVIDIA GPU present (nvidia-smi not installed, but Plex using nvidia runtime)

### Storage Architecture
- **ZFS Pool**: Single pool named "storage"
  - **Size**: 43.6TB total
  - **Used**: 41.1TB (94% capacity)
  - **Available**: 2.49TB
  - **Fragmentation**: 36%
  - **Configuration**: 6 drives (sda through sdf) in single vdev
  - **Health**: ONLINE
  - **Mount**: `/storage`
  
- **Root Filesystem**: 196GB LVM on NVMe (79% used)
- **Boot**: Separate /boot and /boot/efi partitions on NVMe

### Network Configuration
- **Primary Interface**: eno1 (192.168.1.227)
- **Tailscale**: Installed (tailscale0 interface present)
- **Docker Networks**: 17 bridge networks
- **Exposed Ports**: 
  - Web services: 80, 443, 8080, 8090
  - Media services: 32400 (Plex), 7878 (Radarr), 8686 (Lidarr), 6767 (Bazarr)
  - Download services: 9091 (Transmission), 51820 (VPN)
  - Management: 9443 (Portainer), 3000 (Grafana/other)

### Current Docker Environment
- **Containers**: 25 total, 19 running
- **Storage Driver**: overlay2
- **Docker Root**: `/var/lib/docker`
- **Named Volumes**: 14 volumes for service configs
- **Resource Usage**:
  - Plex: 2.5GB RAM, 4.38% CPU (largest consumer)
  - fmd2: 41.88% CPU (high usage)
  - Most services: <500MB RAM each

### Special Requirements Confirmed
- **GPU Access**: Only Plex container
- **Privileged Mode**: None currently
- **Host Network**: None currently
- **VPN Setup**: Transmission routes through Gluetun container

## Critical Observations

### Storage Concerns
1. **ZFS Pool at 94% capacity** - Critical for performance
2. **High fragmentation (36%)** - May impact performance
3. **Single vdev with 6 drives** - No redundancy configured
4. **Root filesystem at 79%** - Limited space for k3s/containers

### Memory Constraints
- Only 2.3GB available RAM
- Current containers using ~8GB total
- k3s overhead needs consideration

### Network Complexity
- 17 Docker networks (many service-specific)
- Mix of default and custom networks
- Need to consolidate for k3s

## Migration Considerations

### Priority Issues
1. **Storage capacity** - Need cleanup strategy before migration
2. **Memory usage** - May need to optimize container resources
3. **GPU support** - Ensure k3s NVIDIA device plugin setup
4. **Network consolidation** - Simplify network architecture

### Architecture Decisions
1. **Storage**: Use hostPath volumes to maintain ZFS direct access
2. **Networking**: Use k3s default CNI (Flannel) with Traefik ingress
3. **GPU**: Install NVIDIA device plugin for k3s
4. **Resource limits**: Implement proper resource quotas

## Next Steps
1. Address storage capacity issue
2. Create k3s installation plan with resource constraints
3. Design phased migration approach
4. Create backup strategy before migration