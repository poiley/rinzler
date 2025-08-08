#!/bin/bash

# Script to verify SSL/DNS setup and certificate status

echo "=========================================="
echo "SSL/DNS Setup Verification"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check DNS propagation
echo "1. DNS Status:"
echo "--------------"
for domain in rinzler.me rinzler.cloud; do
    echo -n "Checking $domain nameservers... "
    ns=$(nslookup -type=NS $domain 2>/dev/null | grep "nameserver" | head -1)
    if echo "$ns" | grep -q "cloudflare"; then
        echo -e "${GREEN}✓ Using Cloudflare${NC}"
    else
        echo -e "${RED}✗ Not using Cloudflare yet${NC}"
        echo "  Current: $ns"
        echo "  Expected: max.ns.cloudflare.com / olga.ns.cloudflare.com"
    fi
    
    echo -n "Checking *.$domain resolution... "
    ip=$(nslookup plex.$domain 2>/dev/null | grep "Address" | tail -1 | awk '{print $2}')
    if [ "$ip" = "192.168.1.227" ]; then
        echo -e "${GREEN}✓ Resolves to $ip${NC}"
    elif [ -n "$ip" ]; then
        echo -e "${YELLOW}⚠ Resolves to $ip (should be 192.168.1.227)${NC}"
    else
        echo -e "${RED}✗ Not resolving${NC}"
    fi
done
echo ""

# Check cert-manager
echo "2. cert-manager Status:"
echo "----------------------"
if kubectl get deployment -n cert-manager cert-manager >/dev/null 2>&1; then
    echo -e "${GREEN}✓ cert-manager is deployed${NC}"
    
    # Check if running
    ready=$(kubectl get deployment -n cert-manager cert-manager -o jsonpath='{.status.readyReplicas}')
    if [ "$ready" -gt 0 ]; then
        echo -e "${GREEN}✓ cert-manager is running${NC}"
    else
        echo -e "${RED}✗ cert-manager is not ready${NC}"
    fi
else
    echo -e "${RED}✗ cert-manager not found${NC}"
fi
echo ""

# Check ClusterIssuers
echo "3. Certificate Issuers:"
echo "----------------------"
for issuer in rinzler-ca-issuer letsencrypt-dns-prod; do
    if kubectl get clusterissuer $issuer >/dev/null 2>&1; then
        ready=$(kubectl get clusterissuer $issuer -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
        if [ "$ready" = "True" ]; then
            echo -e "${GREEN}✓ $issuer is ready${NC}"
        else
            echo -e "${YELLOW}⚠ $issuer exists but not ready${NC}"
            kubectl get clusterissuer $issuer -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}'
            echo ""
        fi
    else
        echo -e "${RED}✗ $issuer not found${NC}"
    fi
done
echo ""

# Check certificates
echo "4. Certificate Status:"
echo "---------------------"
cert_count=$(kubectl get certificates -A --no-headers 2>/dev/null | wc -l)
if [ "$cert_count" -gt 0 ]; then
    echo "Found $cert_count certificates:"
    echo ""
    kubectl get certificates -A --no-headers | while read namespace name ready secret age; do
        if [ "$ready" = "True" ]; then
            echo -e "  ${GREEN}✓${NC} $namespace/$name"
        else
            echo -e "  ${RED}✗${NC} $namespace/$name (not ready)"
        fi
    done
else
    echo -e "${YELLOW}No certificates found yet${NC}"
fi
echo ""

# Check for challenges (Let's Encrypt validation)
echo "5. Active Challenges:"
echo "--------------------"
challenge_count=$(kubectl get challenges -A --no-headers 2>/dev/null | wc -l)
if [ "$challenge_count" -gt 0 ]; then
    echo -e "${YELLOW}Found $challenge_count active challenges:${NC}"
    kubectl get challenges -A
    echo ""
    echo "This means Let's Encrypt is trying to validate your domains."
else
    echo -e "${GREEN}No active challenges${NC}"
fi
echo ""

# Summary
echo "=========================================="
echo "Summary:"
echo "=========================================="

all_good=true

# Check if DNS is ready
if nslookup plex.rinzler.me >/dev/null 2>&1; then
    echo -e "${GREEN}✓ DNS is configured${NC}"
else
    echo -e "${RED}✗ DNS not ready - wait for propagation${NC}"
    all_good=false
fi

# Check if cert-manager is ready
if kubectl get deployment -n cert-manager cert-manager >/dev/null 2>&1; then
    echo -e "${GREEN}✓ cert-manager is running${NC}"
else
    echo -e "${RED}✗ cert-manager needs to be deployed${NC}"
    all_good=false
fi

# Check if Let's Encrypt issuer exists
if kubectl get clusterissuer letsencrypt-dns-prod >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Let's Encrypt issuer configured${NC}"
else
    echo -e "${YELLOW}⚠ Let's Encrypt issuer not configured yet${NC}"
    echo "  Run: kubectl apply -f k8s/cert-manager/issuers/letsencrypt-dns-prod.yaml"
    all_good=false
fi

echo ""
if [ "$all_good" = true ]; then
    echo -e "${GREEN}✅ Everything looks good! Ready for Let's Encrypt certificates.${NC}"
    echo ""
    echo "Next step: Run ./scripts/switch-to-letsencrypt.sh"
else
    echo -e "${YELLOW}⚠ Some items need attention. See above for details.${NC}"
fi