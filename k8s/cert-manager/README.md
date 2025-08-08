# SSL/HTTPS Setup (GitOps)

This directory contains the GitOps configuration for automatic HTTPS on all services using cert-manager.

## Architecture

- **cert-manager**: Kubernetes operator that automatically provisions and renews TLS certificates
- **ClusterIssuer**: Uses a self-signed CA for internal `.grid` domains
- **ArgoCD**: Manages everything automatically - no scripts needed

## Setup

1. **Deploy cert-manager via ArgoCD**:
   ```bash
   kubectl apply -f k8s/cert-manager/application.yaml
   ```

2. **Deploy the certificate issuers**:
   ```bash
   kubectl apply -f k8s/cert-manager/issuers/application.yaml
   ```

3. **Commit and push** - ArgoCD will automatically:
   - Install cert-manager
   - Create the CA issuer
   - Generate certificates for all ingresses
   - Keep everything in sync

## How It Works

Each ingress has these annotations:
```yaml
annotations:
  cert-manager.io/cluster-issuer: rinzler-ca-issuer
  traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
```

And TLS configuration:
```yaml
spec:
  tls:
  - hosts:
    - service.rinzler.grid
    secretName: service-tls
```

cert-manager automatically:
- Detects these annotations
- Generates a certificate signed by our CA
- Stores it in the specified secret
- Renews it before expiration

## Trust the CA Certificate

The CA certificate is in `rinzler-ca.crt`. Import it to your browser/OS to trust all services:

- **macOS**: Double-click the .crt file, add to Keychain, trust for SSL
- **Linux**: Copy to `/usr/local/share/ca-certificates/` and run `update-ca-certificates`
- **Windows**: Import via Certificate Manager (certmgr.msc)

## Adding New Services

Just create an ingress with:
1. The cert-manager annotation
2. The entrypoints annotation  
3. A TLS section

Certificate generation is automatic.

## Monitoring

```bash
# View all certificates
kubectl get certificates -A

# Check certificate details
kubectl describe certificate <name> -n <namespace>

# View cert-manager logs
kubectl logs -n cert-manager deploy/cert-manager
```

## No Scripts Needed

Everything is managed through Git and ArgoCD. Just commit changes and push - ArgoCD handles the rest.