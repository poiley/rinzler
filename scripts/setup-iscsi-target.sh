#!/bin/bash
# Setup iSCSI target for Plex config storage

echo "Setting up iSCSI target for Plex config..."

# Install iSCSI target
echo "Installing targetcli-fb..."
sudo apt-get update
sudo apt-get install -y targetcli-fb

# Create a backing file for the iSCSI LUN (20GB for Plex config)
echo "Creating backing storage file..."
sudo mkdir -p /storage/iscsi
sudo dd if=/dev/zero of=/storage/iscsi/plex-config.img bs=1M count=20480 status=progress

# Configure iSCSI target
echo "Configuring iSCSI target..."
sudo targetcli << 'EOF'
cd /backstores/fileio
create plex-config /storage/iscsi/plex-config.img 20G
cd /iscsi
create iqn.2025-08.cloud.rinzler:plex-config
cd iqn.2025-08.cloud.rinzler:plex-config/tpg1/luns
create /backstores/fileio/plex-config
cd ../acls
create iqn.2025-08.com.apple:mini
cd iqn.2025-08.com.apple:mini
set auth userid=plex
set auth password=PlexConfig2025
cd /
saveconfig
exit
EOF

# Enable and start iSCSI target service
echo "Starting iSCSI target service..."
sudo systemctl enable target
sudo systemctl restart target

# Open firewall port if needed
echo "Configuring firewall..."
sudo ufw allow 3260/tcp 2>/dev/null || true

echo "iSCSI target setup complete!"
echo ""
echo "On Mac Mini, connect with:"
echo "  Target: iqn.2025-08.cloud.rinzler:plex-config"
echo "  Portal: 192.168.1.227:3260"
echo "  Initiator: iqn.2025-08.com.apple:mini"
echo "  User: plex"
echo "  Password: PlexConfig2025"