#!/bin/bash
set -e

# Script to add multi-domain support (rinzler.me and rinzler.cloud) to all ingresses
# This allows services to be accessible via both domains with valid certificates

echo "=========================================="
echo "Adding Multi-Domain Support"
echo "=========================================="
echo ""

# Function to add domain rules to ingress
add_domain_rules() {
    local file=$1
    local service=$2
    
    # Check if already has multiple domains
    if grep -q "rinzler.me" "$file" && grep -q "rinzler.cloud" "$file"; then
        echo "  Already configured for multiple domains"
        return
    fi
    
    # Create backup
    cp "$file" "${file}.backup"
    
    # Create new ingress with multi-domain support
    cat > "${file}.tmp" << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $service
  namespace: $(grep -A5 "metadata:" "$file" | grep "namespace:" | awk '{print $2}')
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-dns-prod
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
spec:
  tls:
  - hosts:
    - ${service}.rinzler.me
    - ${service}.rinzler.cloud
    - ${service}.rinzler.grid
    secretName: ${service}-tls
  rules:
  - host: ${service}.rinzler.me
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ${service}
            port:
              number: $(grep -A10 "service:" "$file" | grep "number:" | head -1 | awk '{print $2}')
  - host: ${service}.rinzler.cloud
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ${service}
            port:
              number: $(grep -A10 "service:" "$file" | grep "number:" | head -1 | awk '{print $2}')
  - host: ${service}.rinzler.grid
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ${service}
            port:
              number: $(grep -A10 "service:" "$file" | grep "number:" | head -1 | awk '{print $2}')
EOF
    
    mv "${file}.tmp" "$file"
    echo "  ✓ Added multi-domain support"
}

# Update each ingress
for file in $(find k8s -name "ingress.yaml" -o -name "*-ingress.yaml" 2>/dev/null); do
    if grep -q "kind: Ingress" "$file"; then
        service_name=$(grep "name:" "$file" | head -1 | awk '{print $2}')
        echo "Processing $service_name..."
        
        # Special handling for services with different names
        case "$service_name" in
            argocd-server-ingress)
                service_name="argocd"
                ;;
            grafana)
                # Grafana is already named correctly
                ;;
            *)
                # Use the service name as-is
                ;;
        esac
        
        add_domain_rules "$file" "$service_name"
    fi
done

echo ""
echo "✓ All ingresses updated for multi-domain support!"
echo ""
echo "Services will be accessible at:"
echo "  - https://<service>.rinzler.me (trusted cert)"
echo "  - https://<service>.rinzler.cloud (trusted cert)"
echo "  - https://<service>.rinzler.grid (self-signed)"
echo ""