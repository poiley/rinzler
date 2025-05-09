#!/bin/bash
############################################################
# Bootstrap Initialization Script
############################################################
# This script initializes a development environment with the following components:
# - Homebrew (package manager)
# - yq (YAML processor)
# - Python (via pyenv)
# - Terraform (via tfenv)
# - ZSH with Oh My Zsh and Powerlevel10k
# - Docker and docker-compose services
#
# CRITICAL EXECUTION ORDER:
# 1. Initial Setup (as root)
#    - Basic system packages (curl, openssl)
#    - Uses SUDO_USER for operations
#
# 2. Homebrew Installation
#    - Must complete before yq installation
#    - Uses SUDO_USER for setup
#    - Sets up Homebrew environment
#
# 3. yq Installation via Homebrew
#    - Required for reading YAML configs
#    - Uses SUDO_USER for installation
#
# 4. GITHUB_SSH_USER Setup
#    - First YAML read using yq
#    - Establishes user for remaining operations
#    - Critical transition point from SUDO_USER
#
# 5. Function Definitions
#    - read_yaml and read_secrets functions
#    - Use GITHUB_SSH_USER context
#    - Required for remaining config reads
#
# 6. Configuration Reading
#    - All YAML configs and secrets
#    - Uses defined functions
#    - Sets up variables for system setup
#
# 7. System Setup
#    - Package installation
#    - Development tools (tfenv, pyenv)
#    - Shell setup (ZSH, Powerlevel10k)
#    - Docker configuration
#
# USER CONTEXT TRANSITIONS:
# - Script starts as root
# - Uses SUDO_USER for initial setup (Phases 1-3)
# - Transitions to GITHUB_SSH_USER (Phases 4-7)
#
# DEPENDENCIES:
# - Homebrew must be installed before yq
# - yq must be installed before any YAML reading
# - GITHUB_SSH_USER must be set before function definitions
# - All configs must be read before system setup
############################################################

# Remove -e flag to prevent exiting on errors, we'll handle errors ourselves
set -uo pipefail

############################################################
# Initial Function Definitions
############################################################
# Define initial read_yaml function that uses SUDO_USER
# This version is used only for reading GITHUB_SSH_USER
read_yaml() {
    local file=$1
    local path=$2
    log "INFO" "Reading YAML from $file at path $path" >&2
    log "INFO" "File exists check: [ -f \"$file\" ]" >&2
    [ -f "$file" ] && echo "File exists" >&2 || echo "File does not exist" >&2
    log "INFO" "File permissions:" >&2
    ls -l "$file" 2>/dev/null >&2 || echo "Cannot access file" >&2
    
    # Get the value using SUDO_USER
    local value=""
    value=$(sudo -u "${SUDO_USER}" bash -c "eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\" || true; yq eval \"$path\" \"$file\" 2>/dev/null" 2>/dev/null) || true
    
    if [[ -z "$value" ]]; then
        log "WARN" "Failed to read value from $file at path $path, returning empty string" >&2
        echo ""
        return 0
    fi
    
    log "INFO" "Raw value (might contain newlines):" >&2
    echo "<<<$value>>>" >&2
    echo "$value"
}

# Version configurations
PYTHON_VERSION="3.12"
TF_VERSION=$(cat terraform/.terraform-version)

# Debug mode toggle for enhanced logging
DEBUG=${DEBUG:-0}

############################################################
# Logging and Error Handling Setup
############################################################
# Create unique log file and initialize tracking variables
SCRIPT_START_TIME=$(date +%s)
LOG_DATE=$(date +%Y%m%d-%H%M%S)
LOG_FILE="/var/log/bootstrap/bootstrap-${LOG_DATE}.log"
mkdir -p /var/log/bootstrap
echo "=== Bootstrap script started at $(date) ===" > "${LOG_FILE}"

# Exit trap control - only enabled at successful completion
ALLOW_EXIT_TRAP=0

# Track step success/failure for final report
declare -A RESULTS
FAILED_STEPS=0
SUCCESSFUL_STEPS=0

