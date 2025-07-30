#!/bin/bash

# Server Diagnostics Script for K3s Migration Planning
# Run this on your Ubuntu server and share the output

echo "=== Server Diagnostics Report ==="
echo "Generated on: $(date)"
echo ""

echo "=== System Information ==="
echo "Hostname: $(hostname)"
echo "OS: $(lsb_release -d | cut -f2)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo ""

echo "=== Hardware Information ==="
echo "CPU Info:"
lscpu | grep -E "Model name:|CPU\(s\):|Thread\(s\) per core:|Core\(s\) per socket:"
echo ""
echo "Memory:"
free -h
echo ""
echo "GPU Info:"
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv
else
    echo "NVIDIA GPU not detected or nvidia-smi not installed"
fi
echo ""

echo "=== Storage Information ==="
echo "Disk Usage:"
df -h | grep -E "^/|Filesystem"
echo ""
echo "ZFS Pools:"
if command -v zpool &> /dev/null; then
    zpool list
    echo ""
    echo "ZFS Pool Status:"
    zpool status -v
    echo ""
    echo "ZFS Datasets:"
    zfs list -o name,used,avail,mountpoint
else
    echo "ZFS not installed"
fi
echo ""

echo "=== Docker Information ==="
echo "Docker Version:"
docker version --format 'Server Version: {{.Server.Version}}'
echo ""
echo "Docker Info:"
docker info --format 'Containers: {{.Containers}}
Running: {{.ContainersRunning}}
Storage Driver: {{.Driver}}
Docker Root Dir: {{.DockerRootDir}}'
echo ""
echo "Docker Networks:"
docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
echo ""
echo "Docker Volumes (named only):"
docker volume ls --format "table {{.Name}}\t{{.Driver}}" | grep -v "^[a-f0-9]\{64\}"
echo ""

echo "=== Network Information ==="
echo "Network Interfaces:"
ip -brief addr show
echo ""
echo "Routing Table:"
ip route show
echo ""
echo "Listening Ports:"
sudo ss -tlnp | grep LISTEN
echo ""

echo "=== Current Container Analysis ==="
echo "Running Containers:"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
echo ""
echo "Container Resource Usage:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
echo ""

echo "=== Special Requirements Check ==="
echo "Containers using Host Network:"
docker ps --format "{{.Names}}" | xargs -I {} sh -c 'docker inspect {} | grep -q "\"NetworkMode\": \"host\"" && echo {}'
echo ""
echo "Containers with Privileged Mode:"
docker ps --format "{{.Names}}" | xargs -I {} sh -c 'docker inspect {} | grep -q "\"Privileged\": true" && echo {}'
echo ""
echo "Containers with GPU Access:"
docker ps --format "{{.Names}}" | xargs -I {} sh -c 'docker inspect {} | grep -q "nvidia" && echo {}'
echo ""

echo "=== File Permissions Check ==="
echo "Storage directory permissions:"
ls -la /storage/ 2>/dev/null || echo "/storage directory not found"
echo ""

echo "=== Additional Checks ==="
echo "Checking for existing k3s/k8s:"
if command -v kubectl &> /dev/null; then
    echo "kubectl found: $(kubectl version --client --short)"
else
    echo "kubectl not found"
fi
if command -v k3s &> /dev/null; then
    echo "k3s found: $(k3s --version)"
else
    echo "k3s not found"
fi
echo ""

echo "=== End of Diagnostics Report ==="