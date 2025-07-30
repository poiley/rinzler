# Secrets Configuration Status

All secrets have been extracted from the .env file and applied to K8s manifests to match the Docker deployments exactly.

## ✅ Configured Services

### Pi-hole
- **Password**: `password` (from .env)
- **Rate Limit**: `0/0`

### Samba  
- **Share**: `mount;/mount;yes;no;yes;all;none;none`
- **Workgroup**: `WORKGROUP`
- **Mount Path**: `/storage` → `/mount`

### Mullvad VPN (Gluetun)
- **Private Key**: `EKHPK+3TEeDhyOJ0QQfogjHtb4XJYoHoPsH7RAEehnE=`
- **IP Address**: `10.64.197.249/32`
- **Server**: Seattle WA, USA
- **Local Network**: `192.168.1.0/24`

### DuckDNS
- **Subdomain**: `poile`
- **Token**: `63b7895d-8fab-4294-aa03-df7c70bc3c5f`

### Plex
- **User**: `ben.poile`
- **Advertise IP**: `http://192.168.1.227:32400,https://poile.duckdns.org:32400`

### Arr Apps
- **Authentication**: Method 1 (Basic Auth)
- **URL Bases**: Removed for clean subdomain access

## 🔒 Security Note

These are the exact values from your current Docker deployment. After verifying everything works with K3s, you should:

1. Change the Pi-hole password
2. Rotate the Mullvad VPN key
3. Consider using Kubernetes Secrets instead of hardcoded values
4. Update DuckDNS token if compromised

## Ready to Deploy

All services now have identical configuration to Docker. You can proceed with:
```bash
sudo ./scripts/k3s-install.sh
```