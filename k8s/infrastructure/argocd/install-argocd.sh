#!/bin/bash

# ArgoCD Installation Script

echo "=== Installing ArgoCD ==="

# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
echo "Waiting for ArgoCD pods to start..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Get initial admin password
echo ""
echo "=== ArgoCD Admin Password ==="
echo "Username: admin"
echo -n "Password: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""

# Create ingress for ArgoCD UI
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
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

echo ""
echo "=== ArgoCD Installation Complete ==="
echo ""
echo "Access ArgoCD:"
echo "1. Port forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   Then visit: https://localhost:8080"
echo ""
echo "2. Or visit directly (DNS already configured):"
echo "   http://argocd.rinzler.grid"
echo ""
echo "Login with:"
echo "  Username: admin"
echo "  Password: (shown above)"
echo ""
echo "First login: Change the admin password!"