#!/bin/bash
set -e

echo "🚀 Rinzler K3s Setup"
echo "===================="

# Check if running as root for K3s installation
if [[ $EUID -eq 0 ]]; then
   echo "✅ Running as root"
else
   echo "❌ This script must be run as root for K3s installation"
   exit 1
fi

# 1. Install K3s
echo -e "\n📦 Installing K3s..."
if command -v k3s &> /dev/null; then
    echo "K3s already installed, skipping..."
else
    ./scripts/k3s-install.sh
fi

# 2. Setup kubeconfig for non-root user
echo -e "\n🔧 Setting up kubeconfig..."
mkdir -p ~/.kube
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
chmod 600 ~/.kube/config
export KUBECONFIG=~/.kube/config

# 3. Wait for K3s to be ready
echo -e "\n⏳ Waiting for K3s to be ready..."
kubectl wait --for=condition=Ready node --all --timeout=60s

# 4. Create namespaces
echo -e "\n📁 Creating namespaces..."
kubectl apply -f k8s/namespaces/

# 5. Generate and apply secrets
echo -e "\n🔐 Setting up secrets..."
./scripts/generate-secrets.sh
kubectl apply -f k8s/secrets/

# 6. Install ArgoCD
echo -e "\n🚢 Installing ArgoCD..."
./scripts/install-argocd.sh

# 7. Deploy cert-manager
echo -e "\n🔒 Deploying cert-manager..."
kubectl apply -f k8s/cert-manager/application.yaml
echo "Waiting for cert-manager to be ready..."
sleep 30
kubectl wait --for=condition=Available deployment -n cert-manager cert-manager --timeout=300s

# 8. Setup Cloudflare secret for Let's Encrypt
echo -e "\n☁️ Setting up Cloudflare DNS..."
if kubectl get secret cloudflare-api-token -n cert-manager &> /dev/null; then
    echo "Cloudflare secret already exists, skipping..."
else
    echo "Please enter your Cloudflare API token:"
    read -s CLOUDFLARE_TOKEN
    kubectl create secret generic cloudflare-api-token \
        -n cert-manager \
        --from-literal=api-token="$CLOUDFLARE_TOKEN"
fi

# 9. Deploy cert-manager issuers
echo -e "\n📜 Deploying certificate issuers..."
kubectl apply -f k8s/cert-manager/issuers/application.yaml

# 10. Deploy all applications
echo -e "\n🎯 Deploying all applications..."
for app in k8s/*/application.yaml; do
    if [[ -f "$app" ]]; then
        echo "Deploying $(dirname $app | xargs basename)..."
        kubectl apply -f "$app"
    fi
done

# 11. Get ArgoCD admin password
echo -e "\n🔑 ArgoCD Admin Password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo -e "\n"

echo "================================"
echo "✅ Setup Complete!"
echo "================================"
echo ""
echo "Services will be available at:"
echo "  • ArgoCD: https://argocd.rinzler.me"
echo "  • Plex: https://plex.rinzler.me"
echo "  • Sonarr: https://sonarr.rinzler.me"
echo "  • etc..."
echo ""
echo "Note: DNS and certificates may take a few minutes to propagate"
echo ""
echo "Check deployment status:"
echo "  kubectl get applications -n argocd"
echo "  kubectl get certificates -A"