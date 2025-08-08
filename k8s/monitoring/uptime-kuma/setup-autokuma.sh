#!/bin/bash

# Setup script for AutoKuma with Uptime Kuma
# This script configures the admin password for automated monitor management

set -e

echo "======================================"
echo "AutoKuma + Uptime Kuma Setup"
echo "======================================"
echo ""
echo "This will set up a fully automated Uptime Kuma with AutoKuma managing all monitors."
echo ""

# Check if secret exists
if kubectl get secret autokuma-secret -n monitoring &>/dev/null; then
    echo "⚠️  Warning: autokuma-secret already exists"
    read -p "Do you want to update the admin password? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing password"
    else
        read -sp "Enter new admin password (min 8 chars): " PASSWORD
        echo
        kubectl delete secret autokuma-secret -n monitoring
        kubectl create secret generic autokuma-secret \
            --from-literal=admin-password="$PASSWORD" \
            -n monitoring
        echo "✅ Password updated"
    fi
else
    echo "Setting up admin password for Uptime Kuma..."
    echo "This password will be used for:"
    echo "  - Web UI login (username: admin)"
    echo "  - AutoKuma automation"
    echo ""
    read -sp "Enter admin password (min 8 chars): " PASSWORD
    echo
    kubectl create secret generic autokuma-secret \
        --from-literal=admin-password="$PASSWORD" \
        -n monitoring
    echo "✅ Secret created"
fi

echo ""
echo "======================================"
echo "Deployment Status"
echo "======================================"
echo ""

# Check deployment status
echo "Checking Uptime Kuma deployment..."
kubectl rollout status deployment/uptime-kuma -n monitoring --timeout=120s || true

echo ""
echo "Checking AutoKuma deployment..."
kubectl rollout status deployment/autokuma -n monitoring --timeout=120s || true

echo ""
echo "======================================"
echo "Access Information"
echo "======================================"
echo ""
echo "🌐 Uptime Kuma URLs:"
echo "   - https://uptime.rinzler.cloud"
echo "   - https://uptime.rinzler.me"
echo ""
echo "👤 Login Credentials:"
echo "   - Username: admin"
echo "   - Password: [the password you just set]"
echo ""
echo "🤖 AutoKuma Status:"
echo "   AutoKuma will automatically:"
echo "   - Create the admin account on first run"
echo "   - Configure all monitors from ConfigMaps"
echo "   - Keep monitors in sync with Git"
echo ""
echo "📊 Configured Monitors:"
echo "   - Infrastructure: ArgoCD, Traefik"
echo "   - Monitoring: Prometheus, Grafana"
echo "   - Media: Plex, Tautulli, Kavita"
echo "   - Arr Stack: Sonarr, Radarr, Bazarr, Lidarr, Readarr"
echo "   - Download: Transmission, Jackett, FlareSolverr, Mylar"
echo "   - Network: PiHole"
echo ""
echo "To view AutoKuma logs:"
echo "  kubectl logs -n monitoring deployment/autokuma -f"
echo ""
echo "To modify monitors:"
echo "  Edit: k8s/monitoring/uptime-kuma/autokuma-monitors-configmap.yaml"
echo "  Then: git commit && git push (ArgoCD will sync)"
echo ""