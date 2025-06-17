#!/bin/bash

# Kubernetes Media Server Deployment Script
# This script deploys the entire media server infrastructure to Kubernetes

set -e

echo "🚀 Starting Kubernetes Media Server Deployment"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_success "Connected to Kubernetes cluster"

# Check if Helm is available (needed for Vault)
if ! command -v helm &> /dev/null; then
    print_warning "Helm is not installed. Some features like Vault won't be available."
    print_status "Install Helm: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
fi

# Step 1: Create namespaces
print_status "Creating namespaces..."
kubectl apply -f manifests/namespace.yaml
print_success "Namespaces created"

# Step 2: Create storage classes and persistent volumes
print_status "Setting up storage with data protection..."
kubectl apply -f manifests/storage/storage-classes.yaml
kubectl apply -f manifests/storage/persistent-volumes.yaml
print_success "Storage configured with data protection"

# Step 3: Deploy Vault for secrets management (if Helm is available)
if command -v helm &> /dev/null; then
    print_status "Setting up Vault for secrets management..."
    
    # Add Helm repositories
    helm repo add hashicorp https://helm.releases.hashicorp.com 2>/dev/null || true
    helm repo add external-secrets https://charts.external-secrets.io 2>/dev/null || true
    helm repo update
    
    # Check if Vault is already installed
    if ! helm list -n vault-system | grep -q vault; then
        print_status "Installing Vault..."
        kubectl create namespace vault-system --dry-run=client -o yaml | kubectl apply -f -
        
        helm install vault hashicorp/vault \
            --namespace vault-system \
            --set "server.dev.enabled=true" \
            --set "ui.enabled=true" \
            --set "injector.enabled=true" \
            --wait
        
        print_success "Vault installed"
        print_status "Run 'k8s/scripts/setup-vault-secrets.sh' to configure secrets"
    else
        print_status "Vault already installed"
    fi
    
    # Install External Secrets Operator
    if ! helm list -n external-secrets-system | grep -q external-secrets; then
        print_status "Installing External Secrets Operator..."
        kubectl create namespace external-secrets-system --dry-run=client -o yaml | kubectl apply -f -
        
        helm install external-secrets external-secrets/external-secrets \
            --namespace external-secrets-system \
            --set installCRDs=true \
            --wait
        
        print_success "External Secrets Operator installed"
    else
        print_status "External Secrets Operator already installed"
    fi
else
    print_warning "Skipping Vault setup (Helm not available)"
fi

# Step 4: Deploy networking components
print_status "Deploying networking components..."
kubectl apply -f manifests/networking/traefik.yaml
kubectl apply -f manifests/networking/pihole.yaml
print_success "Networking components deployed"

# Wait for Traefik to be ready
print_status "Waiting for Traefik to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/traefik -n networking
print_success "Traefik is ready"

# Step 5: Deploy monitoring stack
print_status "Deploying monitoring stack..."
kubectl apply -f manifests/monitoring/monitoring-stack.yaml
print_success "Monitoring stack deployed"

# Step 6: Deploy media services
print_status "Deploying media services..."
kubectl apply -f manifests/media/plex.yaml
kubectl apply -f manifests/media/arr-stack.yaml
kubectl apply -f manifests/media/additional-services.yaml
kubectl apply -f manifests/media/torrent-stack.yaml
print_success "Media services deployed"

# Wait for key services to be ready
print_status "Waiting for key services to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/plex -n media-server
kubectl wait --for=condition=available --timeout=300s deployment/radarr -n media-server
kubectl wait --for=condition=available --timeout=300s deployment/sonarr -n media-server
kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n monitoring
kubectl wait --for=condition=available --timeout=300s deployment/grafana -n monitoring

print_success "All services are ready!"

# Display service information
echo ""
echo "🎉 Deployment Complete!"
echo ""
echo "📊 Service Access URLs (assuming LoadBalancer IPs are configured):"
echo "   Traefik Dashboard: http://your-cluster-ip:8080"
echo "   Plex:             http://plex.local (or http://your-cluster-ip/plex)"
echo "   Radarr:           http://your-cluster-ip/radarr"
echo "   Sonarr:           http://your-cluster-ip/sonarr"
echo "   Lidarr:           http://your-cluster-ip/lidarr"
echo "   Bazarr:           http://your-cluster-ip/bazarr"
echo "   Jackett:          http://your-cluster-ip/jackett"
echo "   Tautulli:         http://your-cluster-ip/tautulli"
echo "   Transmission:     http://your-cluster-ip/transmission"
echo "   Prometheus:       http://your-cluster-ip/prometheus"
echo "   Grafana:          http://your-cluster-ip/grafana"
echo "   Pi-hole:          http://your-cluster-ip/pihole"

if command -v helm &> /dev/null; then
    echo "   Vault UI:         http://your-cluster-ip/vault"
fi

echo ""
echo "🔧 Next Steps:"
echo "   1. Configure secrets:"
if command -v helm &> /dev/null; then
    echo "      - Run: ./scripts/setup-vault-secrets.sh (recommended)"
    echo "      - Or manually update secrets in YAML files"
else
    echo "      - Update VPN credentials in torrent-stack.yaml"
    echo "      - Update Pi-hole password in pihole.yaml"
fi
echo "   2. Update node names in persistent-volumes.yaml if needed"
echo "   3. Configure your DNS to point to the Pi-hole service"
echo "   4. Access Rancher UI to monitor and manage your cluster"
echo "   5. Set up regular backups (automated backup job included)"
echo ""
echo "🔐 Security Features:"
echo "   • All storage volumes have 'Retain' policy (data never deleted)"
echo "   • Daily automated backups to /storage/backups"
echo "   • Vault-based secrets management"
echo "   • RBAC and network policies"
echo ""
echo "🧹 Docker Cleanup:"
echo "   • Run: ./scripts/docker-cleanup.sh to clean up old Docker setup"
echo ""
echo "📝 Check pod status with: kubectl get pods --all-namespaces"
echo "📝 Check services with: kubectl get services --all-namespaces"
echo "📝 Check storage with: kubectl get pv,pvc --all-namespaces" 