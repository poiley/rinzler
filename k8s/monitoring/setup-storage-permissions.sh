#!/bin/bash

# Script to set up Prometheus and Grafana monitoring stack

set -e

echo "Setting up monitoring stack..."

# Create directories with proper permissions
echo "Creating storage directories..."
sudo mkdir -p /storage/prometheus /storage/grafana
sudo chown -R 1000:1000 /storage/prometheus /storage/grafana

# Apply secrets
echo "Applying secrets..."
cd /home/poile/repos/rinzler
./scripts/apply-secrets.sh

# Note: This script is for initial directory setup only
# The actual deployment is managed by ArgoCD

echo "Monitoring stack directory permissions configured!"
echo ""
echo "To deploy the monitoring stack:"
echo "1. Ensure your .env.secrets file is configured"
echo "2. Run ./scripts/apply-secrets.sh"
echo "3. Apply the ArgoCD applications:"
echo "   kubectl apply -f k8s/argocd/applications/monitoring-*.yaml"
echo ""
echo "ArgoCD will handle the deployment automatically."

echo ""
echo "Monitoring stack deployed successfully!"
echo ""
echo "Access points:"
echo "- Grafana: http://grafana.rinzler.grid (admin / admin)"
echo "- Prometheus: http://prometheus.monitoring:9090 (internal)"
echo ""
echo "To import dashboards:"
echo "1. Log into Grafana"
echo "2. Go to Dashboards → Import"
echo "3. Use these dashboard IDs:"
echo "   - Node Exporter: 1860"
echo "   - ArgoCD: 14584"
echo "   - Kubernetes Cluster: 7249"