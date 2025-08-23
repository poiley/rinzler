#!/bin/bash
# Reload NFS exports and check status

echo "Reloading NFS exports..."
sudo exportfs -ra

echo -e "\nActive exports:"
sudo exportfs -v

echo -e "\nChecking NFS server status:"
sudo systemctl status nfs-kernel-server --no-pager | head -10

echo -e "\nTesting export locally:"
sudo showmount -e localhost

echo -e "\nIf Mac still can't mount, try on Mac:"
echo "sudo mount -t nfs -o vers=3,nolocks,resvport,rw 192.168.1.227:/storage/docker-volumes/plex_data_arm64 /Volumes/nfs_plex_config"