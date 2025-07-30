# Pre-Deployment Checklist

## 🔴 Required - Update These Values

### 1. Pi-hole Admin Password
**File**: `k8s/network-services/pihole/deployment.yaml`
```yaml
- name: WEBPASSWORD
  value: "admin"  # Change this!
```

### 2. Samba Password  
**File**: `k8s/network-services/samba/deployment.yaml`
```yaml
- name: USER
  value: "poile;password"  # Change password!
```

### 3. Mullvad VPN Configuration
**File**: `k8s/download/gluetun-transmission/deployment.yaml`
```yaml
- name: WIREGUARD_PRIVATE_KEY
  value: "EKHPK+3TEeDhyOJ0QQfogjHtb4XJYoHoPsH7RAEehnE="  # Your actual key
- name: WIREGUARD_ADDRESSES  
  value: "10.64.197.249/32"  # Your assigned IP
```

## 🟡 Verify These Settings

### 4. Network Configuration
**File**: `k8s/download/gluetun-transmission/deployment.yaml`
```yaml
- name: FIREWALL_OUTBOUND_SUBNETS
  value: "192.168.1.0/24"  # Verify this matches your LAN
```

### 5. DuckDNS (if using)
**File**: `k8s/infrastructure/duckdns/deployment.yaml`
- Add your DuckDNS token

## 🟢 Pre-Deployment Verification

Run these checks before deployment:

```bash
# Check current Docker containers (for reference)
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Verify storage paths exist
ls -la /storage/docker_volumes/
ls -la /var/lib/docker/volumes/

# Check NVIDIA driver
nvidia-smi

# Verify network
ip addr show | grep 192.168
```

## 📝 Notes

- All other environment variables have been validated against Docker configs
- Service URLs will change from ports to subdomains (e.g., `sonarr.rinzler.grid`)
- You can run K3s alongside Docker during migration
- Use the rollback plan in 01-installation-guide.md if needed

## Ready to Deploy?

Once you've updated the required values above:
```bash
sudo ./scripts/k3s-install.sh
```

Then follow [01-installation-guide.md](01-installation-guide.md) for the complete deployment process.