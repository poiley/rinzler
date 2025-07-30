# Pi-hole DNS Configuration for .grid TLD

## Setup Instructions

After deploying Pi-hole, configure local DNS for the .grid domain:

### Option 1: Wildcard DNS (Recommended)
1. Access Pi-hole admin at `http://rinzler:8081/admin`
2. Go to Local DNS → DNS Records
3. Add: `rinzler.grid` → `<your-server-ip>`
4. Go to Local DNS → CNAME Records
5. Add: `*.rinzler.grid` → `rinzler.grid`

### Option 2: Individual Records
Add each service manually in Local DNS → DNS Records:
- `plex.rinzler.grid` → `<your-server-ip>`
- `sonarr.rinzler.grid` → `<your-server-ip>`
- `radarr.rinzler.grid` → `<your-server-ip>`
- etc.

### Option 3: Custom dnsmasq
Create `/etc/dnsmasq.d/10-rinzler.conf`:
```
address=/rinzler.grid/<your-server-ip>
```

## Clean URLs Configuration

The arr apps (Sonarr, Radarr, Lidarr) have been configured WITHOUT URL bases, so you get:
- ✅ `sonarr.rinzler.grid` (clean!)
- ❌ ~~`sonarr.rinzler.grid/sonarr`~~ (no more double names!)

This was achieved by removing the `*ARR__URLBASE` environment variables from the deployments.

## Testing
After configuration, test with:
```bash
nslookup plex.rinzler.grid <pihole-ip>
curl -I http://plex.rinzler.grid
```