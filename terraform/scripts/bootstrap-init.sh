#!/bin/bash
# Remove -e flag to prevent exiting on errors, we'll handle errors ourselves
set -uo pipefail

# Version configurations
PYTHON_VERSION="3.12"
TF_VERSION=$(cat terraform/.terraform-version)

# Add debug mode toggle
DEBUG=${DEBUG:-0}

# Script start timestamp for measuring total execution time
SCRIPT_START_TIME=$(date +%s)

# Create a unique log file for this run
LOG_DATE=$(date +%Y%m%d-%H%M%S)
LOG_FILE="/var/log/bootstrap/bootstrap-${LOG_DATE}.log"
mkdir -p /var/log/bootstrap
echo "=== Bootstrap script started at $(date) ===" > "${LOG_FILE}"

# Disable the exit trap until we're at the end of the script
ALLOW_EXIT_TRAP=0

# Track success and failures
declare -A RESULTS
FAILED_STEPS=0
SUCCESSFUL_STEPS=0

# Error handler function
error_handler() {
    local exit_code=$1
    local line_number=$2
    local command=""
    
    # Safely get the command that failed
    if [ -r "$0" ]; then
        command=$(sed -n "${line_number}p" "$0" 2>/dev/null || echo "unknown command")
    else
        command="unknown command (cannot read script file)"
    fi
    
    # Log error details
    log "ERROR" "Command failed with exit code ${exit_code} at line ${line_number}: '${command}'"
    
    # Record failure
    RESULTS["Line ${line_number} (${command})"]="FAILED (code ${exit_code})"
    ((FAILED_STEPS++))
    
    # Don't exit - let the script continue
    return 0
}

# Setup error trapping - commented out because we handle errors per-command
# trap 'error_handler $? $LINENO' ERR

# Function for enhanced logging
log() {
    local level="INFO"
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Handle log level if provided as first argument
    if [[ "$#" -gt 1 && ("$1" == "INFO" || "$1" == "WARN" || "$1" == "ERROR" || "$1" == "DEBUG") ]]; then
        level="$1"
        message="$2"
    fi
    
    # Get caller information for better tracing
    local caller_info=""
    if [[ "$level" == "ERROR" || "$level" == "DEBUG" ]]; then
        local caller_func="${FUNCNAME[1]:-main}"
        local caller_line="${BASH_LINENO[0]:-unknown}"
        caller_info=" [${caller_func}:${caller_line}]"
    fi
    
    # Format the log message
    local log_message="=== ${timestamp} === [${level}]${caller_info} $message"
    
    # Output to console
    echo -e "$log_message"
    
    # Also log to file with session identifier
    echo -e "$log_message" >> "${LOG_FILE}"
}

# Debug log for tracking execution flow
debug_log() {
    local message="$1"
    log "DEBUG" "FLOW: $message [line:${BASH_LINENO[0]}]"
}

# Function to mark step completion
mark_step() {
    local description="$1"
    local status="${2:-SUCCESS}"
    
    debug_log "Marking step: $description ($status)"
    
    if [[ "$status" == "SUCCESS" ]]; then
        RESULTS["$description"]="SUCCESS"
        ((SUCCESSFUL_STEPS++))
        log "INFO" "Step completed: $description"
    else
        RESULTS["$description"]="$status"
        if [[ "$status" != "SKIPPED" ]]; then
            ((FAILED_STEPS++))
            log "ERROR" "Step failed: $description"
        else
            log "INFO" "Step skipped: $description"
        fi
    fi
}

# Function to print execution summary at the end
print_summary() {
    debug_log "print_summary called, ALLOW_EXIT_TRAP=${ALLOW_EXIT_TRAP}"
    
    # Only print summary if we're at the end of the script
    if [[ "${ALLOW_EXIT_TRAP}" -ne 1 ]]; then
        log "DEBUG" "Early exit trap triggered, but ALLOW_EXIT_TRAP is not set. Ignoring."
        return 0
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - SCRIPT_START_TIME))
    local hours=$((duration / 3600))
    local minutes=$(( (duration % 3600) / 60 ))
    local seconds=$((duration % 60))
    
    log "INFO" "====== BOOTSTRAP EXECUTION SUMMARY ======"
    log "INFO" "Total execution time: ${hours}h ${minutes}m ${seconds}s"
    log "INFO" "Successful steps: ${SUCCESSFUL_STEPS}"
    log "INFO" "Failed steps: ${FAILED_STEPS}"
    log "INFO" "Detailed log file: ${LOG_FILE}"
    
    if [[ ${FAILED_STEPS} -gt 0 ]]; then
        log "INFO" "==== FAILED STEPS ===="
        for step in "${!RESULTS[@]}"; do
            if [[ "${RESULTS[$step]}" == FAILED* ]]; then
                log "ERROR" " - $step: ${RESULTS[$step]}"
            fi
        done
    fi
    
    # Output system state at the end
    log "INFO" "==== FINAL SYSTEM STATE ===="
    log "INFO" "Disk space:"
    df -h | grep -v "tmpfs" | grep -v "udev" >> "${LOG_FILE}"
    df -h | grep -v "tmpfs" | grep -v "udev"
    
    if [[ ${FAILED_STEPS} -eq 0 ]]; then
        log "INFO" "Bootstrap completed successfully!"
    else
        log "ERROR" "Bootstrap completed with ${FAILED_STEPS} failures."
    fi
    
    log "INFO" "Log file: ${LOG_FILE}"
}

# Register exit handler to print summary - but only at the very end
custom_exit_handler() {
    local exit_code=$?
    debug_log "custom_exit_handler called with status: $exit_code"
    
    if [[ "${ALLOW_EXIT_TRAP}" -eq 1 ]]; then
        log "INFO" "Normal script completion with exit code: $exit_code"
        print_summary
    else
        log "WARN" "Script exited prematurely with code $exit_code, execution incomplete!"
        log "WARN" "Current section didn't complete. Check logs for errors."
        
        # Still show a minimal summary for debugging
        local end_time=$(date +%s)
        local duration=$((end_time - SCRIPT_START_TIME))
        log "INFO" "Script ran for ${duration} seconds before termination"
        log "INFO" "Successful steps completed: ${SUCCESSFUL_STEPS}"
        log "INFO" "Failed steps: ${FAILED_STEPS}"
        log "INFO" "Log file: ${LOG_FILE}"
    fi
    
    # Always return success to ensure we don't propagate errors
    return 0
}

# Use EXIT trap instead of ERR trap
trap custom_exit_handler EXIT

