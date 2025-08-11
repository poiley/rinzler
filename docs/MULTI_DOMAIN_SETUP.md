# Multi-Domain Setup

## Prerequisites
- Domains purchased (rinzler.me, rinzler.cloud)
- Cloudflare account (free tier)
- Cloudflare API token with Zone:DNS:Edit permissions

## 1. Configure Cloudflare

### Add Domains
1. Add each domain to Cloudflare (free plan)
2. Update nameservers at your registrar to Cloudflare's
3. Wait for activation email (5-48 hours)

### DNS Records
For each domain in Cloudflare DNS:
```
Type: A
Name: *
IP: 192.168.1.227
Proxy: DISABLED (gray cloud)
```

### API Token
1. Profile → API Tokens → Create Token → Custom Token
2. Permissions: Zone → DNS → Edit
3. Zone Resources: Include both domains
4. Save the token (shown only once)

## 2. Deploy cert-manager

```bash
# Create Cloudflare secret
kubectl create secret generic cloudflare-api-token \
  -n cert-manager \
  --from-literal=api-token=YOUR_TOKEN_HERE

# Apply issuer
kubectl apply -f k8s/cert-manager/issuers/letsencrypt-dns.yaml
```

## 3. Configure Ingresses

Each service needs TLS configuration:
```yaml
spec:
  tls:
  - hosts:
    - service.rinzler.me
    secretName: service-tls
  rules:
  - host: service.rinzler.me
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: service-name
            port:
              number: 8080
```

## 4. Internal DNS

Configure Pi-hole or internal DNS:
```
*.rinzler.me     → 192.168.1.227
*.rinzler.cloud  → 192.168.1.227
```

## Verification

```bash
# Check certificates
kubectl get certificates -A

# Test HTTPS
curl -v https://plex.rinzler.me
```

## Troubleshooting

Certificate not issuing:
- Check cert-manager logs: `kubectl logs -n cert-manager deploy/cert-manager`
- Verify API token permissions
- Ensure Cloudflare proxy is disabled (gray cloud)