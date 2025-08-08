# Multi-Domain Setup Guide for rinzler.me & rinzler.cloud

## Prerequisites
1. Purchase both domains from Namecheap
2. Point both domains to Cloudflare (free tier is fine)
3. Get Cloudflare API token with Zone:DNS:Edit permissions

## Step 1: Purchase Domains on Namecheap

### Buy the domains
1. Go to https://www.namecheap.com
2. Search for `rinzler.me` and `rinzler.cloud`
3. Add both to cart and purchase
4. **IMPORTANT**: Decline all extras except maybe WhoisGuard (free privacy protection)

### Initial Namecheap Setup
1. Log into Namecheap Dashboard
2. Go to "Domain List"
3. For each domain (rinzler.me and rinzler.cloud):
   - Click "Manage"
   - Go to "Domain" tab
   - Under "NAMESERVERS", select "Custom DNS"
   - **Don't add nameservers yet** - we'll get these from Cloudflare

## Step 2: Set up Cloudflare (Free Account)

### Create Cloudflare Account
1. Go to https://cloudflare.com and sign up (free)
2. Click "Add a Site" button

### Add rinzler.me to Cloudflare
1. Enter `rinzler.me` in the domain field
2. Select the **FREE** plan ($0/month)
3. Cloudflare will scan for existing DNS records (there won't be any)
4. Click "Continue"
5. **IMPORTANT**: Cloudflare will show you two nameservers like:
   ```
   anna.ns.cloudflare.com
   bob.ns.cloudflare.com
   ```
   **SAVE THESE** - you need them for Namecheap

### Add rinzler.cloud to Cloudflare
1. Click "Add a Site" again
2. Enter `rinzler.cloud`
3. Select FREE plan
4. Continue through setup
5. **SAVE THE NAMESERVERS** for this domain too (might be different)

## Step 3: Connect Namecheap to Cloudflare

### Update Nameservers in Namecheap
1. Go back to Namecheap Dashboard
2. For **rinzler.me**:
   - Click "Manage" → "Domain" tab
   - Under "NAMESERVERS", select "Custom DNS"
   - Add the two nameservers Cloudflare gave you for rinzler.me
   - Click the checkmark to save
3. For **rinzler.cloud**:
   - Click "Manage" → "Domain" tab  
   - Under "NAMESERVERS", select "Custom DNS"
   - Add the two nameservers Cloudflare gave you for rinzler.cloud
   - Click the checkmark to save

**NOTE**: DNS propagation takes 5-48 hours. Cloudflare will email you when active.

## Step 4: Configure DNS in Cloudflare

### Wait for Activation
1. You'll get emails from Cloudflare when each domain is active
2. Check status in Cloudflare dashboard - should show "Active"

### Add DNS Records
For **EACH** domain in Cloudflare dashboard:

1. Go to domain (rinzler.me) → "DNS" → "Records"
2. Click "Add record"
3. Add wildcard record:
   - Type: `A`
   - Name: `*` (just the asterisk)
   - IPv4 address: `192.168.1.227` (your cluster IP)
   - Proxy status: **DISABLED** (click to make it gray, not orange)
   - TTL: Auto
   - Save

4. Optionally add root domain:
   - Type: `A`
   - Name: `@`
   - IPv4 address: `192.168.1.227`
   - Proxy status: **DISABLED**
   - Save

5. Repeat for rinzler.cloud

**IMPORTANT**: The proxy MUST be disabled (gray cloud) so the DNS resolves to your internal IP!

## Step 5: Create Cloudflare API Token

### Generate API Token
1. In Cloudflare, click your profile icon (top right)
2. Go to "My Profile"
3. Click "API Tokens" tab
4. Click "Create Token"
5. Click "Create Custom Token"
6. Configure token:
   - **Token name**: `cert-manager-dns`
   - **Permissions**: 
     - Zone → DNS → Edit
   - **Zone Resources**:
     - Include → Specific zone → rinzler.me
     - Include → Specific zone → rinzler.cloud
   - **IP Address Filtering** (optional): Leave blank
   - **TTL**: Leave as default

7. Click "Continue to summary"
8. Click "Create Token"
9. **COPY THE TOKEN** - you only see it once!
   ```
   Example: Vx3awBkZ3YAD-OsdlkjLKSDFLKJ234lkjsdf_3dS
   ```

### Test the Token (Optional)
```bash
# Test with curl (replace YOUR_TOKEN)
curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type:application/json"
```

## Step 6: Configure cert-manager with Your API Token

### Update the secret with your API token:
```bash
# Edit k8s/cert-manager/issuers/letsencrypt-dns.yaml
# Replace YOUR-CLOUDFLARE-API-TOKEN with actual token
# Replace your-email@example.com with your email

kubectl apply -f k8s/cert-manager/issuers/letsencrypt-dns.yaml
```

## Step 3: Update Ingresses

### Option A: Multi-domain per service
Each service accessible via both domains:
```yaml
spec:
  tls:
  - hosts:
    - service.rinzler.me
    - service.rinzler.cloud
    secretName: service-tls
  rules:
  - host: service.rinzler.me
    http: ...
  - host: service.rinzler.cloud
    http: ...
```

### Option B: Use wildcard certificates
Deploy wildcard certs once:
```bash
kubectl apply -f k8s/cert-manager/certificates/wildcard-certs.yaml
```

Then reference in ingresses:
```yaml
spec:
  tls:
  - hosts:
    - service.rinzler.me
    secretName: wildcard-rinzler-me-tls
  - hosts:
    - service.rinzler.cloud
    secretName: wildcard-rinzler-cloud-tls
```

## Step 4: Internal DNS

Update your Pi-hole/internal DNS:
```
# Option 1: Point to cluster
*.rinzler.me     → 192.168.1.227
*.rinzler.cloud  → 192.168.1.227

# Option 2: Individual entries
plex.rinzler.me      → 192.168.1.227
sonarr.rinzler.me    → 192.168.1.227
# ... etc
```

## Benefits

- **Trusted certificates**: No browser warnings
- **Redundancy**: If one domain has issues, use the other
- **Flexibility**: Can use .me for personal, .cloud for family
- **Internal only**: DNS points to internal IPs only
- **Keep .grid**: Can still use .grid internally with self-signed

## Testing

```bash
# Test DNS resolution
nslookup plex.rinzler.me
nslookup plex.rinzler.cloud

# Test certificate issuance
kubectl describe certificate -A

# Test HTTPS
curl -v https://plex.rinzler.me
curl -v https://plex.rinzler.cloud
```

## Important Notes

- Certificates auto-renew every 60 days
- DNS-01 challenge means no external access needed
- Both domains can point to same internal IP
- Can gradually migrate from .grid to real domains

## Troubleshooting

### DNS Not Resolving
```bash
# Check if nameservers are updated
nslookup -type=NS rinzler.me

# Should return cloudflare nameservers
# If not, wait longer for propagation
```

### Certificate Not Issuing
```bash
# Check cert-manager logs
kubectl logs -n cert-manager deploy/cert-manager

# Check challenge status
kubectl get challenges -A

# Common issues:
# - API token wrong permissions
# - DNS not propagated yet (wait 24h)
# - Cloudflare proxy enabled (should be gray cloud)
```

### Still Getting Certificate Warnings
- Make sure you're using `letsencrypt-dns-prod` not `rinzler-ca-issuer`
- Check certificate is issued: `kubectl get certificates -A`
- Verify DNS resolves to internal IP: `nslookup plex.rinzler.me`

## Summary Timeline

1. **Hour 0**: Buy domains on Namecheap
2. **Hour 0.5**: Add to Cloudflare, get nameservers
3. **Hour 1**: Update nameservers in Namecheap
4. **Hour 2-48**: Wait for DNS propagation
5. **Hour 48**: Configure DNS records in Cloudflare
6. **Hour 49**: Create API token
7. **Hour 50**: Deploy cert-manager config
8. **Hour 51**: Update ingresses
9. **Hour 52**: Enjoy trusted HTTPS!