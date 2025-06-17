#!/bin/bash

# Docker Cleanup Script
# This script safely removes Docker containers, images, and networks after migrating to Kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to confirm action
confirm_action() {
    local message="$1"
    echo -e "${YELLOW}⚠️  $message${NC}"
    echo -n "Are you sure? (yes/no): "
    read -r confirmation
    if [[ ! $confirmation =~ ^[Yy][Ee][Ss]$ ]]; then
        print_status "Skipping..."
        return 1
    fi
    return 0
}

# Function to backup Docker Compose files
backup_compose_files() {
    print_status "📁 Backing up Docker Compose files..."
    
    if [ -d "compose" ]; then
        BACKUP_DIR="docker-backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        
        cp -r compose "$BACKUP_DIR/"
        if [ -f ".env" ]; then
            cp .env "$BACKUP_DIR/"
        fi
        if [ -f "docker-compose.yml" ]; then
            cp docker-compose.yml "$BACKUP_DIR/"
        fi
        
        print_success "Backed up Docker files to $BACKUP_DIR"
        echo "$BACKUP_DIR" > .docker-backup-location
    else
        print_warning "No compose directory found"
    fi
}

# Function to stop and remove containers
cleanup_containers() {
    print_status "🛑 Stopping and removing Docker containers..."
    
    # Get list of running containers
    RUNNING_CONTAINERS=$(docker ps -q)
    if [ ! -z "$RUNNING_CONTAINERS" ]; then
        print_status "Stopping running containers..."
        docker stop $RUNNING_CONTAINERS
        print_success "Stopped all running containers"
    fi
    
    # Get list of all containers
    ALL_CONTAINERS=$(docker ps -aq)
    if [ ! -z "$ALL_CONTAINERS" ]; then
        if confirm_action "This will remove ALL Docker containers"; then
            docker rm $ALL_CONTAINERS
            print_success "Removed all containers"
        fi
    else
        print_status "No containers to remove"
    fi
}

# Function to remove Docker networks
cleanup_networks() {
    print_status "🌐 Cleaning up Docker networks..."
    
    # Remove custom networks (keep default ones)
    CUSTOM_NETWORKS=$(docker network ls --filter type=custom -q)
    if [ ! -z "$CUSTOM_NETWORKS" ]; then
        if confirm_action "This will remove custom Docker networks"; then
            docker network rm $CUSTOM_NETWORKS 2>/dev/null || true
            print_success "Removed custom networks"
        fi
    else
        print_status "No custom networks to remove"
    fi
}

# Function to remove Docker volumes
cleanup_volumes() {
    print_status "💾 Cleaning up Docker volumes..."
    
    # List all volumes
    ALL_VOLUMES=$(docker volume ls -q)
    if [ ! -z "$ALL_VOLUMES" ]; then
        print_warning "Found Docker volumes:"
        docker volume ls
        echo
        print_warning "⚠️  IMPORTANT: This will delete ALL Docker volumes!"
        print_warning "⚠️  Make sure your data is safely backed up to /storage/ directory"
        print_warning "⚠️  Your Kubernetes setup should be using the same /storage/ paths"
        echo
        
        if confirm_action "This will PERMANENTLY DELETE all Docker volumes"; then
            docker volume rm $ALL_VOLUMES 2>/dev/null || true
            print_success "Removed all volumes"
        fi
    else
        print_status "No volumes to remove"
    fi
}

# Function to remove Docker images
cleanup_images() {
    print_status "🖼️  Cleaning up Docker images..."
    
    # Remove dangling images first
    DANGLING_IMAGES=$(docker images -f "dangling=true" -q)
    if [ ! -z "$DANGLING_IMAGES" ]; then
        print_status "Removing dangling images..."
        docker rmi $DANGLING_IMAGES
        print_success "Removed dangling images"
    fi
    
    # Remove all images
    ALL_IMAGES=$(docker images -q)
    if [ ! -z "$ALL_IMAGES" ]; then
        if confirm_action "This will remove ALL Docker images (they can be re-downloaded if needed)"; then
            docker rmi $ALL_IMAGES -f 2>/dev/null || true
            print_success "Removed all images"
        fi
    else
        print_status "No images to remove"
    fi
}

# Function to clean up Docker system
cleanup_system() {
    print_status "🧹 Running Docker system cleanup..."
    
    if confirm_action "This will run 'docker system prune -a' to clean up everything"; then
        docker system prune -a -f
        print_success "System cleanup completed"
    fi
}

# Function to remove Docker Compose
remove_docker_compose() {
    print_status "🗑️  Removing Docker Compose..."
    
    if command -v docker-compose &> /dev/null; then
        if confirm_action "This will remove Docker Compose binary"; then
            sudo rm -f /usr/local/bin/docker-compose
            print_success "Removed Docker Compose"
        fi
    else
        print_status "Docker Compose not found"
    fi
}

