#!/bin/bash
# ArgoCD Installation Script for Rinzler Media Server
# This script installs ArgoCD and configures it for GitOps management

set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Installing ArgoCD for GitOps Management ===${NC}"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found. Please install K3s first.${NC}"
    exit 1
fi

# Check if K3s is running
if ! kubectl get nodes &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes. Is K3s running?${NC}"
    exit 1
fi

# Create ArgoCD namespace
echo -e "${GREEN}Creating ArgoCD namespace...${NC}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
echo -e "${GREEN}Installing ArgoCD...${NC}"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo -e "${GREEN}Waiting for ArgoCD to be ready...${NC}"
kubectl wait --for=condition=Available --timeout=300s deployment/argocd-server -n argocd
kubectl wait --for=condition=Available --timeout=300s deployment/argocd-repo-server -n argocd
kubectl wait --for=condition=Available --timeout=300s deployment/argocd-dex-server -n argocd
kubectl wait --for=condition=Available --timeout=300s deployment/argocd-applicationset-controller -n argocd
kubectl wait --for=condition=Available --timeout=300s deployment/argocd-notifications-controller -n argocd
kubectl wait --for=condition=Available --timeout=300s deployment/argocd-redis -n argocd

# Get admin password
echo -e "${GREEN}Getting ArgoCD admin password...${NC}"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Create ingress for ArgoCD (if Traefik is installed)
if kubectl -n infrastructure get deployment traefik &> /dev/null; then
    echo -e "${GREEN}Creating ArgoCD ingress...${NC}"
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
  - host: argocd.rinzler.grid
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
EOF
fi

echo -e "${GREEN}=== ArgoCD Installation Complete! ===${NC}"
echo ""
echo -e "${YELLOW}ArgoCD Access Information:${NC}"
echo -e "URL: ${GREEN}https://localhost:8080${NC} (requires port-forward)"
echo -e "URL: ${GREEN}http://argocd.rinzler.grid${NC} (if DNS is configured)"
echo -e "Username: ${GREEN}admin${NC}"
echo -e "Password: ${GREEN}${ARGOCD_PASSWORD}${NC}"
echo ""
echo -e "${YELLOW}To access ArgoCD UI:${NC}"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo -e "${YELLOW}Next step:${NC}"
echo "kubectl apply -f k8s/argocd/applications/"
echo ""
echo -e "${GREEN}ArgoCD will automatically manage all your services from Git!${NC}"