#!/bin/bash
# Fix NFS locking services

echo "Setting up NFS locking services..."

# Install necessary packages
sudo apt-get update
sudo apt-get install -y nfs-common rpcbind

# Start and enable RPC services
echo "Starting RPC services..."
sudo systemctl enable rpcbind
sudo systemctl start rpcbind
sudo systemctl enable nfs-lock
sudo systemctl start nfs-lock
sudo systemctl enable nfs-idmap
sudo systemctl start nfs-idmap

# For systemd systems, might need these instead:
sudo systemctl enable rpc-statd 2>/dev/null
sudo systemctl start rpc-statd 2>/dev/null

# Restart NFS server
echo "Restarting NFS server..."
sudo systemctl restart nfs-kernel-server

# Check status
echo "Checking services..."
sudo systemctl status rpcbind --no-pager | head -5
sudo systemctl status nfs-kernel-server --no-pager | head -5

echo "Done! Try mounting again on Mac Mini"