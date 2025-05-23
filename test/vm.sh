#!/usr/bin/env bash
set -euo pipefail

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

log_detail() {
    echo -e "    ${CYAN}➤${NC} $1"
}

# Repository Configuration
if [[ -z "${REPO_HOME:-}" ]]; then
    REPO_HOME="$HOME/repos/rinzler"
fi

# Image Configuration
if [[ -z "${DISTRO:-}" ]]; then
    DISTRO="noble"
fi
if [[ -z "${TYPE:-}" ]]; then
    TYPE="server"
fi
if [[ -z "${ARCH:-}" ]]; then
    ARCH="amd64"
fi

BASE_IMG_NAME="ubuntu-${DISTRO}-${TYPE}-cloudimg-${ARCH}.img"
IMG_DIR="/tmp/rinzler"
BASE_IMG="$IMG_DIR/${BASE_IMG_NAME}"
VM_IMG="$IMG_DIR/ubuntu.img"
IMAGE_URL="https://cloud-images.ubuntu.com/${DISTRO}/current/${BASE_IMG_NAME}"

# VM Configuration
SEED_ISO="$IMG_DIR/seed.iso"
USER_DATA_TEMP="$IMG_DIR/user-data"
USER_DATA_REPO="$REPO_HOME/test/user-data"
META_DATA="$IMG_DIR/meta-data"

# Detect host OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -f /proc/version ]] && grep -q Microsoft /proc/version; then
        echo "wsl"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

# Check and install QEMU based on OS
check_qemu() {
    local os=$(detect_os)
    log_step "Checking QEMU installation on $os..."
    
    if command -v qemu-system-x86_64 >/dev/null 2>&1 && command -v qemu-img >/dev/null 2>&1; then
        log_success "QEMU is already installed"
        return 0
    fi
    
    log_warning "QEMU not found, attempting to install..."
    
    case $os in
        "macos")
            if ! command -v brew >/dev/null 2>&1; then
                log_error "Homebrew not found. Please install Homebrew first:"
                log_detail "Visit: https://brew.sh/"
                exit 1
            fi
            log_info "Installing QEMU via Homebrew..."
            brew install qemu
            ;;
        "wsl"|"linux")
            if command -v apt >/dev/null 2>&1; then
                log_info "Installing QEMU via apt..."
                sudo apt update
                sudo apt install -y qemu-system-x86 qemu-utils cloud-image-utils
            elif command -v yum >/dev/null 2>&1; then
                log_info "Installing QEMU via yum..."
                sudo yum install -y qemu-kvm qemu-img cloud-utils
            elif command -v dnf >/dev/null 2>&1; then
                log_info "Installing QEMU via dnf..."
                sudo dnf install -y qemu-kvm qemu-img cloud-utils
            else
                log_error "No supported package manager found (apt/yum/dnf)"
                exit 1
            fi
            ;;
        *)
            log_error "Unsupported operating system: $os"
            exit 1
            ;;
    esac
    
    # Verify installation
    if command -v qemu-system-x86_64 >/dev/null 2>&1 && command -v qemu-img >/dev/null 2>&1; then
        log_success "QEMU installed successfully"
    else
        log_error "QEMU installation failed"
        exit 1
    fi
}

# Check for cloud-localds or alternatives
check_cloud_utils() {
    log_step "Checking cloud-init utilities..."
    
    if command -v cloud-localds >/dev/null 2>&1; then
        log_success "cloud-localds is available"
        return 0
    fi
    
    local os=$(detect_os)
    
    case $os in
        "macos")
            log_warning "cloud-localds not available on macOS"
            log_detail "Will use alternative method to create seed ISO"
            
            # Check for required tools on macOS
            if ! command -v hdiutil >/dev/null 2>&1; then
                log_error "hdiutil not found (required for ISO creation on macOS)"
                exit 1
            fi
            
            log_success "macOS ISO creation tools available"
            return 0
            ;;
        "wsl"|"linux")
            log_warning "cloud-localds not found, attempting to install..."
            if command -v apt >/dev/null 2>&1; then
                sudo apt install -y cloud-image-utils
            elif command -v yum >/dev/null 2>&1; then
                sudo yum install -y cloud-utils
            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y cloud-utils
            else
                log_error "No supported package manager found (apt/yum/dnf)"
                exit 1
            fi
            
            if command -v cloud-localds >/dev/null 2>&1; then
                log_success "cloud-localds installed successfully"
            else
                log_error "cloud-localds installation failed"
                exit 1
            fi
            ;;
        *)
            log_error "Unsupported operating system: $os"
            exit 1
            ;;
    esac
}

