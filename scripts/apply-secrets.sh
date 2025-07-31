#!/bin/bash

# Script to apply secrets from .env.secrets to Kubernetes

set -e

# Check if .env.secrets exists
if [ ! -f ".env.secrets" ]; then
    echo "Error: .env.secrets file not found!"
    echo "Please copy .env.secrets.example to .env.secrets and fill in your values."
    exit 1
fi

# Load environment variables
export $(grep -v '^#' .env.secrets | xargs)

# Generate ArgoCD password hash if not provided
if [ -z "$ARGOCD_ADMIN_PASSWORD_HASH" ] && [ ! -z "$ARGOCD_ADMIN_PASSWORD" ]; then
    echo "Generating ArgoCD password hash..."
    ARGOCD_ADMIN_PASSWORD_HASH=$(htpasswd -nbBC 10 "" "$ARGOCD_ADMIN_PASSWORD" | tr -d ':\n')
    export ARGOCD_ADMIN_PASSWORD_HASH
fi

echo "Applying secrets to Kubernetes..."

# Apply ArgoCD secret
echo "Creating ArgoCD secret..."
envsubst < k8s/infrastructure/argocd/secret-from-env.yaml | kubectl apply -f -

# Apply DuckDNS secret
echo "Creating DuckDNS secret..."
envsubst < k8s/infrastructure/duckdns/secret.yaml | kubectl apply -f -

# Apply Pi-hole secret
echo "Creating Pi-hole secret..."
envsubst < k8s/network-services/pihole/secret.yaml | kubectl apply -f -

# Create Mullvad secret if variables are set
if [ ! -z "$MULLVAD_ACCOUNT" ]; then
    echo "Creating Mullvad VPN secret..."
    kubectl create secret generic mullvad-secrets \
        --from-literal=MULLVAD_ACCOUNT="$MULLVAD_ACCOUNT" \
        --from-literal=MULLVAD_CITY="$MULLVAD_CITY" \
        --from-literal=MULLVAD_COUNTRY="$MULLVAD_COUNTRY" \
        --namespace=download \
        --dry-run=client -o yaml | kubectl apply -f -
fi

# Create Arr-stack secret if variables are set
if [ ! -z "$JACKETT_API_KEY" ]; then
    echo "Creating Arr-stack secret..."
    kubectl create secret generic arr-config-secret \
        --from-literal=jackett-api-key="$JACKETT_API_KEY" \
        --from-literal=transmission-username="$TRANSMISSION_USERNAME" \
        --from-literal=transmission-password="$TRANSMISSION_PASSWORD" \
        --namespace=arr-stack \
        --dry-run=client -o yaml | kubectl apply -f -
fi

# Create Monitoring secret
echo "Creating Monitoring secret..."
# Create monitoring namespace if it doesn't exist
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
# Apply the monitoring secret
envsubst < k8s/monitoring/secret-from-env.yaml | kubectl apply -f -
# Apply Grafana secret
envsubst < k8s/monitoring/grafana/grafana-secret.yaml | kubectl apply -f -

echo "All secrets applied successfully!"