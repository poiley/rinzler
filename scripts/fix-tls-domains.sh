#!/bin/bash
set -e

# Fix ingresses to only request Let's Encrypt certificates for valid domains
# Keep .grid in rules but not in TLS section

echo "Fixing TLS domains for Let's Encrypt..."

for file in $(find k8s -name "ingress.yaml" -o -name "*-ingress.yaml" 2>/dev/null); do
    if grep -q "kind: Ingress" "$file"; then
        service_name=$(grep "name:" "$file" | head -1 | awk '{print $2}')
        echo "Processing $service_name..."
        
        # Remove .grid from TLS hosts but keep in rules
        # This allows .grid to work with self-signed while .me and .cloud get Let's Encrypt
        sed -i '/.rinzler.grid$/d' "$file"
        
        echo "  ✓ Removed .grid from TLS hosts"
    fi
done

echo ""
echo "Done! Now only .me and .cloud domains will get Let's Encrypt certificates."
echo ".grid will continue to work with self-signed certificates."