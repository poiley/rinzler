#!/bin/bash

# Vault Secrets Setup Script
# This script populates Vault with all the secrets needed for the media server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Check if vault CLI is available
if ! command -v vault &> /dev/null; then
    print_error "vault CLI is not installed. Please install it first."
    print_status "Install with: curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -"
    print_status "sudo apt-add-repository \"deb [arch=amd64] https://apt.releases.hashicorp.com \$(lsb_release -cs) main\""
    print_status "sudo apt-get update && sudo apt-get install vault"
    exit 1
fi

# Set Vault address
export VAULT_ADDR="http://localhost:8200"

# Port forward to Vault if needed
print_status "Setting up port forward to Vault..."
kubectl port-forward -n vault-system svc/vault 8200:8200 &
PORT_FORWARD_PID=$!
sleep 5

# Function to cleanup port forward on exit
cleanup() {
    if [ ! -z "$PORT_FORWARD_PID" ]; then
        kill $PORT_FORWARD_PID 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Check if Vault is accessible
if ! vault status &> /dev/null; then
    print_error "Cannot connect to Vault. Make sure it's running in your cluster."
    exit 1
fi

print_success "Connected to Vault"

# Function to prompt for secret input
prompt_secret() {
    local prompt="$1"
    local secret_var="$2"
    echo -n "$prompt: "
    read -s $secret_var
    echo
}

# Function to store secret in Vault
store_secret() {
    local path="$1"
    local key="$2"
    local value="$3"
    
    vault kv put secret/$path $key="$value"
    print_success "Stored secret at secret/$path"
}

print_status "🔐 Setting up media server secrets in Vault"
echo

# VPN Secrets
print_status "📡 VPN Configuration"
prompt_secret "Enter your WireGuard private key" WIREGUARD_PRIVATE_KEY
prompt_secret "Enter your WireGuard addresses (e.g., 10.0.0.1/24)" WIREGUARD_ADDRESSES

store_secret "vpn/wireguard" "private_key" "$WIREGUARD_PRIVATE_KEY"
store_secret "vpn/wireguard" "addresses" "$WIREGUARD_ADDRESSES"

# DNS Secrets
print_status "🌐 DNS Configuration"
prompt_secret "Enter Pi-hole web admin password" PIHOLE_PASSWORD

store_secret "dns/pihole" "web_password" "$PIHOLE_PASSWORD"

# Media Server Secrets
print_status "📺 Media Server Configuration"
prompt_secret "Enter Grafana admin password" GRAFANA_PASSWORD
prompt_secret "Enter Prometheus admin password (optional)" PROMETHEUS_PASSWORD

store_secret "media-server/grafana" "admin_password" "$GRAFANA_PASSWORD"
if [ ! -z "$PROMETHEUS_PASSWORD" ]; then
    store_secret "media-server/prometheus" "admin_password" "$PROMETHEUS_PASSWORD"
fi

# Database passwords (if needed)
print_status "🗄️ Database Configuration (optional)"
echo "Do you want to set up database passwords? (y/n)"
read -r setup_db
if [[ $setup_db =~ ^[Yy]$ ]]; then
    prompt_secret "Enter database root password" DB_ROOT_PASSWORD
    prompt_secret "Enter database user password" DB_USER_PASSWORD
    
    store_secret "media-server/database" "root_password" "$DB_ROOT_PASSWORD"
    store_secret "media-server/database" "user_password" "$DB_USER_PASSWORD"
fi

# API Keys
print_status "🔑 API Keys (optional)"
echo "Do you want to set up API keys? (y/n)"
read -r setup_apis
if [[ $setup_apis =~ ^[Yy]$ ]]; then
    prompt_secret "Enter TMDB API key (for Radarr/Sonarr)" TMDB_API_KEY
    prompt_secret "Enter Pushover API key (for notifications)" PUSHOVER_API_KEY
    
    if [ ! -z "$TMDB_API_KEY" ]; then
        store_secret "media-server/apis" "tmdb_key" "$TMDB_API_KEY"
    fi
    if [ ! -z "$PUSHOVER_API_KEY" ]; then
        store_secret "media-server/apis" "pushover_key" "$PUSHOVER_API_KEY"
    fi
fi

print_success "🎉 All secrets have been stored in Vault!"
echo
print_status "📋 Summary of stored secrets:"
echo "  • VPN WireGuard credentials"
echo "  • Pi-hole admin password"
echo "  • Grafana admin password"
if [ ! -z "$PROMETHEUS_PASSWORD" ]; then
    echo "  • Prometheus admin password"
fi
if [[ $setup_db =~ ^[Yy]$ ]]; then
    echo "  • Database passwords"
fi
if [[ $setup_apis =~ ^[Yy]$ ]]; then
    echo "  • API keys"
fi

echo
print_status "🔄 Next steps:"
echo "  1. Deploy the External Secrets Operator to sync these secrets"
echo "  2. Update your Kubernetes manifests to use the synced secrets"
echo "  3. Remove any hardcoded secrets from your YAML files"
echo
print_status "🔍 To view secrets in Vault UI: http://localhost:8200/ui"
print_warning "Remember to securely store your Vault unseal keys!"

# Create a reference file for the secrets structure
cat > vault-secrets-reference.md << EOF
# Vault Secrets Reference

## Secret Paths

### VPN Configuration
- \`secret/vpn/wireguard\`
  - \`private_key\`: WireGuard private key
  - \`addresses\`: WireGuard IP addresses

### DNS Configuration  
- \`secret/dns/pihole\`
  - \`web_password\`: Pi-hole web admin password

### Media Server
- \`secret/media-server/grafana\`
  - \`admin_password\`: Grafana admin password
- \`secret/media-server/prometheus\`
  - \`admin_password\`: Prometheus admin password
- \`secret/media-server/database\`
  - \`root_password\`: Database root password
  - \`user_password\`: Database user password
- \`secret/media-server/apis\`
  - \`tmdb_key\`: TMDB API key
  - \`pushover_key\`: Pushover API key

## Usage in Kubernetes

These secrets are automatically synced to Kubernetes secrets via External Secrets Operator:
- \`vpn-config\` secret in \`media-server\` namespace
- \`pihole-config\` secret in \`networking\` namespace
- \`grafana-config\` secret in \`monitoring\` namespace

EOF

print_success "Created vault-secrets-reference.md for future reference" 