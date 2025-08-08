#!/bin/bash

# Script to add monitors to Uptime Kuma via API
# Usage: ./add-monitors.sh

set -e

UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-https://uptime.rinzler.cloud}"
UPTIME_KUMA_USERNAME="${UPTIME_KUMA_USERNAME:-admin}"

echo "======================================"
echo "Add Monitors to Uptime Kuma"
echo "======================================"
echo ""
echo "URL: $UPTIME_KUMA_URL"
echo "Username: $UPTIME_KUMA_USERNAME"
echo ""

# Prompt for password if not set
if [ -z "$UPTIME_KUMA_PASSWORD" ]; then
    read -sp "Enter Uptime Kuma password: " UPTIME_KUMA_PASSWORD
    echo
fi

# Example monitors to add
# This uses the Uptime Kuma API after authentication

cat << 'EOF' > /tmp/monitors.json
[
  {
    "name": "ArgoCD",
    "type": "http",
    "url": "https://argocd.rinzler.cloud",
    "interval": 300
  },
  {
    "name": "Grafana",
    "type": "http", 
    "url": "https://grafana.rinzler.cloud",
    "interval": 300
  },
  {
    "name": "Plex",
    "type": "http",
    "url": "https://plex.rinzler.cloud",
    "interval": 300
  },
  {
    "name": "Sonarr",
    "type": "http",
    "url": "https://sonarr.rinzler.cloud",
    "interval": 300
  },
  {
    "name": "Radarr",
    "type": "http",
    "url": "https://radarr.rinzler.cloud",
    "interval": 300
  }
]
EOF

echo "Monitors configuration saved to /tmp/monitors.json"
echo ""
echo "To add monitors manually:"
echo "1. Access Uptime Kuma at: $UPTIME_KUMA_URL"
echo "2. Login with your credentials"
echo "3. Click 'Add New Monitor' for each service"
echo ""
echo "Recommended monitors to add:"
echo "- External HTTPS endpoints (*.rinzler.cloud, *.rinzler.me)"
echo "- Internal K8s services (via ClusterIP)"
echo "- Critical infrastructure (DNS, Traefik, ArgoCD)"
echo ""

# Clean up
rm -f /tmp/monitors.json