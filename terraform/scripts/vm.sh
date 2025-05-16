#!/usr/bin/env bash
set -euo pipefail

IMG_DIR="$HOME/images"
BASE_IMG="$IMG_DIR/ubuntu-base.img"
VM_IMG="$IMG_DIR/ubuntu.img"
SEED_ISO="$IMG_DIR/seed.iso"
USER_DATA="$IMG_DIR/user-data"
META_DATA="$IMG_DIR/meta-data"
ARCH="amd64"
DISTRO="noble"
TYPE="server"
IMAGE_URL="https://cloud-images.ubuntu.com/${DISTRO}/current/${DISTRO}-${TYPE}-cloudimg-${ARCH}.img"

# Check for base image
if [[ ! -f "$BASE_IMG" ]]; then
  echo "Missing base image at $BASE_IMG. Download it first:"
  echo "wget $IMAGE_URL -O $BASE_IMG"
  exit 1
fi

# Clean previous VM state
echo "[*] Cleaning old VM state..."
rm -f "$VM_IMG" "$SEED_ISO" "$USER_DATA" "$META_DATA"

# Create a new overlay image from the base image with 16 GB virtual size
echo "[*] Creating new VM disk from base image (16 GB)..."
qemu-img create -f qcow2 -b "$BASE_IMG" -F qcow2 "$VM_IMG" 16G

touch "$META_DATA"
cloud-localds "$SEED_ISO" "$USER_DATA" "$META_DATA"

# Launch the VM
echo "[*] Starting VM..."
echo "    ➤ SSH to:    ssh poile@localhost -p 2222 (password: poile)"
echo "    ➤ Console:   autologin to poile on ttyS0"
qemu-system-x86_64 \
  -m 8192 -smp 4 \
  -drive file="$VM_IMG",format=qcow2,if=virtio \
  -cdrom "$SEED_ISO" \
  -net nic -net user,hostfwd=tcp::2222-:22 \
  -nographic