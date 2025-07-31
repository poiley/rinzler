#!/bin/bash

# Script to build and deploy the Rinzler monitoring dashboard

set -e

echo "Building monitoring collector Docker image..."
cd collector
docker build -t rinzler/monitoring-collector:latest .

echo "Loading image into k3s..."
docker save rinzler/monitoring-collector:latest | sudo k3s ctr images import -

cd ..

echo "Deploying to Kubernetes..."
kubectl apply -k .

echo "Waiting for deployment to be ready..."
kubectl wait --namespace=monitoring --for=condition=available --timeout=300s deployment/monitoring-collector

echo "Deployment complete!"
echo ""
echo "Dashboard will be available at: http://monitoring.rinzler.grid"
echo ""
echo "NOTE: Make sure you have configured your API keys in .env.secrets file"
echo "      and run ./scripts/apply-secrets.sh before deploying!"
echo ""
echo "To get API keys:"
echo "- Plex: https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/"
echo "- *arr services: Settings > General > API Key"
echo "- ArgoCD: argocd account generate-token"
echo "- Jackett: Top right corner of web UI"
echo "- Tautulli: Settings > Web Interface > API Key"