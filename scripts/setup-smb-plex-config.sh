#!/bin/bash
# Setup SMB share for Plex config

echo "Setting up SMB share for Plex config..."

# Add SMB share configuration
sudo tee -a /etc/samba/smb.conf << 'SMBCONF'

[plex_config_arm64]
   path = /storage/docker-volumes/plex_data_arm64
   browseable = yes
   read only = no
   guest ok = no
   valid users = poile
   create mask = 0755
   directory mask = 0755
   force user = poile
   force group = poile
   # Important for macOS compatibility
   vfs objects = catia fruit streams_xattr
   fruit:metadata = stream
   fruit:model = MacSamba
   fruit:posix_rename = yes
   fruit:veto_appledouble = no
   fruit:wipe_intentionally_left_blank_rfork = yes
   fruit:delete_empty_adfiles = yes
SMBCONF

# Reload Samba
echo "Reloading Samba configuration..."
sudo systemctl reload smbd

echo "SMB share configured!"
echo ""
echo "On Mac Mini, mount with:"
echo "sudo mount -t smbfs //poile@192.168.1.227/plex_config_arm64 /Volumes/smb_plex_config"
