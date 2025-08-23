#!/bin/bash
# Setup NFS server for Plex config directory

echo "Setting up NFS server for Plex config..."

# Install NFS server
echo "Installing NFS server packages..."
sudo apt-get update
sudo apt-get install -y nfs-kernel-server

# Create NFS export for Plex ARM64 config
echo "Configuring NFS exports..."
sudo mkdir -p /storage/docker-volumes/plex_data_arm64
sudo chmod 777 /storage/docker-volumes/plex_data_arm64

# Add export to /etc/exports
# Allow access from local network (adjust subnet as needed)
echo "/storage/docker-volumes/plex_data_arm64 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports

# Export the shares
echo "Exporting NFS shares..."
sudo exportfs -ra

# Start and enable NFS server
echo "Starting NFS server..."
sudo systemctl enable nfs-kernel-server
sudo systemctl restart nfs-kernel-server

# Show status
echo "NFS exports configured:"
sudo exportfs -v

echo "NFS server setup complete!"
echo ""
echo "On Mac Mini, mount with:"
echo "sudo mount -t nfs 192.168.1.227:/storage/docker-volumes/plex_data_arm64 /path/to/mount"