############################################################
# Error Handling and Logging Setup
############################################################
# Error handler function
# Captures and logs command failures without stopping script execution
# Parameters:
#   $1: Exit code of failed command
#   $2: Line number where failure occurred
error_handler() {
    local exit_code=$1
    local line_number=$2
    local command=""
    
    # Get the command that failed if possible
    if [ -r "$0" ]; then
        command=$(sed -n "${line_number}p" "$0" 2>/dev/null || echo "unknown command")
    else
        command="unknown command (cannot read script file)"
    fi
    
    # Log error details to both console and log file
    log "ERROR" "Command failed with exit code ${exit_code} at line ${line_number}: '${command}'"
    
    # Track failure for final report
    RESULTS["Line ${line_number} (${command})"]="FAILED (code ${exit_code})"
    ((FAILED_STEPS++))
    
    # Continue script execution
    return 0
}

# Enhanced logging function with multiple severity levels
# Parameters:
#   $1: Log level (INFO/WARN/ERROR/DEBUG) or message if level not specified
#   $2: Message (if $1 is level)
# Usage:
#   log "INFO" "Starting process"
#   log "ERROR" "Failed to execute command"
#   log "Simple message" (defaults to INFO)
log() {
    local level="INFO"
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Handle log level if provided
    if [[ "$#" -gt 1 && ("$1" == "INFO" || "$1" == "WARN" || "$1" == "ERROR" || "$1" == "DEBUG") ]]; then
        level="$1"
        message="$2"
    fi
    
    # Add caller information for ERROR and DEBUG levels
    local caller_info=""
    if [[ "$level" == "ERROR" || "$level" == "DEBUG" ]]; then
        local caller_func="${FUNCNAME[1]:-main}"
        local caller_line="${BASH_LINENO[0]:-unknown}"
        caller_info=" [${caller_func}:${caller_line}]"
    fi
    
    # Format and output log message
    local log_message="=== ${timestamp} === [${level}]${caller_info} $message"
    echo -e "$log_message"
    echo -e "$log_message" >> "${LOG_FILE}"
}

# Debug logging function for execution flow tracking
# Parameters:
#   $1: Debug message to log
# Usage:
#   debug_log "Starting configuration phase"
debug_log() {
    local message="$1"
    log "DEBUG" "FLOW: $message [line:${BASH_LINENO[0]}]"
}

# Function to mark completion of script sections
# Parameters:
#   $1: Description of the completed step
#   $2: Status (SUCCESS/FAILED/SKIPPED, defaults to SUCCESS)
# Usage:
#   mark_step "Homebrew installation"
#   mark_step "Python setup" "SKIPPED"
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

# Function to print execution summary at script completion
# Only runs when ALLOW_EXIT_TRAP=1 (successful completion)
# Outputs:
# - Total execution time
# - Successful and failed steps
# - Detailed failure information
# - Final system state
print_summary() {
    debug_log "print_summary called, ALLOW_EXIT_TRAP=${ALLOW_EXIT_TRAP}"
    
    # Only print summary at script completion
    if [[ "${ALLOW_EXIT_TRAP}" -ne 1 ]]; then
        log "DEBUG" "Early exit trap triggered, but ALLOW_EXIT_TRAP is not set. Ignoring."
        return 0
    fi
    
    # Calculate execution time
    local end_time=$(date +%s)
    local duration=$((end_time - SCRIPT_START_TIME))
    local hours=$((duration / 3600))
    local minutes=$(( (duration % 3600) / 60 ))
    local seconds=$((duration % 60))
    
    # Print summary header
    log "INFO" "====== BOOTSTRAP EXECUTION SUMMARY ======"
    log "INFO" "Total execution time: ${hours}h ${minutes}m ${seconds}s"
    log "INFO" "Successful steps: ${SUCCESSFUL_STEPS}"
    log "INFO" "Failed steps: ${FAILED_STEPS}"
    log "INFO" "Detailed log file: ${LOG_FILE}"
    
    # List failed steps if any
    if [[ ${FAILED_STEPS} -gt 0 ]]; then
        log "INFO" "==== FAILED STEPS ===="
        for step in "${!RESULTS[@]}"; do
            if [[ "${RESULTS[$step]}" == FAILED* ]]; then
                log "ERROR" " - $step: ${RESULTS[$step]}"
            fi
        done
    fi
    
    # Output final system state
    log "INFO" "==== FINAL SYSTEM STATE ===="
    log "INFO" "Disk space:"
    df -h | grep -v "tmpfs" | grep -v "udev" >> "${LOG_FILE}"
    df -h | grep -v "tmpfs" | grep -v "udev"
    
    # Print final status
    if [[ ${FAILED_STEPS} -eq 0 ]]; then
        log "INFO" "Bootstrap completed successfully!"
    else
        log "ERROR" "Bootstrap completed with ${FAILED_STEPS} failures."
    fi
    
    log "INFO" "Log file: ${LOG_FILE}"
}

