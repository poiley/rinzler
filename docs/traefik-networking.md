# Traefik Networking

## Architecture

K3s includes Traefik as the ingress controller. All HTTP/HTTPS traffic routes through Traefik for:
- SSL/TLS termination
- Hostname-based routing
- Load balancing

## DNS Configuration

Internal DNS (Pi-hole) resolves:
```
*.rinzler.me     → 192.168.1.227
*.rinzler.cloud  → 192.168.1.227
```

## Ingress Configuration

Each service defines an Ingress:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: service
  namespace: namespace
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-dns
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
            name: service
            port:
              number: 8080
```

## Certificate Management

- cert-manager provisions Let's Encrypt certificates
- DNS-01 challenge via Cloudflare API
- Auto-renewal 30 days before expiration

## Traffic Flow

```
Client → DNS (192.168.1.227) → Traefik (443/80) → Service Pod
```

## Troubleshooting

```bash
# Check ingresses
kubectl get ingress -A

# Check certificates
kubectl get certificates -A

# Traefik logs
kubectl logs -n kube-system deployment/traefik

# Test DNS
nslookup service.rinzler.me
curl -v https://service.rinzler.me
```