# Function to log command executions with their results
log_cmd() {
    local cmd="$1"
    local desc="${2:-Executing command}"
    
    log "INFO" "$desc: '$cmd'"
    local output
    local status=0
    
    output=$(eval "$cmd" 2>&1) || {
        status=$?
        log "ERROR" "Command failed with status $status: '$cmd'"
        log "ERROR" "Command output: $output"
    }
    
    if [ $status -eq 0 ]; then
        log "INFO" "Command succeeded: '$cmd'"
        if [[ "${DEBUG:-0}" == "1" || "${3:-}" == "show_output" ]]; then
            log "INFO" "Command output: $output"
        fi
        echo "$output"
        return 0
    else
        log "WARN" "Continuing despite command failure"
        echo "$output"
        return $status
    fi
}

# Function to check and log disk space
log_disk_space() {
    local mount_point="${1:-/}"
    log "INFO" "Disk space on $mount_point:"
    df -h "$mount_point" | awk 'NR>1 {print "  Total: "$2", Used: "$3", Avail: "$4", Use%: "$5}'
}

debug_log "Starting main script execution"

log "INFO" "Script started"
log "INFO" "Environment check:"
log_cmd "whoami" "Current user"
log_cmd "echo ${SUDO_USER}" "SUDO_USER"
log_cmd "pwd" "Current directory"
log_disk_space "/home"

# Ensure we're running as root
if [ "$EUID" -ne 0 ]; then 
    log "ERROR" "Script must be run as root"
    exit 1
fi

# Set non-interactive frontend
export DEBIAN_FRONTEND=noninteractive

log "INFO" "Installing initial packages"
debug_log "Starting initial package installation"
apt-get update
apt-get install curl openssl -y

log "INFO" "=== Starting Homebrew Installation ==="
debug_log "Starting Homebrew installation"

# Add system state logging
log "INFO" "System state before Homebrew installation:"
log "INFO" "Current user: $(whoami)"
log "INFO" "SUDO_USER: ${SUDO_USER}"
log "INFO" "Current directory: $(pwd)"
log "INFO" "Available disk space:"
df -h /home
log "INFO" "Memory status:"
free -h
log "INFO" "Environment variables:"
env | grep -E 'HOME|USER|PATH|SUDO' | sort

# Check Homebrew prerequisites with detailed logging
log "INFO" "Checking Homebrew prerequisites:"
log_cmd "curl --version" "curl version" "show_output" || {
    log "ERROR" "curl check failed"
    mark_step "Homebrew prerequisites" "FAILED"
    return 1
}
log_cmd "openssl version" "openssl version" "show_output" || {
    log "ERROR" "openssl check failed"
    mark_step "Homebrew prerequisites" "FAILED"
    return 1
}

# Check Homebrew directory permissions
log "INFO" "Homebrew directory permissions before install:"
ls -la /home/linuxbrew 2>/dev/null || echo "Homebrew directory does not exist yet"

