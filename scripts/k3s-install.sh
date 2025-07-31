#!/bin/bash

# K3s Installation Script for Rinzler
# Single-node media server with GPU support

set -e

echo "=== K3s Installation Script ==="
echo "This will install k3s with:"
echo "- Single node setup"
echo "- NVIDIA GPU support"
echo "- Local storage provisioner"
echo "- Traefik included (k3s version)"
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "Please run this script as a regular user with sudo access, not as root"
   exit 1
fi

echo "=== Pre-installation Checks ==="

# Check NVIDIA driver
if command -v nvidia-smi &> /dev/null; then
    echo "✓ NVIDIA drivers installed"
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
else
    echo "✗ NVIDIA drivers not found. Please install them first."
    exit 1
fi

# # Check if k3s already installed
# if command -v k3s &> /dev/null; then
#     echo "⚠️  k3s is already installed. Remove it first with:"
#     echo "  sudo /usr/local/bin/k3s-uninstall.sh"
#     exit 1
# fi

echo ""
echo "=== Installing k3s ==="

# Install k3s with traefik included
# With write-kubeconfig-mode for non-root access
#curl -sfL https://get.k3s.io | sh -s - \
#    --write-kubeconfig-mode 644

echo ""
echo "=== Configuring kubectl access ==="

# Set up kubeconfig for current user
mkdir -p $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
sed -i "s/127.0.0.1/$(hostname -I | awk '{print $1}')/g" $HOME/.kube/config

# Add to shell rc
if [[ $SHELL == *"zsh"* ]]; then
    echo 'export KUBECONFIG=$HOME/.kube/config' >> ~/.zshrc
    echo 'alias k=kubectl' >> ~/.zshrc
else
    echo 'export KUBECONFIG=$HOME/.kube/config' >> ~/.bashrc
    echo 'alias k=kubectl' >> ~/.bashrc
fi

echo ""
echo "=== Installing NVIDIA device plugin ==="

# Wait for k3s to be ready
echo "Waiting for k3s to start..."
sleep 10
kubectl wait --for=condition=Ready nodes --all --timeout=60s

# Install NVIDIA device plugin
kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.1/nvidia-device-plugin.yml

echo ""
echo "=== Setting up local-path storage ==="

# k3s comes with local-path-provisioner by default
# Just verify it's there
kubectl get storageclass

echo ""
echo "=== Creating namespaces ==="

# Create our namespaces
kubectl create namespace media
kubectl create namespace arr-stack
kubectl create namespace download
kubectl create namespace infrastructure
kubectl create namespace network-services
kubectl create namespace home

echo ""
echo "=== Installation Complete! ==="
echo ""
echo "Next steps:"
echo "1. Verify installation:"
echo "   kubectl get nodes"
echo "   kubectl get pods -A"
echo ""
echo "2. Check GPU support:"
echo "   kubectl get nodes -o json | jq '.items[].status.capacity'"
echo ""
echo "3. Source your shell config:"
echo "   source ~/.${SHELL##*/}rc"
echo ""
echo "4. Ready to deploy services!"