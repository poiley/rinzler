# K3s Migration Strategy

## Executive Summary
Migration from Portainer to k3s on a single-node media server with significant resource constraints and storage concerns.

## Pre-Migration Requirements

### 1. Storage Considerations
**Current State**: 94% full, 36% fragmented ZFS pool

**Recommended Actions**:
- Clean up old downloads (6+ months)
- Remove unused Docker volumes
- Consider ZFS snapshot cleanup
- While high, this won't block migration if your workload is mostly reads

**Commands to run**:
```bash
# Find largest directories
du -h /storage/ --max-depth=2 | sort -hr | head -20

# Check ZFS snapshots
zfs list -t snapshot -o name,used,referenced

# Check for orphaned Docker volumes
docker volume ls -q | xargs -I {} sh -c 'docker volume inspect {} | grep -q "Mountpoint.*_data" || echo "Orphaned: {}"'
```

### 2. Memory Benefits
**Current State**: 2.3GB free of 16GB total

**Expected improvements with k3s**:
- k3s uses ~500MB-1GB vs current Docker + Portainer overhead
- More efficient container runtime
- Better resource scheduling
- Should free up 1-2GB RAM overall

### 3. GPU Driver Setup
**Requirement**: Install NVIDIA drivers and nvidia-docker2
```bash
# Check GPU model first
lspci | grep -i nvidia

# Install drivers (after confirming model)
# ubuntu-drivers devices
# ubuntu-drivers autoinstall
```

## Migration Architecture

### Storage Strategy
```yaml
# Use hostPath for direct ZFS access
# Example PV for media library:
apiVersion: v1
kind: PersistentVolume
metadata:
  name: media-pv
spec:
  capacity:
    storage: 40Ti
  accessModes:
    - ReadWriteMany
  hostPath:
    path: /storage/media
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - rinzler
```

### Network Architecture
- Consolidate 17 Docker networks into k3s namespaces
- Use Traefik IngressRoute for service routing
- Maintain service discovery through k8s DNS

### Service Grouping
1. **media** namespace:
   - Plex, Tautulli, Kavita
   
2. **arr-stack** namespace:
   - Sonarr, Radarr, Lidarr, Readarr, Bazarr
   
3. **download** namespace:
   - Gluetun, Transmission, Jackett, Flaresolverr, Mylar, FMD2
   
4. **infrastructure** namespace:
   - Traefik, DuckDNS, ArgoCD

5. **network-services** namespace:
   - Pi-hole, Samba

6. **home** namespace:
   - Home Assistant

## Phased Migration Plan

### Phase 0: Preparation (Current)
- [ ] Clean up storage to <85% usage
- [ ] Install NVIDIA drivers
- [ ] Create full system backup
- [ ] Document all service configurations

### Phase 1: k3s Installation
- [ ] Install k3s with specific configurations
- [ ] Deploy NVIDIA device plugin
- [ ] Set up local-path-provisioner
- [ ] Configure resource quotas

### Phase 2: Infrastructure Services
- [ ] Migrate Traefik to k3s
- [ ] Deploy ArgoCD
- [ ] Set up Prometheus/Grafana
- [ ] Deploy Uptime Kuma

### Phase 3: Download Stack
- [ ] Create VPN pod (Gluetun)
- [ ] Migrate Transmission with VPN sidecar
- [ ] Migrate Jackett/Flaresolverr

### Phase 4: Media Stack
- [ ] Migrate Plex with GPU support
- [ ] Migrate *arr services
- [ ] Verify media library access

### Phase 5: Remaining Apps
- [ ] Migrate remaining services
- [ ] Decommission Portainer
- [ ] Final cleanup

## Rollback Strategy
- Keep Portainer running until Phase 4 complete
- Maintain docker-compose files as backup
- Use different ports during transition
- Document service dependencies

## Risk Mitigation

### High-Risk Items
1. **Storage Performance**: ZFS at 94% will severely impact k8s etcd performance
2. **Memory Exhaustion**: Limited headroom for k8s overhead
3. **Single Node**: No redundancy for etcd/control plane
4. **GPU Compatibility**: Ensure k8s NVIDIA plugin works with your GPU

### Monitoring During Migration
- Watch memory usage closely
- Monitor ZFS pool performance
- Check service availability continuously
- Keep detailed migration log

## Success Criteria
- All services running in k3s
- Resource usage ≤ current Docker setup
- Improved deployment workflow via GitOps
- Better monitoring visibility
- Maintain current performance levels