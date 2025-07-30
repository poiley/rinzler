#!/bin/bash

# NVIDIA Driver Installation for Ubuntu 20.04
# For GTX 750 Ti (GM107)

echo "=== NVIDIA Driver Installation Script ==="
echo "GPU Detected: NVIDIA GeForce GTX 750 Ti"
echo ""

echo "=== Installing ubuntu-drivers-common package ==="
echo "sudo apt update"
echo "sudo apt install -y ubuntu-drivers-common"
echo ""

echo "=== Option 1: Using ubuntu-drivers (after installing package) ==="
echo "# Check available drivers:"
echo "ubuntu-drivers list"
echo ""
echo "# Install recommended:"
echo "sudo ubuntu-drivers autoinstall"
echo ""

echo "=== Option 2: Direct driver installation ==="
echo "# The GTX 750 Ti is supported by driver 470 or 390"
echo "# Install driver 470 (recommended for GTX 750 Ti):"
echo "sudo apt update"
echo "sudo apt install -y nvidia-driver-470"
echo ""

echo "=== Option 3: Using NVIDIA's official installer ==="
echo "# Add graphics drivers PPA:"
echo "sudo add-apt-repository ppa:graphics-drivers/ppa"
echo "sudo apt update"
echo "sudo apt install -y nvidia-driver-470"
echo ""

echo "=== After driver installation: ==="
echo "# 1. Reboot the system"
echo "sudo reboot"
echo ""
echo "# 2. Verify installation after reboot:"
echo "nvidia-smi"
echo ""
echo "# 3. Since nvidia-container-runtime is already configured,"
echo "# just verify it works:"
echo "docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi"
echo ""

echo "=== Current Docker daemon.json status ==="
if [ -f /etc/docker/daemon.json ]; then
    echo "✓ Docker already configured for NVIDIA runtime:"
    cat /etc/docker/daemon.json | grep -A3 nvidia
else
    echo "✗ No Docker daemon.json found"
fi
echo ""

echo "=== Quick installation commands (copy and run): ==="
echo "# Install ubuntu-drivers-common first:"
echo "sudo apt update && sudo apt install -y ubuntu-drivers-common"
echo ""
echo "# Then install NVIDIA driver:"
echo "sudo ubuntu-drivers autoinstall"
echo "# OR directly:"
echo "sudo apt install -y nvidia-driver-470"