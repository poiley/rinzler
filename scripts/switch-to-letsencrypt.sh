#!/bin/bash
set -e

# Script to switch all services from self-signed to Let's Encrypt certificates
# and add support for multiple domains (rinzler.me and rinzler.cloud)

echo "=========================================="
echo "Switching to Let's Encrypt Certificates"
echo "=========================================="
echo ""

# Check if DNS is ready
echo "Checking DNS resolution..."
for domain in rinzler.me rinzler.cloud; do
    echo -n "Checking *.$domain... "
    if nslookup plex.$domain >/dev/null 2>&1; then
        echo "✓ Resolving"
    else
        echo "✗ Not ready"
        echo ""
        echo "ERROR: DNS not ready yet. Please wait for nameserver propagation."
        echo "This can take 5-48 hours after updating Namecheap."
        exit 1
    fi
done
echo ""

# Apply Let's Encrypt issuer
echo "Applying Let's Encrypt issuer configuration..."
kubectl apply -f k8s/cert-manager/issuers/letsencrypt-dns-prod.yaml
echo "✓ Let's Encrypt issuer configured"
echo ""

# Update all ingresses
echo "Updating all ingresses to use Let's Encrypt..."
for file in $(find k8s -name "ingress.yaml" -o -name "*-ingress.yaml" 2>/dev/null); do
    if grep -q "kind: Ingress" "$file"; then
        service_name=$(grep "name:" "$file" | head -1 | awk '{print $2}')
        namespace=$(grep -B10 "kind: Ingress" "$file" | grep "namespace:" | head -1 | awk '{print $2}')
        
        # Skip if namespace is empty (some ingresses might not have it in metadata)
        if [ -z "$namespace" ]; then
            namespace="default"
        fi
        
        echo "Processing $service_name in namespace $namespace..."
        
        # Update to use Let's Encrypt issuer
        sed -i 's/cert-manager.io\/cluster-issuer: rinzler-ca-issuer/cert-manager.io\/cluster-issuer: letsencrypt-dns-prod/g' "$file"
        sed -i 's/cert-manager.io\/cluster-issuer: ca-issuer/cert-manager.io\/cluster-issuer: letsencrypt-dns-prod/g' "$file"
        
        echo "  ✓ Updated to Let's Encrypt issuer"
    fi
done

echo ""
echo "✓ All ingresses updated!"
echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. Commit and push changes:"
echo "   git add -A && git commit -m 'Switch to Let's Encrypt certificates' && git push"
echo ""
echo "2. Sync ArgoCD applications:"
echo "   kubectl -n argocd get applications -o name | xargs -I {} kubectl -n argocd patch {} --type merge -p '{\"operation\":{\"sync\":{\"revision\":\"HEAD\"}}}'"
echo ""
echo "3. Monitor certificate issuance:"
echo "   watch kubectl get certificates -A"
echo ""
echo "4. Check for any issues:"
echo "   kubectl get challenges -A"
echo "   kubectl logs -n cert-manager deploy/cert-manager"
echo ""
echo "Certificates will be automatically issued once DNS is verified!"