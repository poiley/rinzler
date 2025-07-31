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

# Deploy monitoring stack
echo "Deploying monitoring stack..."
cd k8s/monitoring
kubectl apply -f prometheus/
kubectl apply -f grafana/
kubectl apply -f exporters/

echo "Waiting for pods to be ready..."
kubectl wait --namespace=monitoring --for=condition=available --timeout=300s deployment/prometheus
kubectl wait --namespace=monitoring --for=condition=available --timeout=300s deployment/grafana

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