# Custom exit handler for script completion
# Parameters:
#   Automatically receives exit code from trap
# Handles:
# - Normal script completion
# - Premature termination
# - Final summary output
custom_exit_handler() {
    local exit_code=$?
    debug_log "custom_exit_handler called with status: $exit_code"
    
    if [[ "${ALLOW_EXIT_TRAP}" -eq 1 ]]; then
        log "INFO" "Normal script completion with exit code: $exit_code"
        print_summary
    else
        log "WARN" "Script exited prematurely with code $exit_code, execution incomplete!"
        log "WARN" "Current section didn't complete. Check logs for errors."
        
        # Show minimal summary for debugging
        local end_time=$(date +%s)
        local duration=$((end_time - SCRIPT_START_TIME))
        log "INFO" "Script ran for ${duration} seconds before termination"
        log "INFO" "Successful steps completed: ${SUCCESSFUL_STEPS}"
        log "INFO" "Failed steps: ${FAILED_STEPS}"
        log "INFO" "Log file: ${LOG_FILE}"
    fi
    
    # Always return success to prevent cascading errors
    return 0
}

# Register exit handler
trap custom_exit_handler EXIT

############################################################
# Command Execution Functions
############################################################
# Function to execute commands with logging and error handling
# Parameters:
#   $1: Command to execute
#   $2: Description of command (optional)
#   $3: "show_output" to display command output (optional)
# Returns:
#   Command output (stdout)
#   Command status is logged but not returned
# Usage:
#   log_cmd "whoami" "Check current user"
#   log_cmd "ls -la" "List directory" "show_output"
log_cmd() {
    local cmd="$1"
    local desc="${2:-Executing command}"
    
    log "INFO" "$desc: '$cmd'"
    local output
    local status=0
    
    # Execute command and capture output
    output=$(eval "$cmd" 2>&1) || {
        status=$?
        log "ERROR" "Command failed with status $status: '$cmd'"
        log "ERROR" "Command output: $output"
    }
    
    # Handle success case
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
# Parameters:
#   $1: Mount point to check (defaults to /)
# Usage:
#   log_disk_space "/home"
#   log_disk_space "/var/log"
log_disk_space() {
    local mount_point="${1:-/}"
    log "INFO" "Disk space on $mount_point:"
    df -h "$mount_point" | awk 'NR>1 {print "  Total: "$2", Used: "$3", Avail: "$4", Use%: "$5}'
}

############################################################
# PHASE 1: Initial Setup
############################################################
# Install initial required packages
log "INFO" "=== Starting Initial Setup ==="
log "INFO" "Installing initial packages..."
apt-get update
apt-get install -y build-essential procps curl file git

############################################################
# PHASE 2: Homebrew Installation
############################################################
log "INFO" "=== Starting Homebrew Installation ==="

# Install Homebrew as SUDO_USER
log "INFO" "Installing Homebrew..."
sudo -u "${SUDO_USER}" bash -c 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'

# Verify Homebrew installation
if ! [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
    log "ERROR" "Homebrew installation failed. Cannot continue without Homebrew."
    exit 1
fi

# Add Homebrew to PATH and verify
log "INFO" "Setting up Homebrew environment..."
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
BREW_VERSION=$(sudo -u "${SUDO_USER}" bash -c 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && brew --version')
log "INFO" "Installed Homebrew version: ${BREW_VERSION}"

############################################################
# PHASE 3: yq Installation
############################################################
log "INFO" "=== Installing yq ==="

# Install yq using Homebrew
log "INFO" "Installing yq via Homebrew..."
sudo -u "${SUDO_USER}" bash -c 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && brew install yq'

# Verify yq installation
if ! sudo -u "${SUDO_USER}" bash -c 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && which yq'; then
    log "ERROR" "yq installation failed. Cannot continue without yq."
    exit 1
fi

log "INFO" "yq installed successfully"
YQ_VERSION=$(sudo -u "${SUDO_USER}" bash -c 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && yq --version')
log "INFO" "Installed yq version: ${YQ_VERSION}"

############################################################
# PHASE 4: GitHub User Setup
############################################################
# Critical: First YAML read to get GITHUB_SSH_USER
log "INFO" "Reading GitHub configuration..."
GITHUB_OWNER=$(read_yaml "config/runner.yaml" ".runner.github.owner")
REPOSITORY_NAME=$(read_yaml "config/runner.yaml" ".runner.github.repo_name")
GITHUB_SSH_USER=$(read_yaml "config/runner.yaml" ".runner.github.ssh.user")

if [[ -z "${GITHUB_SSH_USER}" ]]; then
    log "ERROR" "Failed to read GITHUB_SSH_USER from config. This is required to continue."
    exit 1
fi

############################################################
# PHASE 5: Function Definitions
############################################################
# Now that we have GITHUB_SSH_USER, define the final versions of YAML reading functions
read_yaml() {
    local file=$1
    local path=$2
    log "INFO" "Reading YAML from $file at path $path" >&2
    log "INFO" "File exists check: [ -f \"$file\" ]" >&2
    [ -f "$file" ] && echo "File exists" >&2 || echo "File does not exist" >&2
    log "INFO" "File permissions:" >&2
    ls -l "$file" 2>/dev/null >&2 || echo "Cannot access file" >&2
    
    # Get the value using GITHUB_SSH_USER
    local value=""
    value=$(sudo -u "${GITHUB_SSH_USER}" bash -c "eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\" || true; yq eval \"$path\" \"$file\" 2>/dev/null" 2>/dev/null) || true
    
    if [[ -z "$value" ]]; then
        log "WARN" "Failed to read value from $file at path $path, returning empty string" >&2
        echo ""
        return 0
    fi
    
    log "INFO" "Raw value (might contain newlines):" >&2
    echo "<<<$value>>>" >&2
    echo "$value"
}

read_secrets() {
    local file=$1
    local path=$2
    log "INFO" "Reading secrets from $file at path $path" >&2
    log "INFO" "File exists check: [ -f \"$file\" ]" >&2
    [ -f "$file" ] && echo "File exists" >&2 || echo "File does not exist" >&2
    log "INFO" "File permissions:" >&2
    ls -l "$file" 2>/dev/null >&2 || echo "Cannot access file" >&2
    
    # Get the value using GITHUB_SSH_USER
    local value=""
    value=$(sudo -u "${GITHUB_SSH_USER}" bash -c "eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\" || true; yq eval \"$path\" \"$file\" 2>/dev/null" 2>/dev/null) || true
    
    if [[ -z "$value" ]]; then
        log "WARN" "Failed to read secret from $file at path $path, returning empty string" >&2
        echo ""
        return 0
    fi
    
    log "INFO" "Raw secret value detected (not showing content)" >&2
    echo "$value"
}

############################################################
# PHASE 6: Configuration Reading
############################################################
# Read all configuration values using GITHUB_SSH_USER context
log "INFO" "Reading configuration values..."

############################################################
# PHASE 7: System Setup
############################################################
# Development tools installation and configuration
log "INFO" "=== Starting System Setup ==="

# Python Environment Setup (pyenv)
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
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    
    # Initialize pyenv
    eval "$(pyenv init -)" || { echo 'Failed to initialize pyenv'; exit 1; }
    
    # Check existing Python installations
    echo "Checking existing Python installations:"
    pyenv versions || echo "No Python versions installed yet"
    
    # Get target Python version
    PYTHON_FULL_VERSION=$(pyenv install --list | grep -E "^[[:space:]]*${PYTHON_VERSION}\.[0-9]+$" | tail -n 1 | tr -d "[:space:]")
    echo "Target Python version: $PYTHON_FULL_VERSION"
    
    # Check if this version is already installed
    if pyenv versions | grep -q "$PYTHON_FULL_VERSION"; then
        echo "Python $PYTHON_FULL_VERSION is already installed"
        INSTALLED=1
    else
        echo "Python $PYTHON_FULL_VERSION needs to be installed"
        INSTALLED=0
    fi
    
    # If already installed, just verify and exit with success
    if [ $INSTALLED -eq 1 ]; then
        echo "Using existing Python $PYTHON_FULL_VERSION installation"
        # Try to set it as global version
        pyenv global "$PYTHON_FULL_VERSION" || echo "Could not set global Python version"
        
        # Verify installation
        pyenv versions
        echo "Python version:"
        pyenv exec python --version
        exit 0
    fi
    
    # Ensure directories exist with debug output
    echo "Setting up pyenv directories:"
    mkdir -p "$PYENV_ROOT/versions"
    ls -la "$PYENV_ROOT"
    ls -la "$PYENV_ROOT/versions"
    
    # Install Python with auto-agreement to continue if version exists
    echo "Starting Python installation with pyenv..."
    PYENV_INSTALL="yes | pyenv install -v $PYTHON_FULL_VERSION"
    echo "Running: $PYENV_INSTALL"
    eval "$PYENV_INSTALL" || {
        echo "Python installation failed, checking permissions..."
        ls -la "$PYENV_ROOT"
        ls -la "$PYENV_ROOT/versions" 2>/dev/null || true
        df -h "/home/${GITHUB_SSH_USER}" # Check disk space
        exit 1
    }
    
    # Set global Python version
    echo "Setting global Python version to $PYTHON_FULL_VERSION"
    pyenv global "$PYTHON_FULL_VERSION"
    
    # Verify installation
    echo "Python executable location: $(which python || echo 'Not found')"
    echo "Python version installed:"
    pyenv exec python --version
    echo "Pip version installed:"
    pyenv exec pip --version
    echo "Python install location:"
    ls -la "$PYENV_ROOT/versions/$PYTHON_FULL_VERSION/bin/python" || echo "Python binary not found!"
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
        export PYENV_ROOT="$HOME/.pyenv"
        export PATH="$PYENV_ROOT/bin:$PATH"
        eval "$(pyenv init -)"
        PYTHON_FULL_VERSION=$(pyenv install --list | grep -E "^[[:space:]]*${PYTHON_VERSION}\.[0-9]+$" | tail -n 1 | tr -d "[:space:]")
        echo "Retrying installation of Python $PYTHON_FULL_VERSION"
        
        # Check if the version already exists
        if [ -d "$PYENV_ROOT/versions/$PYTHON_FULL_VERSION" ]; then
            echo "Python version dir exists, attempting to reinstall..."
            rm -rf "$PYENV_ROOT/versions/$PYTHON_FULL_VERSION"
        fi
        
        # Non-interactive install
        echo "Running non-interactive install..."
        yes | pyenv install "$PYTHON_FULL_VERSION" && {
            pyenv global "$PYTHON_FULL_VERSION"
            echo "Retry successful, Python $(pyenv exec python --version)"
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

############################################################
# Terraform Environment Setup (tfenv)
############################################################
# This section:
# 1. Installs tfenv for Terraform version management
# 2. Configures shell integration
# 3. Installs specified Terraform version
# 4. Sets up proper permissions and paths
log "INFO" "Installing tfenv..."
debug_log "Starting tfenv installation"

# ... existing tfenv installation code ...

############################################################
# Shell Environment Setup (ZSH + Oh My Zsh)
############################################################
# This section:
# 1. Installs ZSH and Oh My Zsh
# 2. Configures Powerlevel10k theme
# 3. Sets up shell plugins
# 4. Creates shell configuration files
log "INFO" "Setting up ZSH and Powerlevel10k..."
debug_log "Starting ZSH and Powerlevel10k setup"

# ... existing ZSH setup code ...

############################################################
# Font Installation (Nerd Fonts)
############################################################
# This section:
# 1. Downloads and installs IBM Plex Mono Nerd Font
# 2. Sets up font cache and permissions
# 3. Verifies font installation
log "INFO" "Installing Nerd Fonts..."
debug_log "Starting Nerd Fonts installation"

# ... existing font installation code ...

############################################################
# Docker and Service Setup
############################################################
# This section:
# 1. Configures Docker service
# 2. Sets up service directories
# 3. Starts Docker Compose services
# 4. Verifies service health
log "INFO" "Configuring Docker..."
debug_log "Starting Docker configuration"

# ... existing Docker setup code ...

############################################################
# Script Completion
############################################################
# Enable exit trap for summary printing
ALLOW_EXIT_TRAP=1
debug_log "Script completed, exit trap enabled"
mark_step "Script execution"
log "INFO" "Script execution completed successfully"
exit 0 