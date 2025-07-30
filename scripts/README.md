# Scripts Directory

This directory contains automation scripts for server setup and maintenance.

## Installation Scripts

### k3s-install.sh
**Purpose**: Installs K3s with all required configurations for the media server.

**What it does**:
1. Installs K3s v1.28.5 with containerd runtime
2. Configures NVIDIA GPU support
3. Creates all required namespaces
4. Installs NVIDIA device plugin
5. Sets up kubectl access

**Usage**:
```bash
sudo ./k3s-install.sh
```

**Prerequisites**:
- Ubuntu 20.04 or later
- NVIDIA drivers installed (for GPU support)
- Root/sudo access

### nvidia-install.sh
**Purpose**: Installs NVIDIA drivers for GPU transcoding support.

**What it does**:
1. Adds NVIDIA driver repository
2. Installs nvidia-driver-470 (for GTX 750 Ti)
3. Configures Docker runtime for GPU support

**Usage**:
```bash
sudo ./nvidia-install.sh
```

**Note**: Already completed - drivers are installed.

## Diagnostic Scripts

### server-diagnostics.sh
**Purpose**: Comprehensive system analysis tool.

**What it reports**:
- System information (OS, kernel, hostname)
- Hardware specs (CPU, RAM, GPU)
- Storage usage (ZFS pools, disk space)
- Docker status and containers
- Network configuration

**Usage**:
```bash
./server-diagnostics.sh
```

**When to use**:
- Before migration to understand current state
- Troubleshooting issues
- Verifying system resources

### storage-cleanup.sh
**Purpose**: Identifies and cleans up old/unused files.

**What it does**:
1. Finds downloads older than 180 days
2. Identifies large files (>1GB)
3. Locates duplicate files
4. Cleans Docker artifacts

**Usage**:
```bash
# Dry run (shows what would be deleted)
./storage-cleanup.sh

# Actual cleanup
./storage-cleanup.sh --clean
```

**Note**: Already run - freed 886GB of space.

## Script Standards

All scripts follow these conventions:
- Bash shebang: `#!/bin/bash`
- Error handling: `set -euo pipefail`
- Clear output with section headers
- Confirmation prompts for destructive actions
- Detailed comments explaining each step