# Function to optionally remove Docker entirely
remove_docker() {
    print_status "🐳 Docker Engine Removal (Optional)"
    print_warning "This will completely remove Docker from your system"
    print_warning "Only do this if you're sure you won't need Docker anymore"
    echo
    
    if confirm_action "Do you want to completely remove Docker Engine?"; then
        print_status "Stopping Docker service..."
        sudo systemctl stop docker
        sudo systemctl disable docker
        
        print_status "Removing Docker packages..."
        sudo apt-get purge -y docker-engine docker docker.io docker-ce docker-ce-cli containerd.io
        sudo apt-get autoremove -y
        
        print_status "Removing Docker directories..."
        sudo rm -rf /var/lib/docker
        sudo rm -rf /etc/docker
        sudo rm -rf /var/run/docker.sock
        
        print_success "Docker completely removed"
    else
        print_status "Keeping Docker installed"
    fi
}

# Function to verify Kubernetes is working
verify_kubernetes() {
    print_status "✅ Verifying Kubernetes deployment..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please ensure Kubernetes is properly set up."
        return 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        return 1
    fi
    
    print_status "Checking media server pods..."
    kubectl get pods -n media-server 2>/dev/null || {
        print_warning "Media server namespace not found. Make sure you've deployed the Kubernetes manifests."
        return 1
    }
    
    print_success "Kubernetes cluster is accessible"
    return 0
}

# Function to create cleanup report
create_cleanup_report() {
    local report_file="docker-cleanup-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
Docker Cleanup Report
Generated: $(date)

=== Pre-Cleanup Status ===
Docker Version: $(docker --version 2>/dev/null || echo "Not available")
Docker Compose Version: $(docker-compose --version 2>/dev/null || echo "Not available")

=== Cleanup Actions Performed ===
- Containers: $([ "$CLEANUP_CONTAINERS" = "true" ] && echo "Removed" || echo "Skipped")
- Networks: $([ "$CLEANUP_NETWORKS" = "true" ] && echo "Removed" || echo "Skipped")  
- Volumes: $([ "$CLEANUP_VOLUMES" = "true" ] && echo "Removed" || echo "Skipped")
- Images: $([ "$CLEANUP_IMAGES" = "true" ] && echo "Removed" || echo "Skipped")
- System Prune: $([ "$CLEANUP_SYSTEM" = "true" ] && echo "Performed" || echo "Skipped")
- Docker Compose: $([ "$REMOVE_COMPOSE" = "true" ] && echo "Removed" || echo "Kept")
- Docker Engine: $([ "$REMOVE_DOCKER" = "true" ] && echo "Removed" || echo "Kept")

=== Backup Location ===
$([ -f ".docker-backup-location" ] && echo "Docker files backed up to: $(cat .docker-backup-location)" || echo "No backup created")

=== Kubernetes Status ===
$(kubectl get pods --all-namespaces 2>/dev/null | head -10 || echo "Kubernetes not accessible")

=== Next Steps ===
1. Verify all services are running in Kubernetes
2. Update any remaining references to Docker
3. Monitor Kubernetes cluster health
4. Set up regular backups for Kubernetes persistent volumes

EOF

    print_success "Created cleanup report: $report_file"
}

# Main execution
main() {
    echo "🧹 Docker to Kubernetes Migration Cleanup"
    echo "=========================================="
    echo
    
    print_warning "This script will help clean up Docker after migrating to Kubernetes"
    print_warning "Make sure your Kubernetes deployment is working before proceeding!"
    echo
    
    # Verify Kubernetes first
    if ! verify_kubernetes; then
        print_error "Please ensure Kubernetes is working before cleaning up Docker"
        exit 1
    fi
    
    # Backup first
    backup_compose_files
    
    # Set flags for report
    CLEANUP_CONTAINERS="false"
    CLEANUP_NETWORKS="false"
    CLEANUP_VOLUMES="false"
    CLEANUP_IMAGES="false"
    CLEANUP_SYSTEM="false"
    REMOVE_COMPOSE="false"
    REMOVE_DOCKER="false"
    
    # Menu-driven cleanup
    while true; do
        echo
        echo "🧹 Cleanup Options:"
        echo "1. Stop and remove containers"
        echo "2. Remove Docker networks"
        echo "3. Remove Docker volumes (⚠️  DESTRUCTIVE)"
        echo "4. Remove Docker images"
        echo "5. Run system cleanup"
        echo "6. Remove Docker Compose"
        echo "7. Remove Docker Engine (⚠️  COMPLETE REMOVAL)"
        echo "8. Generate cleanup report"
        echo "9. Exit"
        echo
        echo -n "Choose an option (1-9): "
        read -r choice
        
        case $choice in
            1)
                cleanup_containers
                CLEANUP_CONTAINERS="true"
                ;;
            2)
                cleanup_networks
                CLEANUP_NETWORKS="true"
                ;;
            3)
                cleanup_volumes
                CLEANUP_VOLUMES="true"
                ;;
            4)
                cleanup_images
                CLEANUP_IMAGES="true"
                ;;
            5)
                cleanup_system
                CLEANUP_SYSTEM="true"
                ;;
            6)
                remove_docker_compose
                REMOVE_COMPOSE="true"
                ;;
            7)
                remove_docker
                REMOVE_DOCKER="true"
                ;;
            8)
                create_cleanup_report
                ;;
            9)
                print_success "Cleanup completed!"
                break
                ;;
            *)
                print_error "Invalid option. Please choose 1-9."
                ;;
        esac
    done
    
    echo
    print_success "🎉 Docker cleanup process completed!"
    print_status "Your system is now running on Kubernetes! 🚀"
}

# Run main function
main "$@" 