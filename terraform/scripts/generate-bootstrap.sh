#!/bin/bash
set -euo pipefail

# Clone repository
git clone -b test https://github.com/poiley/rinzler $HOME/rinzler

cd $HOME/rinzler

# Function to read YAML values using yq
read_yaml() {
    local file=$1
    local path=$2
    yq eval "$path" "$file"
}

# Function to read secrets from YAML
read_secrets() {
    local file=$1
    local path=$2
    yq eval "$path" "$file"
}

# Read packages list from bootstrap.yaml
PACKAGES=$(read_yaml "config/bootstrap.yaml" ".bootstrap.packages | join(\" \")")

# Read configuration values from bootstrap.yaml
DOCKGE_STACKS_DIR=$(read_yaml "config/bootstrap.yaml" ".bootstrap.dockge_stacks_dir")
TIMEZONE=$(read_yaml "config/bootstrap.yaml" ".bootstrap.timezone")
PUID=$(read_yaml "config/bootstrap.yaml" ".bootstrap.puid")
PGID=$(read_yaml "config/bootstrap.yaml" ".bootstrap.pgid")
ZFS_POOL=$(read_yaml "config/bootstrap.yaml" ".bootstrap.zfs_pool")
WIREGUARD_ADDRESSES=$(read_yaml "config/bootstrap.yaml" ".bootstrap.wireguard.addresses")

# Read GitHub configuration
GITHUB_OWNER=$(read_yaml "config/runner.yaml" ".runner.github.owner")
REPOSITORY_NAME=$(read_yaml "config/runner.yaml" ".runner.github.repo_name")
GITHUB_SSH_USER=$(read_yaml "config/runner.yaml" ".runner.github.ssh.user")
GITHUB_SERVER_HOST=$(read_yaml "config/runner.yaml" ".runner.github.ssh.server_host")

# Read Pi-hole configuration
PIHOLE_URL=$(read_yaml "config/pihole.yaml" ".pihole.url")

# Read UniFi configuration
UNIFI_CONTROLLER_URL=$(read_yaml "config/unifi.yaml" ".unifi.controller_url")
UNIFI_SITE=$(read_yaml "config/unifi.yaml" ".unifi.site")

# Read secrets (assuming they're in config/secrets/example.yaml)
BASIC_AUTH_HEADER=$(read_secrets "config/secrets/example.yaml" ".bootstrap.basic_auth_header")
WIREGUARD_PRIVATE_KEY=$(read_secrets "config/secrets/example.yaml" ".bootstrap.wireguard.private_key")
PIHOLE_PASSWORD=$(read_secrets "config/secrets/example.yaml" ".pihole.password")
PIHOLE_API_TOKEN=$(read_secrets "config/secrets/example.yaml" ".pihole.api_token")
GITHUB_TOKEN=$(read_secrets "config/secrets/example.yaml" ".github.token")
GITHUB_RUNNER_TOKEN=$(read_secrets "config/secrets/example.yaml" ".github.runner_token")
GITHUB_SSH_PRIVATE_KEY=$(read_secrets "config/secrets/example.yaml" ".github.ssh.private_key")
UNIFI_USERNAME=$(read_secrets "config/secrets/example.yaml" ".unifi.username")
UNIFI_PASSWORD=$(read_secrets "config/secrets/example.yaml" ".unifi.password")
UNIFI_API_KEY=$(read_secrets "config/secrets/example.yaml" ".unifi.api_key")

# Create the modified bootstrap script with hardcoded values
cat > terraform/scripts/bootstrap-init-hardcoded.sh << EOF
#!/bin/bash

# Set non-interactive frontend
export DEBIAN_FRONTEND=noninteractive

# Hardcoded environment variables from config files
export DOCKGE_STACKS_DIR="${DOCKGE_STACKS_DIR}"
export WIREGUARD_PRIVATE_KEY="${WIREGUARD_PRIVATE_KEY}"
export WIREGUARD_ADDRESSES="${WIREGUARD_ADDRESSES}"
export PIHOLE_PASSWORD="${PIHOLE_PASSWORD}"
export PIHOLE_API_TOKEN="${PIHOLE_API_TOKEN}"
export PIHOLE_URL="${PIHOLE_URL}"
export GITHUB_TOKEN="${GITHUB_TOKEN}"
export GITHUB_OWNER="${GITHUB_OWNER}"
export REPOSITORY_NAME="${REPOSITORY_NAME}"
export GITHUB_SSH_USER="${GITHUB_SSH_USER}"
export GITHUB_SERVER_HOST="${GITHUB_SERVER_HOST}"
export GITHUB_SSH_PRIVATE_KEY="${GITHUB_SSH_PRIVATE_KEY}"
export GITHUB_RUNNER_TOKEN="${GITHUB_RUNNER_TOKEN}"
export UNIFI_CONTROLLER_URL="${UNIFI_CONTROLLER_URL}"
export UNIFI_USERNAME="${UNIFI_USERNAME}"
export UNIFI_PASSWORD="${UNIFI_PASSWORD}"
export UNIFI_API_KEY="${UNIFI_API_KEY}"
export UNIFI_SITE="${UNIFI_SITE}"
export BASIC_AUTH_HEADER="${BASIC_AUTH_HEADER}"
export TZ="${TIMEZONE}"
export PUID="${PUID}"
export PGID="${PGID}"
export ZFS_POOL="${ZFS_POOL}"

# Install required packages
apt-get update
# Convert space-separated list to array and install each package
IFS=' ' read -ra PACKAGES <<< "${PACKAGES}"
apt-get install -y "\${PACKAGES[@]}"

EOF

# Append the original bootstrap-init.sh content
cat terraform/scripts/bootstrap-init.sh >> terraform/scripts/bootstrap-init-hardcoded.sh

# Make the generated script executable
chmod +x terraform/scripts/bootstrap-init-hardcoded.sh

echo "Generated bootstrap-init-hardcoded.sh with hardcoded environment variables" 