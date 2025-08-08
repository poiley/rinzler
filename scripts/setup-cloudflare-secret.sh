#!/bin/bash

# Script to create Cloudflare API token secret for cert-manager
# This keeps the sensitive API token out of the git repository

set -e

echo "==================================="
echo "Cloudflare API Token Setup"
echo "==================================="
echo ""
echo "This script will create the Kubernetes secret needed for cert-manager"
echo "to issue Let's Encrypt certificates using DNS-01 challenge."
echo ""
echo "IMPORTANT: Your API token will NOT be stored in git!"
echo ""

# Check if secret already exists
if kubectl get secret cloudflare-api-token -n cert-manager &>/dev/null; then
    echo "⚠️  WARNING: cloudflare-api-token secret already exists in cert-manager namespace"
    read -p "Do you want to replace it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Exiting without changes."
        exit 0
    fi
    echo "Deleting existing secret..."
    kubectl delete secret cloudflare-api-token -n cert-manager
fi

# Prompt for API token
echo "Please enter your Cloudflare API token:"
echo "(You can create one at: https://dash.cloudflare.com/profile/api-tokens)"
echo ""
echo "Required permissions:"
echo "  - Zone:DNS:Edit"
echo "  - Zone:Zone:Read"
echo ""
read -s -p "API Token: " API_TOKEN
echo ""

if [ -z "$API_TOKEN" ]; then
    echo "❌ Error: API token cannot be empty"
    exit 1
fi

# Create the secret
echo ""
echo "Creating Kubernetes secret..."
kubectl create secret generic cloudflare-api-token \
    --from-literal=api-token="$API_TOKEN" \
    --namespace cert-manager

echo "✅ Secret created successfully!"
echo ""
echo "Next steps:"
echo "1. Your certificates should now be issued automatically"
echo "2. Check certificate status: kubectl get certificates -A"
echo "3. If you need to rotate the token, run this script again"
echo ""
echo "⚠️  SECURITY REMINDER:"
echo "   - NEVER commit API tokens to git"
echo "   - Rotate tokens regularly"
echo "   - Use tokens with minimal required permissions"