#!/bin/bash
# Setup NFSv4 which handles metadata differently

echo "Setting up NFSv4 export for Plex..."

# Update exports for NFSv4
sudo tee /etc/exports << 'EOF'
/storage/docker-volumes/plex_data_arm64 192.168.1.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000,fsid=0)
EOF

# Enable NFSv4 only
echo "Configuring NFSv4..."
sudo tee -a /etc/default/nfs-kernel-server << 'EOF'
RPCNFSDARGS="-N 2 -N 3"
RPCMOUNTDOPTS="--manage-gids"
EOF

# Reload exports
sudo exportfs -ra
sudo systemctl restart nfs-kernel-server

echo "NFSv4 configured. On Mac Mini, mount with:"
echo "sudo mount -t nfs -o vers=4 192.168.1.227:/storage/docker-volumes/plex_data_arm64 /Volumes/nfs_plex_config"