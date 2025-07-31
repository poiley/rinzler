#!/bin/bash
# Generate Kubernetes secrets from environment variables
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Kubernetes Secrets Generator ===${NC}"

# Check for required tools
if ! command -v envsubst &> /dev/null; then
    echo -e "${RED}Error: envsubst not found. Install gettext package.${NC}"
    echo "Ubuntu/Debian: sudo apt-get install gettext"
    echo "macOS: brew install gettext"
    exit 1
fi

# Check for secret file
if [ ! -f ".env.secrets" ]; then
    echo -e "${RED}Error: .env.secrets file not found!${NC}"
    echo -e "${YELLOW}Creating from example...${NC}"
    
    if [ -f ".env.secrets.example" ]; then
        cp .env.secrets.example .env.secrets
        echo -e "${GREEN}Created .env.secrets from example${NC}"
        echo -e "${YELLOW}Please edit .env.secrets with your actual values and run this script again${NC}"
        exit 1
    else
        echo -e "${RED}No .env.secrets.example found!${NC}"
        exit 1
    fi
fi

# Source the secrets
echo "Loading secrets from .env.secrets..."
set -a  # Export all variables
source .env.secrets
set +a

# Validate required variables
required_vars=(
    "PIHOLE_PASSWORD"
    "MULLVAD_PRIVATE_KEY"
    "MULLVAD_IP"
    "DUCKDNS_TOKEN"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if [ -z "${!var:-}" ] || [ "${!var}" = "change-me"* ] || [ "${!var}" = "your-"* ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -ne 0 ]; then
    echo -e "${RED}Error: The following variables need to be set in .env.secret:${NC}"
    printf '%s\n' "${missing_vars[@]}"
    exit 1
fi

# Create output directory
mkdir -p k8s-generated/secrets

# Generate individual secret files
echo -e "${YELLOW}Generating secret manifests...${NC}"

# Pi-hole Secret
cat > k8s-generated/secrets/pihole-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: pihole-secrets
  namespace: network-services
type: Opaque
stringData:
  webpassword: "${PIHOLE_PASSWORD}"
EOF
echo "✓ Generated pihole-secret.yaml"

# Mullvad VPN Secret
cat > k8s-generated/secrets/mullvad-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: mullvad-secrets
  namespace: download
type: Opaque
stringData:
  private-key: "${MULLVAD_PRIVATE_KEY}"
  addresses: "${MULLVAD_IP}"
EOF
echo "✓ Generated mullvad-secret.yaml"

# DuckDNS Secret
cat > k8s-generated/secrets/duckdns-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: duckdns-secrets
  namespace: infrastructure
type: Opaque
stringData:
  token: "${DUCKDNS_TOKEN}"
  subdomain: "${DUCKDNS_SUBDOMAIN:-poile}"
EOF
echo "✓ Generated duckdns-secret.yaml"

# Samba Secret (if configured)
if [ ! -z "${SAMBA_USER:-}" ] && [ ! -z "${SAMBA_PASS:-}" ]; then
    cat > k8s-generated/secrets/samba-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: samba-secrets
  namespace: network-services
type: Opaque
stringData:
  share-config: "${SAMBA_USER};${SAMBA_PASS}"
EOF
    echo "✓ Generated samba-secret.yaml"
fi

# Plex Secret (if configured)
if [ ! -z "${PLEX_USER:-}" ]; then
    cat > k8s-generated/secrets/plex-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: plex-secrets
  namespace: media
type: Opaque
stringData:
  username: "${PLEX_USER}"
  advertise-ip: "${PLEX_ADVERTISE_IP:-}"
EOF
    echo "✓ Generated plex-secret.yaml"
fi

# Grafana MCP Secret (if configured)
if [ ! -z "${GRAFANA_API_KEY:-}" ]; then
    cat > k8s-generated/secrets/grafana-mcp-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: grafana-mcp-secret
  namespace: mcp-servers
type: Opaque
stringData:
  api-key: "${GRAFANA_API_KEY}"
EOF
    echo "✓ Generated grafana-mcp-secret.yaml"
fi

echo -e "${GREEN}=== Secret generation complete! ===${NC}"
echo ""
echo "Generated secrets in: k8s-generated/secrets/"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review generated files:"
echo "   ls -la k8s-generated/secrets/"
echo ""
echo "2. Apply secrets to cluster:"
echo "   kubectl apply -f k8s-generated/secrets/"
echo ""
echo "3. Update deployments to use secrets (see SECRETS-MANAGEMENT.md)"
echo ""
echo -e "${RED}Remember: Never commit k8s-generated/ or .env.secret to Git!${NC}"