# Create images directory
setup_directories() {
    log_step "Setting up directories..."
    if [[ ! -d "$IMG_DIR" ]]; then
        mkdir -p "$IMG_DIR"
        log_success "Created images directory: $IMG_DIR"
    else
        log_detail "Images directory exists: $IMG_DIR"
    fi
}

# Check for base image
check_base_image() {
    log_step "Checking for base Ubuntu image..."
    if [[ ! -f "$BASE_IMG" ]]; then
        log_error "Missing base image at $BASE_IMG"
        log_detail "Download it with:"
        log_detail "wget $IMAGE_URL -O $BASE_IMG"
        exit 1
    else
        log_success "Base image found: $BASE_IMG"
    fi
}

# Clean previous VM state
cleanup_vm_state() {
    log_step "Cleaning previous VM state..."
    local cleaned=false
    
    for file in "$VM_IMG" "$SEED_ISO" "$USER_DATA_TEMP" "$META_DATA"; do
        if [[ -f "$file" ]]; then
            rm -f "$file"
            cleaned=true
        fi
    done
    
    if $cleaned; then
        log_success "Cleaned old VM files"
    else
        log_detail "No previous VM files to clean"
    fi
}

# Create VM disk
create_vm_disk() {
    log_step "Creating VM disk (16GB)..."
    qemu-img create -f qcow2 -b "$BASE_IMG" -F qcow2 "$VM_IMG" 16G >/dev/null 2>&1
    log_success "VM disk created: $VM_IMG"
}

# Create seed ISO using native macOS tools
create_seed_iso_macos() {
    local temp_dir=$(mktemp -d)
    
    # Copy files to temp directory
    cp "$USER_DATA_TEMP" "$temp_dir/user-data"
    cp "$META_DATA" "$temp_dir/meta-data"
    
    # Create ISO using hdiutil
    hdiutil makehybrid -o "$SEED_ISO" -hfs -joliet -iso -default-volume-name cidata "$temp_dir" >/dev/null 2>&1
    
    # Clean up temp directory
    rm -rf "$temp_dir"
}

# Setup cloud-init configuration
setup_cloud_init() {
    log_step "Setting up cloud-init configuration..."
    
    # Copy user-data from repo to temp location
    if [[ -f "$USER_DATA_REPO" ]]; then
        cp "$USER_DATA_REPO" "$USER_DATA_TEMP"
        log_success "Copied user-data from repository to temp location"
    else
        log_warning "Repository user-data not found at $USER_DATA_REPO"
        log_detail "Creating empty user-data file"
        touch "$USER_DATA_TEMP"
    fi
    
    # Create meta-data (empty file is sufficient for basic setup)
    cat > "$META_DATA" << EOF
instance-id: ubuntu-vm-$(date +%s)
local-hostname: ubuntu-vm
EOF
    log_success "Created meta-data file"
    
    # Create seed ISO based on OS
    local os=$(detect_os)
    if [[ "$os" == "macos" ]]; then
        create_seed_iso_macos
        log_success "Generated cloud-init seed ISO (macOS method)"
    else
        cloud-localds "$SEED_ISO" "$USER_DATA_TEMP" "$META_DATA" >/dev/null 2>&1
        log_success "Generated cloud-init seed ISO"
    fi
}

# Launch VM
launch_vm() {
    log_step "Starting Ubuntu VM..."
    log_detail "VM Specs: 8GB RAM, 4 CPU cores, 16GB disk"
    log_detail "SSH access: ssh poile@localhost -p 2222 (password: password)"
    log_detail "Console: Auto-login as poile on ttyS0"
    log_detail "Press Ctrl+A then X to quit QEMU"
    echo
    log_info "VM is starting..."
    
    qemu-system-x86_64 \
        -m 8192 -smp 4 \
        -drive file="$VM_IMG",format=qcow2,if=virtio \
        -cdrom "$SEED_ISO" \
        -net nic -net user,hostfwd=tcp::2222-:22 \
        -nographic
}

# Main execution
main() {
    echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║        Ubuntu VM Launcher            ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
    echo
    
    local os=$(detect_os)
    log_info "Detected OS: $os"
    
    check_qemu
    check_cloud_utils
    setup_directories
    check_base_image
    cleanup_vm_state
    create_vm_disk
    setup_cloud_init
    launch_vm
}

# Run main function
main "$@"