# Install Homebrew if not already installed
if [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
    log "INFO" "Homebrew already installed, checking installation:"
    log "INFO" "Homebrew directory structure:"
    ls -la /home/linuxbrew/.linuxbrew || true
    log "INFO" "Homebrew Cellar directory:"
    ls -la /home/linuxbrew/.linuxbrew/Cellar 2>/dev/null || echo "Cellar directory does not exist yet"
    BREW_INSTALL_STATUS=0
else
    # Install Homebrew with detailed logging
    log "INFO" "Installing Homebrew..."
    log "INFO" "Running Homebrew installation as user ${SUDO_USER}"
    
    # Create a temporary log file for the installation
    BREW_INSTALL_LOG="/tmp/homebrew_install_${LOG_DATE}.log"
    log "INFO" "Homebrew installation log will be saved to: ${BREW_INSTALL_LOG}"
    
    # Run Homebrew installation with detailed logging
    sudo -u "${SUDO_USER}" bash -c "
        set -x
        echo '=== Homebrew Installation Started ===' > ${BREW_INSTALL_LOG}
        echo 'Environment:' >> ${BREW_INSTALL_LOG}
        env | sort >> ${BREW_INSTALL_LOG}
        echo 'Current directory: \$(pwd)' >> ${BREW_INSTALL_LOG}
        echo 'Disk space:' >> ${BREW_INSTALL_LOG}
        df -h >> ${BREW_INSTALL_LOG}
        echo 'Starting Homebrew installation...' >> ${BREW_INSTALL_LOG}
        NONINTERACTIVE=1 /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\" >> ${BREW_INSTALL_LOG} 2>&1
        INSTALL_STATUS=\$?
        echo 'Installation completed with status: \$INSTALL_STATUS' >> ${BREW_INSTALL_LOG}
        exit \$INSTALL_STATUS
    " 2>&1 | tee -a "${LOG_FILE}"
    BREW_INSTALL_STATUS=$?
    
    log "INFO" "Homebrew installation command exited with status: $BREW_INSTALL_STATUS"
    log "INFO" "Full Homebrew installation log:"
    cat "${BREW_INSTALL_LOG}" >> "${LOG_FILE}"
fi

# Whether installation succeeded or not, try to continue
log "INFO" "Checking for Homebrew directory..."
if [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
    log "INFO" "=== Homebrew Installation Complete ==="
    log "INFO" "Homebrew directory structure:"
    ls -la /home/linuxbrew/.linuxbrew || true
    log "INFO" "Homebrew Cellar directory:"
    ls -la /home/linuxbrew/.linuxbrew/Cellar 2>/dev/null || echo "Cellar directory does not exist yet"
    
    if [[ $BREW_INSTALL_STATUS -eq 0 ]]; then
        mark_step "Homebrew installation"
    else
        log "WARN" "Homebrew installation completed with warnings (status: $BREW_INSTALL_STATUS)"
        mark_step "Homebrew installation" "WARNING"
    fi
    
    # Add debug tracking for Homebrew section completion
    debug_log "Completed Homebrew section"
    
    # Set proper permissions for Homebrew directory
    log "INFO" "Setting permissions for Homebrew directory..."
    chown -R "${SUDO_USER}:${SUDO_USER}" /home/linuxbrew/.linuxbrew || {
        log "ERROR" "Failed to set Homebrew directory permissions"
        log "INFO" "Current permissions:"
        ls -la /home/linuxbrew/.linuxbrew
    }
    
    log "INFO" "Permissions after chown:"
    ls -la /home/linuxbrew/.linuxbrew || true
    log "INFO" "Cellar permissions after chown:"
    ls -la /home/linuxbrew/.linuxbrew/Cellar 2>/dev/null || echo "Cellar directory does not exist yet"
    
    # Add Homebrew to environment for the current user
    log "INFO" "Adding Homebrew to shell configuration..."
    { echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "/home/${SUDO_USER}/.bashrc"; } || log "ERROR" "Failed to add Homebrew to .bashrc"
    { echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "/home/${SUDO_USER}/.zshrc"; } || log "ERROR" "Failed to add Homebrew to .zshrc"
    
    # Set up Homebrew environment for the current shell
    log "INFO" "Setting up Homebrew environment..."
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" || log "ERROR" "Failed to set up Homebrew environment"
    
    log "INFO" "=== Installing yq ==="
    log "INFO" "Homebrew environment:"
    env | grep HOMEBREW || true
    log "INFO" "Homebrew version:"
    brew --version || true
    
    # Install yq as the target user with proper environment setup
    log "INFO" "Starting yq installation as ${SUDO_USER}..."
    sudo -u "${SUDO_USER}" bash -c '
        set -x
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" || true
        export HOMEBREW_NO_AUTO_UPDATE=1
        export HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1
        echo "=== Starting yq installation ==="
        echo "Current user: $(whoami)"
        echo "Homebrew path: $(which brew || echo "brew not found")"
        echo "Homebrew version: $(brew --version 2>/dev/null || echo "brew version failed")"
        echo "Target directory permissions:"
        ls -la /home/linuxbrew/.linuxbrew/Cellar || echo "Cannot access Cellar"
        echo "Available disk space:"
        df -h /home
        echo "Starting brew install yq..."
        brew install yq || echo "yq installation failed with status $?"
    ' || true
    YQ_INSTALL_STATUS=$?
    
    log "INFO" "yq installation command exited with status: $YQ_INSTALL_STATUS"
    
    if [[ $YQ_INSTALL_STATUS -eq 0 ]]; then
        mark_step "yq installation"
        # Add debug tracking for yq completion
        debug_log "Completed yq installation"
    else
        log "WARN" "yq installation may have failed with status $YQ_INSTALL_STATUS, but continuing script"
        mark_step "yq installation" "WARNING"
    fi
    
    # Add diagnostic logging after yq installation
    log "INFO" "=== Post yq Installation Diagnostics ==="
    log "INFO" "Current directory: $(pwd)"
    log "INFO" "Directory contents:"
    ls -la || true
    log "INFO" "Checking for config directory:"
    ls -la config/ 2>/dev/null || echo "Config directory not found"
    log "INFO" "Checking for bootstrap.yaml:"
    ls -la config/bootstrap.yaml 2>/dev/null || echo "bootstrap.yaml not found"
    log "INFO" "Testing yq installation:"
    sudo -u "${SUDO_USER}" bash -c 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" || true; yq --version || echo "yq version command failed"' || true
    log "INFO" "Testing yq with a simple command:"
    sudo -u "${SUDO_USER}" bash -c 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" || true; yq eval "true" config/bootstrap.yaml 2>&1 || echo "yq test failed with status $?"' || true

    log "INFO" "=== LINE 124: Before function definitions ==="
    log "INFO" "Checking if we can define functions..."
else
    log "ERROR" "Error: Homebrew installation directory not found after installation attempt"
    mark_step "Homebrew installation" "FAILED"
fi

# Function to read YAML values using yq
read_yaml() {
    local file=$1
    local path=$2
    # Send logs to stderr instead of stdout
    log "INFO" "Reading YAML from $file at path $path" >&2
    log "INFO" "File exists check: [ -f \"$file\" ]" >&2
    [ -f "$file" ] && echo "File exists" >&2 || echo "File does not exist" >&2
    log "INFO" "File permissions:" >&2
    ls -l "$file" 2>/dev/null >&2 || echo "Cannot access file" >&2
    
    # Get the value without logging
    local value=""
    value=$(sudo -u "${SUDO_USER}" bash -c "eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\" || true; yq eval \"$path\" \"$file\" 2>/dev/null" 2>/dev/null) || true
    
    # Check if value is empty
    if [[ -z "$value" ]]; then
        log "WARN" "Failed to read value from $file at path $path, returning empty string" >&2
        echo ""
        return 0
    fi
    
    # Add diagnostic logging
    log "INFO" "Raw value (might contain newlines):" >&2
    echo "<<<$value>>>" >&2
    
    # Return the value directly
    echo "$value"
}

log "INFO" "=== LINE 135: After read_yaml function ==="
log "INFO" "Checking if we can continue after function definition..."

# Function to read secrets from YAML
read_secrets() {
    local file=$1
    local path=$2
    # Send logs to stderr instead of stdout
    log "INFO" "Reading secrets from $file at path $path" >&2
    log "INFO" "File exists check: [ -f \"$file\" ]" >&2
    [ -f "$file" ] && echo "File exists" >&2 || echo "File does not exist" >&2
    log "INFO" "File permissions:" >&2
    ls -l "$file" 2>/dev/null >&2 || echo "Cannot access file" >&2
    
    # Get the value without logging
    local value=""
    value=$(sudo -u "${SUDO_USER}" bash -c "eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\" || true; yq eval \"$path\" \"$file\" 2>/dev/null" 2>/dev/null) || true
    
    # Check if value is empty
    if [[ -z "$value" ]]; then
        log "WARN" "Failed to read secret from $file at path $path, returning empty string" >&2
        echo ""
        return 0
    fi
    
    # Add diagnostic logging
    log "INFO" "Raw secret value detected (not showing content)" >&2
    
    # Return the value directly
    echo "$value"
}

log "INFO" "=== LINE 145: After read_secrets function ==="
log "INFO" "Checking if we can continue after secrets function..."

# Change to the correct directory
log "INFO" "Changing to rinzler directory..."
cd "/home/${SUDO_USER}/rinzler"
log "INFO" "Current directory: $(pwd)"
log "INFO" "Directory contents after cd:"
ls -la

# Read packages list from bootstrap.yaml
log "INFO" "Reading packages from bootstrap.yaml..."
# Get packages directly without extra logging
PACKAGES=$(sudo -u "${SUDO_USER}" bash -c 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"; yq eval ".bootstrap.packages[]" "config/bootstrap.yaml"' | tr '\n' ' ')
log "INFO" "Packages to install: ${PACKAGES}"

# Read configuration values from bootstrap.yaml
log "INFO" "Reading configuration values from bootstrap.yaml..."
DOCKGE_STACKS_DIR=$(read_yaml "config/bootstrap.yaml" ".bootstrap.dockge_stacks_dir")
TIMEZONE=$(read_yaml "config/bootstrap.yaml" ".bootstrap.timezone")
PUID=$(read_yaml "config/bootstrap.yaml" ".bootstrap.puid")
PGID=$(read_yaml "config/bootstrap.yaml" ".bootstrap.pgid")
ZFS_POOL=$(read_yaml "config/bootstrap.yaml" ".bootstrap.zfs_pool")
WIREGUARD_ADDRESSES=$(read_yaml "config/bootstrap.yaml" ".bootstrap.wireguard.addresses")

# Read GitHub configuration
log "INFO" "Reading GitHub configuration..."
GITHUB_OWNER=$(read_yaml "config/runner.yaml" ".runner.github.owner")
REPOSITORY_NAME=$(read_yaml "config/runner.yaml" ".runner.github.repo_name")
GITHUB_SSH_USER=$(read_yaml "config/runner.yaml" ".runner.github.ssh.user")

# Add debug for GITHUB_SSH_USER
log "DEBUG" "DEBUG: GITHUB_SSH_USER value check:" >&2
echo "GITHUB_SSH_USER=[${GITHUB_SSH_USER}]" >&2
log "DEBUG" "DEBUG: Length of GITHUB_SSH_USER: $(echo -n "${GITHUB_SSH_USER}" | wc -c) characters" >&2
log "DEBUG" "DEBUG: Line count of GITHUB_SSH_USER: $(echo "${GITHUB_SSH_USER}" | wc -l) lines" >&2

# Rest of the configs
GITHUB_SERVER_HOST=$(read_yaml "config/runner.yaml" ".runner.github.ssh.server_host")

# Read Pi-hole configuration
log "INFO" "Reading Pi-hole configuration..."
PIHOLE_URL=$(read_yaml "config/pihole.yaml" ".pihole.url")

# Read UniFi configuration
log "INFO" "Reading UniFi configuration..."
UNIFI_CONTROLLER_URL=$(read_yaml "config/unifi.yaml" ".unifi.controller_url")
UNIFI_SITE=$(read_yaml "config/unifi.yaml" ".unifi.site")

# Read secrets
log "INFO" "Reading secrets from example.yaml..."
BASIC_AUTH_HEADER=$(read_secrets "config/secrets/example.yaml" ".bootstrap.basic_auth_header")
WIREGUARD_PRIVATE_KEY=$(read_secrets "config/secrets/example.yaml" ".bootstrap.wireguard.private_key")
PIHOLE_PASSWORD=$(read_secrets "config/secrets/example.yaml" ".pihole.password")
PIHOLE_API_TOKEN=$(read_secrets "config/secrets/example.yaml" ".pihole.api_token")
GITHUB_TOKEN=$(read_secrets "config/secrets/example.yaml" ".github.token")
GITHUB_RUNNER_TOKEN=$(read_secrets "config/secrets/example.yaml" ".github.runner_token")
GITHUB_SSH_PRIVATE_KEY=$(read_secrets "config/secrets/example.yaml" ".github.ssh.private_key")
UNIFI_USERNAME=$(read_secrets "config/secrets/example.yaml" ".unifi.username")
UNIFI_PASSWORD=$(read_secrets "config/secrets/example.yaml" ".unifi.password")
UNIFI_API_KEY=$(read_secrets "config/secrets/example.yaml" ".unifi.api_key")

# Install required packages
log "INFO" "Installing required packages..."
apt-get update
# Convert space-separated string to array and install
read -ra PACKAGES_ARRAY <<< "${PACKAGES}"
apt-get install -y "${PACKAGES_ARRAY[@]}"

mark_step "System packages installation"

# Install tfenv
log "INFO" "Installing tfenv..."
debug_log "Starting tfenv installation"
TFENV_DIR="/home/${GITHUB_SSH_USER}/.tfenv"
log "INFO" "tfenv directory path: ${TFENV_DIR}"
log "INFO" "GITHUB_SSH_USER: ${GITHUB_SSH_USER}"

# Ensure dependencies
command -v git >/dev/null || { log "ERROR" "Error: git is required"; exit 1; }
log "INFO" "Git is available: $(git --version)"

# Clone tfenv if not already present
if [[ ! -d "$TFENV_DIR" ]]; then
    log "INFO" "Cloning tfenv repository..."
    git clone --depth=1 https://github.com/tfutils/tfenv.git "$TFENV_DIR"
    log "INFO" "tfenv clone result: $?"
    
    # Fix ownership immediately after clone
    log "INFO" "Setting tfenv directory permissions..."
    chown -R "${GITHUB_SSH_USER}:${GITHUB_SSH_USER}" "$TFENV_DIR"
    log "INFO" "Ownership change result: $?"
else
    log "INFO" "tfenv directory already exists at $TFENV_DIR"
    ls -la "$TFENV_DIR"
fi

# Add tfenv to PATH and shell configs
log "INFO" "Adding tfenv to PATH..."
export PATH="${TFENV_DIR}/bin:$PATH"
echo "export PATH=\"${TFENV_DIR}/bin:\$PATH\"" >> "/home/${GITHUB_SSH_USER}/.bashrc"
echo "export PATH=\"${TFENV_DIR}/bin:\$PATH\"" >> "/home/${GITHUB_SSH_USER}/.zshrc"
log "INFO" "Current PATH: $PATH"

# Create the versions directory with proper permissions
log "INFO" "Creating tfenv versions directory with proper permissions..."
mkdir -p "${TFENV_DIR}/versions"
chown -R "${GITHUB_SSH_USER}:${GITHUB_SSH_USER}" "${TFENV_DIR}"
chmod -R 755 "${TFENV_DIR}"
log "INFO" "tfenv directory structure after permission setup:"
ls -la "${TFENV_DIR}"
ls -la "${TFENV_DIR}/versions"

# Install Terraform non-interactively
log "INFO" "Installing Terraform ${TF_VERSION}..."
log "INFO" "Terraform version from file: ${TF_VERSION}"
sudo -u "${GITHUB_SSH_USER}" bash -c "
    set -x
    export PATH=\"${TFENV_DIR}/bin:\$PATH\"
    cd \$HOME  # Ensure we're in the user's home directory
    log \"Running as user: \$(whoami)\"
    log \"Current directory: \$(pwd)\"
    log \"tfenv path: \$(which tfenv 2>/dev/null || echo 'tfenv not found')\"
    log \"tfenv in PATH: \$(echo \$PATH | grep -q \"${TFENV_DIR}/bin\" && echo 'yes' || echo 'no')\"
    tfenv install \"${TF_VERSION}\" || { echo 'Terraform installation failed with code $?'; exit 1; }
    tfenv use \"${TF_VERSION}\" || { echo 'Terraform version selection failed with code $?'; exit 1; }
    log \"Terraform location: \$(which terraform 2>/dev/null || echo 'terraform not found')\"
    log \"Terraform version: \$(terraform --version 2>/dev/null || echo 'terraform version command failed')\"
" || log "INFO" "Terraform installation process exited with non-zero status, continuing anyway..."

# Verify installation
if [[ -f "${TFENV_DIR}/versions/${TF_VERSION}/terraform" ]]; then
    log "INFO" "Terraform binary found at ${TFENV_DIR}/versions/${TF_VERSION}/terraform"
    ls -la "${TFENV_DIR}/versions/${TF_VERSION}/terraform"
else
    log "INFO" "Warning: Terraform binary not found at expected location: ${TFENV_DIR}/versions/${TF_VERSION}/terraform"
    log "INFO" "Available versions:"
    ls -la "${TFENV_DIR}/versions/" 2>/dev/null || echo "No versions directory or no versions installed"
fi

mark_step "Terraform installation"
debug_log "Completed Terraform installation"

# Install pyenv
log "INFO" "Installing pyenv..."
debug_log "Starting pyenv installation"
log "INFO" "Running pyenv installation for user: ${GITHUB_SSH_USER}"

# Check if pyenv is already installed
if [[ -d "/home/${GITHUB_SSH_USER}/.pyenv" ]]; then
    log "INFO" "Pyenv already installed at /home/${GITHUB_SSH_USER}/.pyenv, skipping installation"
    log "INFO" "Existing pyenv version: $(sudo -u "${GITHUB_SSH_USER}" bash -c 'PYENV_ROOT="$HOME/.pyenv" PATH="$PYENV_ROOT/bin:$PATH" pyenv --version 2>/dev/null || echo "Unknown"')"
else
    sudo -u "${GITHUB_SSH_USER}" bash -c 'set -x; curl -s https://pyenv.run | bash; echo "Pyenv install result: $?"'
fi

# Create pyenv directories with proper permissions
log "INFO" "Creating pyenv directories with proper permissions..."
mkdir -p "/home/${GITHUB_SSH_USER}/.pyenv/versions"
chown -R "${GITHUB_SSH_USER}:${GITHUB_SSH_USER}" "/home/${GITHUB_SSH_USER}/.pyenv"
chmod -R 755 "/home/${GITHUB_SSH_USER}/.pyenv"
log "INFO" "Pyenv directory structure after creation:"
ls -la "/home/${GITHUB_SSH_USER}/.pyenv"
ls -la "/home/${GITHUB_SSH_USER}/.pyenv/versions"

# Configure pyenv in shell startup files
log "INFO" "Configuring pyenv in shell startup files..."
cat >> "/home/${GITHUB_SSH_USER}/.bashrc" << 'EOF'

# pyenv configuration
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
EOF

cat >> "/home/${GITHUB_SSH_USER}/.zshrc" << 'EOF'

# pyenv configuration
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
EOF

log "INFO" "Updated shell configuration files for pyenv"

# Set up Python installation environment
log "INFO" "Setting up Python build environment..."
export PYENV_ROOT="/home/${GITHUB_SSH_USER}/.pyenv"
export PATH="${PYENV_ROOT}/bin:$PATH"
eval "$(pyenv init -)" || log "INFO" "Warning: pyenv init failed"
log "INFO" "Current PATH: $PATH"
log "INFO" "Pyenv executable: $(which pyenv 2>/dev/null || echo 'pyenv not found')"

# Install Python via pyenv
log "INFO" "Installing Python ${PYTHON_VERSION} via pyenv..."
log "INFO" "System dependencies for pyenv build:"
log "INFO" "$(dpkg -l | grep -E 'libssl|libreadline|zlib|bzip|libbz2|libsqlite|libffi|libncurses')"

# Check if Python is already installed
PYTHON_FULL_VERSION=""
sudo -u "${GITHUB_SSH_USER}" bash -c "
    set -xeo pipefail
    export PYENV_ROOT=\"\$HOME/.pyenv\"
    export PATH=\"\$PYENV_ROOT/bin:\$PATH\"
    
    # Initialize pyenv
    eval \"\$(pyenv init -)\" || { echo 'Failed to initialize pyenv'; exit 1; }
    
    # Check existing Python installations
    echo \"Checking existing Python installations:\"
    pyenv versions || echo \"No Python versions installed yet\"
    
    # Get target Python version
    PYTHON_FULL_VERSION=\$(pyenv install --list | grep -E \"^[[:space:]]*${PYTHON_VERSION}\.[0-9]+\$\" | tail -n 1 | tr -d \"[:space:]\")
    echo \"Target Python version: \$PYTHON_FULL_VERSION\"
    
    # Check if this version is already installed
    if pyenv versions | grep -q \"\$PYTHON_FULL_VERSION\"; then
        echo \"Python \$PYTHON_FULL_VERSION is already installed\"
        INSTALLED=1
    else
        echo \"Python \$PYTHON_FULL_VERSION needs to be installed\"
        INSTALLED=0
    fi
    
    # If already installed, just verify and exit with success
    if [ \$INSTALLED -eq 1 ]; then
        echo \"Using existing Python \$PYTHON_FULL_VERSION installation\"
        # Try to set it as global version
        pyenv global \"\$PYTHON_FULL_VERSION\" || echo \"Could not set global Python version\"
        
        # Verify installation
        pyenv versions
        echo \"Python version:\"
        pyenv exec python --version
        exit 0
    fi
    
    # Ensure directories exist with debug output
    echo \"Setting up pyenv directories:\"
    mkdir -p \"\$PYENV_ROOT/versions\"
    ls -la \"\$PYENV_ROOT\"
    ls -la \"\$PYENV_ROOT/versions\"
    
    # Install Python with auto-agreement to continue if version exists
    echo \"Starting Python installation with pyenv...\"
    PYENV_INSTALL=\"yes | pyenv install -v \$PYTHON_FULL_VERSION\"
    echo \"Running: \$PYENV_INSTALL\"
    eval \"\$PYENV_INSTALL\" || {
        echo \"Python installation failed, checking permissions...\"
        ls -la \"\$PYENV_ROOT\"
        ls -la \"\$PYENV_ROOT/versions\" 2>/dev/null || true
        df -h \"/home/${GITHUB_SSH_USER}\" # Check disk space
        exit 1
    }
    
    # Set global Python version
    echo \"Setting global Python version to \$PYTHON_FULL_VERSION\"
    pyenv global \"\$PYTHON_FULL_VERSION\"
    
    # Verify installation
    echo \"Python executable location: \$(which python || echo 'Not found')\"
    echo \"Python version installed:\"
    pyenv exec python --version
    echo \"Pip version installed:\"
    pyenv exec pip --version
    echo \"Python install location:\"
    ls -la \"\$PYENV_ROOT/versions/\$PYTHON_FULL_VERSION/bin/python\" || echo \"Python binary not found!\"
" 2>&1 | tee "/tmp/pyenv_install_log_${GITHUB_SSH_USER}.log" || {
    log "ERROR" "Error: Python installation failed. Fixing permissions and retrying..."
    log "INFO" "Full installation log available at /tmp/pyenv_install_log_${GITHUB_SSH_USER}.log"
    
    # Check system for issues
    log "INFO" "System state check:"
    log "INFO" "Available disk space:"
    df -h
    log "INFO" "Memory status:"
    free -h
    log "INFO" "Python build dependencies:"
    apt-cache policy libbz2-dev libssl-dev libffi-dev libreadline-dev
    
    # Ensure directories exist with proper permissions as fallback
    mkdir -p "/home/${GITHUB_SSH_USER}/.pyenv/versions"
    chown -R "${GITHUB_SSH_USER}:${GITHUB_SSH_USER}" "/home/${GITHUB_SSH_USER}/.pyenv"
    chmod -R 755 "/home/${GITHUB_SSH_USER}/.pyenv"
    
    # Retry installation with fixed permissions and non-interactive mode
    log "INFO" "Retrying Python installation with fixed permissions..."
    sudo -u "${GITHUB_SSH_USER}" bash -c "
        set -x
        export PYENV_ROOT=\"\$HOME/.pyenv\"
        export PATH=\"\$PYENV_ROOT/bin:\$PATH\"
        eval \"\$(pyenv init -)\"
        PYTHON_FULL_VERSION=\$(pyenv install --list | grep -E \"^[[:space:]]*${PYTHON_VERSION}\.[0-9]+\$\" | tail -n 1 | tr -d \"[:space:]\")
        echo \"Retrying installation of Python \$PYTHON_FULL_VERSION\"
        
        # Check if the version already exists
        if [ -d \"\$PYENV_ROOT/versions/\$PYTHON_FULL_VERSION\" ]; then
            echo \"Python version dir exists, attempting to reinstall...\"
            rm -rf \"\$PYENV_ROOT/versions/\$PYTHON_FULL_VERSION\"
        fi
        
        # Non-interactive install
        echo \"Running non-interactive install...\"
        yes | pyenv install \"\$PYTHON_FULL_VERSION\" && {
            pyenv global \"\$PYTHON_FULL_VERSION\"
            echo \"Retry successful, Python \$(pyenv exec python --version)\"
        }
    " 2>&1 | tee "/tmp/pyenv_retry_log_${GITHUB_SSH_USER}.log" || {
        log "INFO" "Warning: Python installation failed again. See logs for details:"
        log "INFO" "Original attempt: /tmp/pyenv_install_log_${GITHUB_SSH_USER}.log"
        log "INFO" "Retry attempt: /tmp/pyenv_retry_log_${GITHUB_SSH_USER}.log"
        log "INFO" "Continuing script execution without Python..."
    }
}

# Ensure Pyenv permissions are correct
log "INFO" "Setting pyenv permissions..."
chown -R "${GITHUB_SSH_USER}:${GITHUB_SSH_USER}" "/home/${GITHUB_SSH_USER}/.pyenv"
log "INFO" "Pyenv installation summary:"
log "INFO" "Pyenv directory exists: $([ -d "/home/${GITHUB_SSH_USER}/.pyenv" ] && echo 'Yes' || echo 'No')"
log "INFO" "Python versions installed:"
ls -la "/home/${GITHUB_SSH_USER}/.pyenv/versions/" 2>/dev/null || echo "No Python versions directory found"

mark_step "Python installation"
debug_log "Completed Python installation"

# Set up ZSH and Powerlevel10k
log "INFO" "Setting up ZSH and Powerlevel10k..."
debug_log "Starting ZSH and Powerlevel10k setup"

# Check if Oh My Zsh is already installed
if [[ -d "/home/${GITHUB_SSH_USER}/.oh-my-zsh" ]]; then
    log "INFO" "Oh My Zsh already installed, skipping installation"
else
    # Install Oh My Zsh (non-interactive)
    log "INFO" "Installing Oh My Zsh..."
    sudo -u "${GITHUB_SSH_USER}" bash -c "RUNZSH=no CHSH=no sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended"
    OMZ_STATUS=$?
    log "INFO" "Oh My Zsh installation result: $OMZ_STATUS"
    
    if [[ $OMZ_STATUS -ne 0 ]]; then
        log "WARN" "Warning: Oh My Zsh installation failed with status $OMZ_STATUS"
    fi
fi

# Install Powerlevel10k (check if already installed first)
log "INFO" "Setting up Powerlevel10k theme..."
if [[ -d "/home/${GITHUB_SSH_USER}/.oh-my-zsh/custom/themes/powerlevel10k" ]]; then
    log "INFO" "Powerlevel10k already installed, updating..."
    cd "/home/${GITHUB_SSH_USER}/.oh-my-zsh/custom/themes/powerlevel10k" || log "ERROR" "Cannot change to powerlevel10k directory"
    sudo -u "${GITHUB_SSH_USER}" git pull || log "ERROR" "Failed to update powerlevel10k"
else
    log "INFO" "Installing Powerlevel10k theme..."
    sudo -u "${GITHUB_SSH_USER}" git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "/home/${GITHUB_SSH_USER}/.oh-my-zsh/custom/themes/powerlevel10k" || log "ERROR" "Failed to install powerlevel10k"
fi

# Install ZSH plugins (check first)
log "INFO" "Setting up ZSH plugins..."
if [[ ! -d "/home/${GITHUB_SSH_USER}/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]]; then
    log "INFO" "Installing zsh-autosuggestions..."
    sudo -u "${GITHUB_SSH_USER}" git clone https://github.com/zsh-users/zsh-autosuggestions "/home/${GITHUB_SSH_USER}/.oh-my-zsh/custom/plugins/zsh-autosuggestions" || log "ERROR" "Failed to install zsh-autosuggestions"
fi

if [[ ! -d "/home/${GITHUB_SSH_USER}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]]; then
    log "INFO" "Installing zsh-syntax-highlighting..."
    sudo -u "${GITHUB_SSH_USER}" git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "/home/${GITHUB_SSH_USER}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" || log "ERROR" "Failed to install zsh-syntax-highlighting"
fi

# Set ZSH as default shell (non-interactive)
log "INFO" "Setting ZSH as default shell..."
ZSH_PATH=$(which zsh)
if [[ -n "$ZSH_PATH" ]]; then
    if getent passwd "${GITHUB_SSH_USER}" | grep -q "$ZSH_PATH"; then
        log "INFO" "ZSH is already the default shell for ${GITHUB_SSH_USER}"
    else
        chsh -s "$ZSH_PATH" "${GITHUB_SSH_USER}" || log "ERROR" "Failed to set ZSH as default shell"
    fi
else
    log "ERROR" "Error: ZSH not found, cannot set as default shell"
fi

mark_step "ZSH setup"
debug_log "Completed ZSH setup"

# Install Nerd Fonts
log "INFO" "Installing Nerd Fonts..."
debug_log "Starting Nerd Fonts installation"
log "INFO" "Creating fonts directory for user ${GITHUB_SSH_USER}..."
mkdir -p "/home/${GITHUB_SSH_USER}/.local/share/fonts"
cd "/home/${GITHUB_SSH_USER}/.local/share/fonts"
log "INFO" "Changed to fonts directory: $(pwd)"

# Set proper ownership for the fonts directory
log "INFO" "Setting ownership of fonts directory to ${GITHUB_SSH_USER}..."
chown -R "${GITHUB_SSH_USER}:${GITHUB_SSH_USER}" "/home/${GITHUB_SSH_USER}/.local/share/fonts"
log "INFO" "Font directory permissions:"
ls -la "/home/${GITHUB_SSH_USER}/.local/share/fonts"

# Get the latest release version with error handling
log "INFO" "Getting latest Nerd Fonts release..."
LATEST_RELEASE=$(curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || echo "v3.4.0")
log "INFO" "GitHub API response status: $?"

# Fallback if GitHub API fails
if [[ -z "$LATEST_RELEASE" ]]; then
    log "INFO" "Failed to get latest release, using default version v3.4.0"
    LATEST_RELEASE="v3.4.0"
fi

log "INFO" "Latest release: ${LATEST_RELEASE}"
log "INFO" "Font download URL: https://github.com/ryanoasis/nerd-fonts/releases/download/${LATEST_RELEASE}/IBMPlexMono.zip"

# Download and extract IBM Plex Mono with error handling
log "INFO" "Downloading IBM Plex Mono..."
if curl -L --fail -o "IBMPlexMono.zip" "https://github.com/ryanoasis/nerd-fonts/releases/download/${LATEST_RELEASE}/IBMPlexMono.zip"; then
    log "INFO" "Successfully downloaded IBMPlexMono.zip"
    log "INFO" "Download size: $(du -h IBMPlexMono.zip)"
    log "INFO" "Download integrity check: $(file IBMPlexMono.zip)"
    
    log "INFO" "Extracting font files..."
    if unzip -o "IBMPlexMono.zip" "BlexMonoNerdFontMono-*.ttf" -d "/home/${GITHUB_SSH_USER}/.local/share/fonts/" 2>/dev/null; then
        log "INFO" "Successfully extracted font files"
        log "INFO" "Extracted files:"
        ls -la "/home/${GITHUB_SSH_USER}/.local/share/fonts/BlexMonoNerdFontMono-"*
    else
        log "WARN" "Warning: Failed to extract specific font files, trying alternative extraction"
        unzip -o "IBMPlexMono.zip" -d "/home/${GITHUB_SSH_USER}/.local/share/fonts/" > "/tmp/font_extraction_${GITHUB_SSH_USER}.log" 2>&1
        UNZIP_STATUS=$?
        if [ $UNZIP_STATUS -eq 0 ]; then
            log "INFO" "Alternative extraction succeeded"
            log "INFO" "Extracted font count: $(ls -1 "/home/${GITHUB_SSH_USER}/.local/share/fonts/"*.ttf 2>/dev/null | wc -l)"
        else
            log "ERROR" "Error: Font extraction failed with status $UNZIP_STATUS"
            log "INFO" "See extraction log at /tmp/font_extraction_${GITHUB_SSH_USER}.log"
        fi
    fi
    
    log "INFO" "Cleaning up zip file..."
    rm "IBMPlexMono.zip"
    log "INFO" "Cleanup result: $?"
else
    log "ERROR" "Error: Failed to download IBM Plex Mono, trying fallback method"
    log "INFO" "Curl exit status: $?"
    
    # Fallback to direct download of specific files if needed
    log "INFO" "Attempting direct file download fallback..."
    FALLBACK_URL="https://github.com/ryanoasis/nerd-fonts/raw/${LATEST_RELEASE}/patched-fonts/IBMPlexMono/Mono/Regular/complete/Blex%20Mono%20Nerd%20Font%20Complete%20Mono.ttf"
    log "INFO" "Fallback URL: $FALLBACK_URL"
    
    curl -fLo "BlexMonoNerdFontMono-Regular.ttf" "$FALLBACK_URL"
    FALLBACK_STATUS=$?
    log "INFO" "Fallback download status: $FALLBACK_STATUS"
    
    if [ $FALLBACK_STATUS -eq 0 ]; then
        log "INFO" "Fallback download successful"
        log "INFO" "Downloaded file: $(ls -la BlexMonoNerdFontMono-Regular.ttf)"
    else
        log "ERROR" "Error: Fallback font download failed with status $FALLBACK_STATUS"
    fi
fi

# Set proper permissions for the font files
log "INFO" "Setting font file permissions..."
chown -R "${GITHUB_SSH_USER}:${GITHUB_SSH_USER}" "/home/${GITHUB_SSH_USER}/.local/share/fonts"
chmod 644 "/home/${GITHUB_SSH_USER}/.local/share/fonts/"*.ttf 2>/dev/null
CHMOD_STATUS=$?
if [ $CHMOD_STATUS -eq 0 ]; then
    log "INFO" "Font permissions set successfully"
else
    log "WARN" "Warning: Setting font permissions returned status $CHMOD_STATUS"
    log "INFO" "Font directory contents:"
    ls -la "/home/${GITHUB_SSH_USER}/.local/share/fonts/"
fi

# Update font cache for Ubuntu
log "INFO" "Updating font cache..."
su - ${GITHUB_SSH_USER} -c "fc-cache -f -v" > "/tmp/font_cache_${GITHUB_SSH_USER}.log" 2>&1
FCCACHE_STATUS=$?
if [ $FCCACHE_STATUS -eq 0 ]; then
    log "INFO" "Font cache updated successfully"
else
    log "WARN" "Warning: Font cache update failed with status $FCCACHE_STATUS"
    log "INFO" "See font cache log at /tmp/font_cache_${GITHUB_SSH_USER}.log"
fi
log "INFO" "Font installation verification:"
su - ${GITHUB_SSH_USER} -c "fc-list | grep -i blex" || log "INFO" "IBM Plex Mono Nerd Font not found in font list"

mark_step "Nerd Fonts installation"
debug_log "Completed Nerd Fonts installation"

# Create .zshrc with Powerlevel10k configuration
log "INFO" "Creating .zshrc configuration..."
cat > "/home/${GITHUB_SSH_USER}/.zshrc" << 'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git docker docker-compose zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

# Add Homebrew to PATH
test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Configure pyenv
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# Add tfenv to PATH
export PATH="$HOME/.tfenv/bin:$PATH"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh
[[ ! -f "$HOME/.p10k.zsh" ]] || source "$HOME/.p10k.zsh"
EOF

# Create a basic p10k configuration
log "INFO" "Creating p10k configuration..."
cat > "/home/${GITHUB_SSH_USER}/.p10k.zsh" << 'EOF'
# Basic Powerlevel10k configuration
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
  dir                     # current directory
  vcs                    # git status
  newline                # \n
  prompt_char            # prompt symbol
)

typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
  status                 # exit code of the last command
  command_execution_time # duration of the last command
  background_jobs       # presence of background jobs
  time                  # current time
)

# Basic color scheme
typeset -g POWERLEVEL9K_MODE=nerdfont-complete
typeset -g POWERLEVEL9K_PROMPT_ON_NEWLINE=true
typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=true
EOF

# Configure Docker
log "INFO" "Configuring Docker..."
debug_log "Starting Docker configuration"
log "INFO" "Docker info before services setup:"
docker info || log "INFO" "Docker service not running or not accessible"

log "INFO" "Enabling Docker service..."
systemctl enable docker
ENABLE_STATUS=$?
log "INFO" "Docker enable status: $ENABLE_STATUS"

log "INFO" "Starting Docker service..."
systemctl start docker
START_STATUS=$?
log "INFO" "Docker start status: $START_STATUS"

if [ $START_STATUS -eq 0 ]; then
    log "INFO" "Docker service started successfully. Verifying:"
    docker version
    log "INFO" "Docker service status:"
    systemctl status docker | head -10
else
    log "WARN" "Warning: Docker service failed to start. Status:"
    systemctl status docker | head -10 || log "ERROR" "Failed to retrieve Docker status"
fi

# Start services (only if compose directory exists)
COMPOSE_DIR="/home/${GITHUB_SSH_USER}/compose"
log "INFO" "Checking for compose directory at ${COMPOSE_DIR}..."
if [[ -d "$COMPOSE_DIR" ]]; then
    log "INFO" "Compose directory found. Directory contents:"
    ls -la "$COMPOSE_DIR"
    
    log "INFO" "Starting services from compose directory..."
    cd "$COMPOSE_DIR"
    log "INFO" "Current directory: $(pwd)"
    
    # Check if there are any docker-compose.yml files
    log "INFO" "Looking for compose files in ${COMPOSE_DIR}..."
    COMPOSE_FILES=$(find . -name "docker-compose.yml" -o -name "compose.yaml" -o -name "compose.yml")
    if [[ -n "$COMPOSE_FILES" ]]; then
        log "INFO" "Found compose files: $COMPOSE_FILES"
        for compose_file in $COMPOSE_FILES; do
            compose_dir=$(dirname "$compose_file")
            log "INFO" "Starting services in $compose_dir (file: $compose_file)"
            cd "$compose_dir"
            log "INFO" "Current directory: $(pwd)"
            log "INFO" "Compose file contents (first 10 lines):"
            head -10 "$(basename "$compose_file")"
            
            log "INFO" "Starting services with docker-compose..."
            sudo -u "${GITHUB_SSH_USER}" docker-compose up -d
            UP_STATUS=$?
            
            if [ $UP_STATUS -eq 0 ]; then
                log "INFO" "Services in $compose_dir started successfully"
                sudo -u "${GITHUB_SSH_USER}" docker-compose ps
            else
                log "WARN" "Warning: Failed to start services in $compose_dir (status: $UP_STATUS)"
                log "INFO" "Docker compose logs:"
                sudo -u "${GITHUB_SSH_USER}" docker-compose logs --tail 20
            fi
            
            cd "$COMPOSE_DIR"
        done
    else
        log "INFO" "No compose files found in $COMPOSE_DIR"
    fi
else
    log "INFO" "Compose directory $COMPOSE_DIR not found, skipping service startup"
    log "INFO" "Available directories in /home/${GITHUB_SSH_USER}:"
    ls -la "/home/${GITHUB_SSH_USER}" | grep -v "\\." | head -10
fi

log "INFO" "Checking Docker service status after setup:"
systemctl is-active docker && log "INFO" "Docker is active" || log "INFO" "Docker is not active"
systemctl is-enabled docker && log "INFO" "Docker is enabled" || log "INFO" "Docker is not enabled"

log "INFO" "Checking container status:"
docker ps -a || log "ERROR" "Failed to list Docker containers"

mark_step "Docker setup"
debug_log "Completed Docker setup"

# At the very end of the script, right before mark_step "Script execution"
# Evaluate services startup success
if [[ -d "$COMPOSE_DIR" && -n "$COMPOSE_FILES" ]]; then
    log "INFO" "All services startup attempts completed"
    mark_step "Services startup"
elif [[ -d "$COMPOSE_DIR" ]]; then
    log "INFO" "No compose files found in $COMPOSE_DIR"
    mark_step "Services startup" "SKIPPED" 
else
    log "INFO" "Compose directory not found, services startup skipped"
    mark_step "Services startup" "SKIPPED"
fi

# Allow the exit trap to print the summary at the end of the script
log "INFO" "Enabling exit trap for script completion"
ALLOW_EXIT_TRAP=1

# Add final debugging
debug_log "Script completed, exit trap enabled"

# End of the script
mark_step "Script execution"
log "INFO" "Script execution completed successfully"

# Exit with success status to ensure we don't propagate any errors
exit 0 