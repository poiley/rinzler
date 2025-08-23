#!/bin/bash
# Fix NFS for AppleDouble files (._* files)

echo "Updating NFS export to handle AppleDouble files..."

# Update exports with no_acl option
sudo tee /etc/exports << 'EOF'
/storage/docker-volumes/plex_data_arm64 192.168.1.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000,insecure,no_acl)
EOF

# Reload exports
echo "Reloading NFS exports..."
sudo exportfs -ra

# Restart NFS server
echo "Restarting NFS server..."
sudo systemctl restart nfs-kernel-server

echo "NFS updated. The Mac Mini needs to remount the NFS share."
echo ""
echo "On Mac Mini, run:"
echo "sudo umount /Volumes/nfs_plex_config"
echo "sudo mount -t nfs -o vers=3,nolocks,resvport,rw 192.168.1.227:/storage/docker-volumes/plex_data_arm64 /Volumes/nfs_plex_config"