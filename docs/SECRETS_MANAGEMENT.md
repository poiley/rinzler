# Secrets Management

This document describes how secrets are managed in the Rinzler infrastructure.

## Overview

All sensitive values have been moved from hardcoded YAML files to environment variables and Kubernetes secrets. This ensures that:

1. Secrets are never committed to the repository
2. Secrets can be easily rotated
3. Different environments can use different values

## Setup

1. Copy the example secrets file:
   ```bash
   cp .env.secrets.example .env.secrets
   ```

2. Edit `.env.secrets` and fill in your actual values:
   ```bash
   nano .env.secrets
   ```

3. Apply the secrets to your Kubernetes cluster:
   ```bash
   ./scripts/apply-secrets.sh
   ```

## Secrets Required

### ArgoCD
- `ARGOCD_ADMIN_PASSWORD`: Plain text password for ArgoCD admin user
- `ARGOCD_SERVER_SECRET_KEY`: Secret key for ArgoCD server (generate a strong random key)

### DuckDNS
- `DUCKDNS_TOKEN`: Your DuckDNS API token

### Pi-hole
- `PIHOLE_WEBPASSWORD`: Password for Pi-hole web interface

### Optional: VPN (Mullvad)
- `MULLVAD_ACCOUNT`: Your Mullvad account number
- `MULLVAD_CITY`: Preferred VPN city
- `MULLVAD_COUNTRY`: Preferred VPN country

### Optional: Arr-Stack
- `JACKETT_API_KEY`: Jackett API key
- `TRANSMISSION_USERNAME`: Transmission username
- `TRANSMISSION_PASSWORD`: Transmission password

## Security Notes

1. **Never commit `.env.secrets`** - It's already in `.gitignore`
2. **Rotate secrets regularly** - Especially if they may have been exposed
3. **Use strong passwords** - Generate random passwords for production use
4. **Secure your cluster** - Ensure RBAC is properly configured

## Applying Individual Secrets

If you need to apply secrets manually:

```bash
# Load environment variables
export $(grep -v '^#' .env.secrets | xargs)

# Apply ArgoCD secret
envsubst < k8s/infrastructure/argocd/secret-from-env.yaml | kubectl apply -f -

# Apply DuckDNS secret
envsubst < k8s/infrastructure/duckdns/secret.yaml | kubectl apply -f -

# Apply Pi-hole secret
envsubst < k8s/network-services/pihole/secret.yaml | kubectl apply -f -
```

## Troubleshooting

If secrets are not being applied correctly:

1. Check that the namespaces exist:
   ```bash
   kubectl get namespaces
   ```

2. Verify the secrets were created:
   ```bash
   kubectl get secrets -A | grep -E "argocd-secret|duckdns-secret|pihole-secret"
   ```

3. Check pod logs for any errors:
   ```bash
   kubectl logs -n <namespace> <pod-name>
   ```