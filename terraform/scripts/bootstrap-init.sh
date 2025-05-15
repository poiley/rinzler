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

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run with sudo"
    exit 1
fi

# Handle SUDO_USER when running with sudo
if [ -z "${SUDO_USER}" ]; then
    if [ -n "${USER}" ]; then
        SUDO_USER="${USER}"
    else
        echo "Could not determine user context"
        exit 1
    fi
fi

# Remove -e flag to prevent exiting on errors, we'll handle errors ourselves
set -u # Exit on undefined variables

############################################################
# Logging Setup
############################################################
# Initialize logging variables
SCRIPT_START_TIME=$(date +%s)
LOG_DATE=$(date +%Y%m%d-%H%M%S)

# Try different log locations in order of preference
LOG_DIRS="/var/log/bootstrap /home/${SUDO_USER}/.bootstrap/logs $(pwd)/logs /tmp/bootstrap-${SUDO_USER}"

# Initialize log file variable
LOG_FILE=""
LOG_DIR=""

# Find writable log directory
for dir in ${LOG_DIRS}; do
    # Try to create directory and test writability
    if mkdir -p "${dir}" 2>/dev/null && [ -w "${dir}" ]; then
        LOG_DIR="${dir}"
        LOG_FILE="${dir}/bootstrap-${LOG_DATE}.log"
        chmod 755 "${dir}" 2>/dev/null || true
        break
    fi
done

# Verify we have a writable log location
if [ -z "${LOG_FILE}" ]; then
    echo "ERROR: Could not find writable log location. Tried:"
    printf '%s\n' "${LOG_DIRS[@]}"
    exit 1
fi

# Initialize log file
echo "=== Bootstrap script started at $(date) ===" > "${LOG_FILE}" || {
    echo "ERROR: Could not write to log file ${LOG_FILE}"
    exit 1
}
chmod 644 "${LOG_FILE}" 2>/dev/null || true

# Track if logging to file is working
LOG_TO_FILE=1

############################################################
# Logging Functions
############################################################
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
    case "$1" in
        INFO|WARN|ERROR|DEBUG)
        level="$1"
        message="$2"
            ;;
    esac
    
    # Add caller information for ERROR and DEBUG levels
    local caller_info=""
    case "$level" in
        ERROR|DEBUG)
            caller_info=" [${0##*/}:${LINENO:-unknown}]"
            ;;
    esac
    
    # Format log message
    local log_message="=== ${timestamp} === [${level}]${caller_info} $message"
    
    # Always output to console
    echo "$log_message"
    
    # Try to write to log file if enabled
    if [ "${LOG_TO_FILE:-1}" = "1" ]; then
        if ! echo "$log_message" >> "${LOG_FILE}" 2>/dev/null; then
            echo "WARNING: Failed to write to log file, disabling file logging"
            LOG_TO_FILE=0
        fi
    fi
}

# Debug logging function for execution flow tracking
debug_log() {
    local message="$1"
    log "DEBUG" "FLOW: $message [line:${LINENO:-unknown}]"
}

# Log initial setup information
log "INFO" "Log file location: ${LOG_FILE}"
log "INFO" "Running as user: ${SUDO_USER}"
log "INFO" "Current directory: $(pwd)"

############################################################
# Initial Function Definitions
############################################################
# Define initial read_yaml function that uses SUDO_USER
# This version is used only for reading GITHUB_SSH_USER
read_yaml() {
    local file="$1"
    local path="$2"
    
    # Redirect all debug output to stderr
    {
        log "INFO" "Reading YAML from $file at path $path"
        log "INFO" "File exists check: [ -f \"$file\" ]"
        [ -f "$file" ] && echo "File exists" || echo "File does not exist"
        log "INFO" "File permissions:"
        ls -l "$file" 2>/dev/null || echo "Cannot access file"
    } 1>&2
    
    # Get the value using SUDO_USER
    local value=""
    value=$(sudo -u "${SUDO_USER}" bash -c "eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\" || true; yq eval \"$path\" \"$file\" 2>/dev/null" 2>/dev/null) || true
    
    if [[ -z "$value" ]]; then
        log "WARN" "Failed to read value from $file at path $path, returning empty string" 1>&2
        echo ""
        return 0
    fi
    
    # Log the value and return it
    {
        log "INFO" "Raw value - may include newlines"
        echo "---BEGIN VALUE---"
        echo "$value"
        echo "---END VALUE---"
    } 1>&2
    
    echo "$value"
}

# Version configurations
PYTHON_VERSION="3.12"
if [ -f "terraform/.terraform-version" ]; then
TF_VERSION=$(cat terraform/.terraform-version)
else
    log "WARN" "terraform/.terraform-version not found, using latest stable version"
    TF_VERSION="latest"
fi

# Debug mode toggle for enhanced logging
DEBUG=${DEBUG:-0}

############################################################
# Error Handling and Logging Setup
############################################################
# Exit trap control - only enabled at successful completion
ALLOW_EXIT_TRAP=0

# Initialize tracking variables
FAILED_STEPS=0
SUCCESSFUL_STEPS=0
RESULTS=""

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
    RESULTS="${RESULTS}Line ${line_number} (${command}):FAILED (code ${exit_code});"
    ((FAILED_STEPS++))
    
    # Continue script execution
    return 0
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
    
    case "$status" in
        SUCCESS)
            SUCCESSFUL_STEPS=$((SUCCESSFUL_STEPS + 1))
        log "INFO" "Step completed: $description"
            ;;
        FAILED)
            FAILED_STEPS=$((FAILED_STEPS + 1))
            log "ERROR" "Step failed: $description"
            ;;
        SKIPPED)
            log "INFO" "Step skipped: $description"
            ;;
    esac
    
    RESULTS="${RESULTS}${description}:${status};"
}

# Function to print execution summary at script completion
# Only runs when ALLOW_EXIT_TRAP=1 (successful completion)
# Outputs:
# - Total execution time
# - Successful and failed steps
# - Detailed failure information
# - Final system state
print_summary() {
    debug_log "print_summary called, ALLOW_EXIT_TRAP=${ALLOW_EXIT_TRAP:-0}"
    
    # Only print summary at script completion
    if [ "${ALLOW_EXIT_TRAP:-0}" != "1" ]; then
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
    if [ "${FAILED_STEPS}" -gt 0 ]; then
        log "INFO" "==== FAILED STEPS ===="
        echo "${RESULTS}" | tr ';' '\n' | while IFS=: read -r step status; do
            if [ "${status}" = "FAILED" ]; then
                log "ERROR" " - ${step}: ${status}"
            fi
        done
    fi
    
    # Output final system state
    log "INFO" "==== FINAL SYSTEM STATE ===="
    log "INFO" "Disk space:"
    df -h | grep -v "tmpfs" | grep -v "udev" >> "${LOG_FILE}"
    df -h | grep -v "tmpfs" | grep -v "udev"
    
    # Print final status
    if [ "${FAILED_STEPS}" -eq 0 ]; then
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
log "INFO" "=== Starting Initial Setup ==="
log "INFO" "Installing initial packages..."

# Install base dependencies
apt-get update
apt-get install -y build-essential procps curl file git unzip

# Install Python build dependencies (needed later, but install now as root)
log "INFO" "Installing Python build dependencies..."
apt-get install -y \
    libbz2-dev \
    libssl-dev \
    libffi-dev \
    libreadline-dev \
    zlib1g-dev \
    liblzma-dev \
    libsqlite3-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libxml2-dev \
    libxmlsec1-dev \
    libgdbm-dev \
    libnss3-dev \
    libreadline-dev \
    libffi-dev \
    libdb-dev \
    uuid-dev

# Verify critical build dependencies
log "INFO" "Verifying Python build dependencies..."
# Add a small delay to ensure package database is updated
sleep 2

# Verify each critical package using dpkg-query
for pkg in zlib1g-dev libssl-dev libffi-dev libreadline-dev; do
    if ! dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null | grep -q "installed"; then
        log "ERROR" "Required package ${pkg} is not installed"
        mark_step "Initial Setup" "FAILED"
    exit 1
fi
done

# Log installed versions of critical packages
log "INFO" "Installed versions of critical packages:"
for pkg in zlib1g-dev libssl-dev libffi-dev libreadline-dev; do
    VERSION=$(dpkg-query -W -f='${Version}' "${pkg}" 2>/dev/null)
    log "INFO" "  ${pkg}: ${VERSION}"
done

mark_step "Initial Setup"

############################################################
# PHASE 2: Homebrew Installation
############################################################
log "INFO" "=== Starting Homebrew Installation ==="

# Install Homebrew as SUDO_USER
    log "INFO" "Installing Homebrew..."
sudo -u "${SUDO_USER}" bash -c 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' || {
    log "ERROR" "Homebrew installation failed"
    mark_step "Homebrew Installation" "FAILED"
    exit 1
}

# Verify Homebrew installation and environment
log "INFO" "Verifying Homebrew installation..."
if ! [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
    log "ERROR" "Homebrew binary not found at expected location"
    mark_step "Homebrew Installation" "FAILED"
    exit 1
fi

# Add Homebrew to PATH and verify
log "INFO" "Setting up Homebrew environment..."
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" || {
    log "ERROR" "Failed to set up Homebrew environment"
    mark_step "Homebrew Installation" "FAILED"
    exit 1
}

# Verify Homebrew functionality
BREW_VERSION=$(sudo -u "${SUDO_USER}" bash -c 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && brew --version') || {
    log "ERROR" "Failed to get Homebrew version"
    mark_step "Homebrew Installation" "FAILED"
    exit 1
}

# Log Homebrew environment for debugging
log "INFO" "Homebrew environment details:"
log "INFO" "  Version: ${BREW_VERSION}"
log "INFO" "  Path: $(which brew)"
log "INFO" "  Home: $(brew --prefix)"

mark_step "Homebrew Installation"

############################################################
# PHASE 3: yq Installation
############################################################
log "INFO" "=== Installing yq ==="

# Install yq using Homebrew
log "INFO" "Installing yq via Homebrew..."
sudo -u "${SUDO_USER}" bash -c 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && brew install yq' || {
    log "ERROR" "yq installation failed"
    mark_step "yq Installation" "FAILED"
    exit 1
}

# Verify yq installation and functionality
log "INFO" "Verifying yq installation..."
YQ_PATH=$(sudo -u "${SUDO_USER}" bash -c 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && which yq') || {
    log "ERROR" "yq not found in PATH"
    mark_step "yq Installation" "FAILED"
    exit 1
}

# Get and verify yq version
YQ_VERSION=$(sudo -u "${SUDO_USER}" bash -c 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && yq --version') || {
    log "ERROR" "Failed to get yq version"
    mark_step "yq Installation" "FAILED"
    exit 1
}

# Log yq details for debugging
log "INFO" "yq installation details:"
log "INFO" "  Path: ${YQ_PATH}"
log "INFO" "  Version: ${YQ_VERSION}"

# Test yq functionality with a simple YAML
log "INFO" "Testing yq functionality..."
TEST_YAML="/home/${SUDO_USER}/.bootstrap/yq-test.yaml"
mkdir -p "$(dirname "${TEST_YAML}")"
chown "${SUDO_USER}:${SUDO_USER}" "$(dirname "${TEST_YAML}")"
echo "test: value" > "${TEST_YAML}"
chown "${SUDO_USER}:${SUDO_USER}" "${TEST_YAML}"

YQ_TEST=""
YQ_TEST=$(sudo -u "${SUDO_USER}" bash -c '
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" || exit 1
    yq eval ".test" "'"${TEST_YAML}"'" 2>/dev/null
') || {
    log "ERROR" "yq functionality test failed"
    rm -f "${TEST_YAML}"
    mark_step "yq Installation" "FAILED"
    exit 1
}

if [[ -z "${YQ_TEST}" ]]; then
    log "ERROR" "yq test output was empty"
    rm -f "${TEST_YAML}"
    mark_step "yq Installation" "FAILED"
    exit 1
fi

if [[ "${YQ_TEST}" != "value" ]]; then
    log "ERROR" "yq test output mismatch: expected 'value', got '${YQ_TEST}'"
    rm -f "${TEST_YAML}"
    mark_step "yq Installation" "FAILED"
    exit 1
fi

rm -f "${TEST_YAML}"
log "INFO" "yq installation and verification completed successfully"
mark_step "yq Installation"

############################################################
# PHASE 4: GitHub User Setup
############################################################
log "INFO" "=== Reading GitHub Configuration ==="

# Verify config file exists
if [ ! -f "config/runner.yaml" ]; then
    log "ERROR" "Configuration file 'config/runner.yaml' not found"
    mark_step "GitHub User Setup" "FAILED"
    exit 1
fi

# Critical: First YAML read to get GITHUB_SSH_USER
log "INFO" "Reading GitHub configuration..."
GITHUB_OWNER=$(read_yaml "config/runner.yaml" ".runner.github.owner")
if [[ -z "${GITHUB_OWNER}" ]]; then
    log "ERROR" "Failed to read GitHub owner from config"
    mark_step "GitHub User Setup" "FAILED"
    exit 1
fi

REPOSITORY_NAME=$(read_yaml "config/runner.yaml" ".runner.github.repo_name")
if [[ -z "${REPOSITORY_NAME}" ]]; then
    log "ERROR" "Failed to read repository name from config"
    mark_step "GitHub User Setup" "FAILED"
    exit 1
fi

GITHUB_SSH_USER=$(read_yaml "config/runner.yaml" ".runner.github.ssh.user")
if [[ -z "${GITHUB_SSH_USER}" ]]; then
    log "ERROR" "Failed to read GITHUB_SSH_USER from config"
    mark_step "GitHub User Setup" "FAILED"
    exit 1
fi

# Verify user exists
if ! id "${GITHUB_SSH_USER}" &>/dev/null; then
    log "ERROR" "User ${GITHUB_SSH_USER} does not exist"
    mark_step "GitHub User Setup" "FAILED"
    exit 1
fi

# Log configuration details
log "INFO" "Successfully read GitHub configuration:"
log "INFO" "  Owner: ${GITHUB_OWNER}"
log "INFO" "  Repository: ${REPOSITORY_NAME}"
log "INFO" "  SSH User: ${GITHUB_SSH_USER}"
log "INFO" "  User Home: $(eval echo ~${GITHUB_SSH_USER})"
log "INFO" "  User Groups: $(groups ${GITHUB_SSH_USER})"

mark_step "GitHub User Setup"

############################################################
# PHASE 5: Function Definitions
############################################################
# Now that we have GITHUB_SSH_USER, define the final versions of YAML reading functions
read_yaml() {
    local file="$1"
    local path="$2"
    
    # Redirect all debug output to stderr
    {
        log "INFO" "Reading YAML from $file at path $path"
        log "INFO" "File exists check: [ -f \"$file\" ]"
        [ -f "$file" ] && echo "File exists" || echo "File does not exist"
        log "INFO" "File permissions:"
        ls -l "$file" 2>/dev/null || echo "Cannot access file"
    } 1>&2
    
    # Get the value using SUDO_USER
    local value=""
    value=$(sudo -u "${SUDO_USER}" bash -c "eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\" || true; yq eval \"$path\" \"$file\" 2>/dev/null" 2>/dev/null) || true
    
    if [[ -z "$value" ]]; then
        log "WARN" "Failed to read value from $file at path $path, returning empty string" 1>&2
        echo ""
        return 0
    fi
    
    # Log the value and return it
    {
        log "INFO" "Raw value - may include newlines"
        echo "---BEGIN VALUE---"
        echo "$value"
        echo "---END VALUE---"
    } 1>&2
    
    echo "$value"
}

read_secrets() {
    local file="$1"
    local path="$2"
    
    # Redirect all debug output to stderr
    {
        log "INFO" "Reading secrets from $file at path $path"
        log "INFO" "File exists check: [ -f \"$file\" ]"
        [ -f "$file" ] && echo "File exists" || echo "File does not exist"
        log "INFO" "File permissions:"
        ls -l "$file" 2>/dev/null || echo "Cannot access file"
    } 1>&2
    
    # Get the value using GITHUB_SSH_USER
    local value=""
    value=$(sudo -u "${GITHUB_SSH_USER}" bash -c "eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\" || true; yq eval \"$path\" \"$file\" 2>/dev/null" 2>/dev/null) || true
    
    if [[ -z "$value" ]]; then
        log "WARN" "Failed to read secret from $file at path $path, returning empty string" 1>&2
        echo ""
        return 0
    fi
    
    # Log that we found a secret
    log "INFO" "Secret value found - not displaying contents" 1>&2
    
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
log "INFO" "=== Starting System Setup ==="

# Install pyenv
log "INFO" "Installing pyenv..."
if [ -d "/home/${GITHUB_SSH_USER}/.pyenv" ]; then
    log "INFO" "Pyenv already installed at /home/${GITHUB_SSH_USER}/.pyenv, checking version..."
    PYENV_VERSION=$(sudo -u "${GITHUB_SSH_USER}" bash -c 'PYENV_ROOT="$HOME/.pyenv" PATH="$PYENV_ROOT/bin:$PATH" pyenv --version 2>/dev/null || echo "Unknown"')
    log "INFO" "Existing pyenv version: ${PYENV_VERSION}"
    INSTALLED=1
else
    log "INFO" "Installing pyenv..."
    sudo -u "${GITHUB_SSH_USER}" bash -c 'set -x; curl -s https://pyenv.run | bash' || {
        log "ERROR" "Failed to install pyenv"
        mark_step "Python Installation" "FAILED"
        exit 1
    }
fi

# Create pyenv directories with proper permissions
log "INFO" "Setting up pyenv directories..."
mkdir -p "/home/${GITHUB_SSH_USER}/.pyenv/versions"
chown -R "${GITHUB_SSH_USER}:${GITHUB_SSH_USER}" "/home/${GITHUB_SSH_USER}/.pyenv"
chmod -R 755 "/home/${GITHUB_SSH_USER}/.pyenv"

# Verify pyenv installation
if ! sudo -u "${GITHUB_SSH_USER}" bash -c 'PYENV_ROOT="$HOME/.pyenv" PATH="$PYENV_ROOT/bin:$PATH" pyenv --version' &>/dev/null; then
    log "ERROR" "Pyenv installation verification failed"
    mark_step "Python Installation" "FAILED"
    exit 1
fi

# Configure shell startup files
log "INFO" "Configuring pyenv in shell startup files..."
cat >> "/home/${GITHUB_SSH_USER}/.bashrc" << 'EOF'

# pyenv configuration
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
EOF

# Set up Python installation environment
log "INFO" "Setting up Python build environment..."
export PYENV_ROOT="/home/${GITHUB_SSH_USER}/.pyenv"
export PATH="${PYENV_ROOT}/bin:$PATH"

# Determine Python version to install
log "INFO" "Determining Python version to install..."

# Check for existing .python-version file
if [ -f ".python-version" ]; then
    PYTHON_VERSIONS=$(cat ".python-version" | tr -d '[:space:]')
    log "INFO" "Found .python-version file, using version: ${PYTHON_VERSIONS}"
else
    # Get available Python versions
    log "INFO" "No .python-version file found, fetching latest ${PYTHON_VERSION}.x version..."
    log "INFO" "Looking for Python version matching: ${PYTHON_VERSION}.x"

    # Debug pyenv environment before running commands
    log "INFO" "Verifying pyenv environment:"
    log "INFO" "PYENV_ROOT expected: /home/${GITHUB_SSH_USER}/.pyenv"
    log "INFO" "pyenv binary location: $(which pyenv 2>/dev/null || echo 'not found')"
    log "INFO" "Current user: $(id)"
log "INFO" "GITHUB_SSH_USER: ${GITHUB_SSH_USER}"

    # Create a temporary file for version output
    VERSION_FILE=$(mktemp)
    chmod 666 "${VERSION_FILE}"  # Make it world readable/writable

    # Get the latest matching version directly
    log "INFO" "Starting Python version selection..."
    sudo -u "${GITHUB_SSH_USER}" bash -c '
        export PYENV_ROOT="$HOME/.pyenv"
        export PATH="$PYENV_ROOT/bin:$PATH"
        
        echo "Debug: Checking pyenv installation" >&2
        if ! command -v pyenv >/dev/null 2>&1; then
            echo "Error: pyenv not found in PATH" >&2
            exit 1
        fi
    
    # Initialize pyenv
        echo "Debug: Running pyenv init" >&2
        eval "$(pyenv init -)" || {
            echo "Error: Failed to initialize pyenv" >&2
            exit 1
        }
        
        # Find latest matching version
        echo "Debug: Fetching Python versions list" >&2
        # Only get CPython versions, exclude other implementations
        pyenv install --list | \
            grep -E "^[[:space:]]*'"${PYTHON_VERSION}"'\\.[0-9]+\$" | \
            grep -v "stackless\|pypy\|miniconda\|anaconda\|graalpython\|jython\|ironpython\|micropython" | \
            sort -V | \
            tail -n1 | \
            tr -d "[:space:]" > '"${VERSION_FILE}"'
    ' 2> >(while read -r line; do log "DEBUG" "pyenv: $line"; done)

    SELECTION_STATUS=$?
    log "INFO" "Version selection command exit status: ${SELECTION_STATUS}"

    # Read the version from the file
    if [ ! -s "${VERSION_FILE}" ]; then
        log "ERROR" "No Python version was written to version file"
        log "ERROR" "This could mean either:"
        log "ERROR" "  1. pyenv is not properly initialized"
        log "ERROR" "  2. The requested version ${PYTHON_VERSION}.x is not available"
        log "ERROR" "  3. The version pattern matching failed"
        rm -f "${VERSION_FILE}"
        mark_step "Python Installation" "FAILED"
        exit 1
    fi

    PYTHON_VERSIONS=$(cat "${VERSION_FILE}")
    rm -f "${VERSION_FILE}"
fi

log "INFO" "Selected version string: '${PYTHON_VERSIONS}'"

if [ -z "${PYTHON_VERSIONS}" ]; then
    log "ERROR" "Failed to determine Python version"
    log "ERROR" "This could mean either:"
    log "ERROR" "  1. .python-version file is empty"
    log "ERROR" "  2. Version selection failed"
    mark_step "Python Installation" "FAILED"
    exit 1
fi

log "INFO" "Found matching Python version: ${PYTHON_VERSIONS}"
log "INFO" "Verifying version string format..."
if ! echo "${PYTHON_VERSIONS}" | grep -qE "^${PYTHON_VERSION}\.[0-9]+$"; then
    log "ERROR" "Selected version '${PYTHON_VERSIONS}' does not match expected format"
    log "ERROR" "Expected format: ${PYTHON_VERSION}.x where x is a number"
    mark_step "Python Installation" "FAILED"
    exit 1
fi

log "INFO" "Version string format verified"
log "INFO" "Proceeding with installation..."

# Install Python with build environment
log "INFO" "Installing Python ${PYTHON_VERSIONS}..."

# Create a temporary script for installation
INSTALL_SCRIPT="/home/${GITHUB_SSH_USER}/.pyenv/pyenv_install.sh"
cat > "${INSTALL_SCRIPT}" << 'EOF'
#!/bin/bash
set -e
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

# Initialize pyenv
eval "$(pyenv init -)" || {
    echo "Failed to initialize pyenv"
        exit 1
    }
    
# Set build environment variables
export CFLAGS="-I/usr/include/openssl -I/usr/include/ncursesw"
export LDFLAGS="-L/usr/lib/x86_64-linux-gnu"
export LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu"

# Install Python with auto-agreement
VERSION="$1"
echo "Installing Python version: $VERSION"
yes | pyenv install -v "$VERSION"
EOF

# Set proper permissions
chmod 755 "${INSTALL_SCRIPT}"
chown "${GITHUB_SSH_USER}:${GITHUB_SSH_USER}" "${INSTALL_SCRIPT}"

# Run the installation script
sudo -u "${GITHUB_SSH_USER}" "${INSTALL_SCRIPT}" "${PYTHON_VERSIONS}" || {
    log "ERROR" "Python installation failed"
    rm -f "${INSTALL_SCRIPT}"
    mark_step "Python Installation" "FAILED"
    exit 1
}

# Clean up
rm -f "${INSTALL_SCRIPT}"

# Set global Python version
log "INFO" "Setting global Python version..."

# Create a temporary script for setting global version
GLOBAL_SCRIPT="/home/${GITHUB_SSH_USER}/.pyenv/pyenv_global.sh"
cat > "${GLOBAL_SCRIPT}" << 'EOF'
#!/bin/bash
set -e
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
VERSION="$1"
pyenv global "$VERSION"
EOF

# Set proper permissions
chmod 755 "${GLOBAL_SCRIPT}"
chown "${GITHUB_SSH_USER}:${GITHUB_SSH_USER}" "${GLOBAL_SCRIPT}"

# Run the global version script
sudo -u "${GITHUB_SSH_USER}" "${GLOBAL_SCRIPT}" "${PYTHON_VERSIONS}" || {
    log "ERROR" "Failed to set global Python version"
    rm -f "${GLOBAL_SCRIPT}"
    mark_step "Python Installation" "FAILED"
    exit 1
}

# Clean up
rm -f "${GLOBAL_SCRIPT}"

# Verify installation
log "INFO" "Verifying Python installation..."
PYTHON_VERSION_INSTALLED=$(sudo -u "${GITHUB_SSH_USER}" bash -c "
    export PYENV_ROOT=\"\$HOME/.pyenv\"
    export PATH=\"\$PYENV_ROOT/bin:\$PATH\"
    eval \"\$(pyenv init -)\"
    python --version 2>&1 || echo 'Not installed'
")

if [ "${PYTHON_VERSION_INSTALLED}" = "Not installed" ]; then
    log "ERROR" "Python installation verification failed"
    mark_step "Python Installation" "FAILED"
    exit 1
fi

log "INFO" "Python ${PYTHON_VERSIONS} installed successfully"
log "INFO" "Python version: ${PYTHON_VERSION_INSTALLED}"
mark_step "Python Installation"

############################################################
# Terraform Environment Setup (tfenv)
############################################################
log "INFO" "Installing tfenv..."
debug_log "Starting tfenv installation"

# Install tfenv using git
log "INFO" "Cloning tfenv repository..."
sudo -u "${GITHUB_SSH_USER}" HOME="/home/${GITHUB_SSH_USER}" bash -c '
    set -e
    if [ ! -d "$HOME/.tfenv" ]; then
        git clone --depth=1 https://github.com/tfutils/tfenv.git "$HOME/.tfenv" || {
            echo "Failed to clone tfenv"
            exit 1
        }
    else
        echo "tfenv already installed, updating..."
        cd "$HOME/.tfenv" && git pull
    fi
' || {
    log "ERROR" "tfenv installation failed"
    mark_step "Terraform Installation" "FAILED"
    exit 1
}

# Verify tfenv installation
if ! [ -f "/home/${GITHUB_SSH_USER}/.tfenv/bin/tfenv" ]; then
    log "ERROR" "tfenv binary not found after installation"
    mark_step "Terraform Installation" "FAILED"
    exit 1
fi

# Add tfenv to PATH in shell config
log "INFO" "Configuring tfenv in shell startup files..."
cat >> "/home/${GITHUB_SSH_USER}/.bashrc" << 'EOF'

# tfenv configuration
export PATH="$HOME/.tfenv/bin:$PATH"
EOF

# Verify tfenv functionality
log "INFO" "Verifying tfenv installation..."
TFENV_VERSION=$(sudo -u "${GITHUB_SSH_USER}" bash -c 'export PATH="$HOME/.tfenv/bin:$PATH" && tfenv --version 2>/dev/null') || {
    log "ERROR" "Failed to get tfenv version"
    mark_step "Terraform Installation" "FAILED"
        exit 1
    }
    
log "INFO" "tfenv version: ${TFENV_VERSION}"

# Get available Terraform versions
log "INFO" "Fetching available Terraform versions..."
if [[ "${TF_VERSION}" == "latest" ]]; then
    TF_VERSION=$(sudo -u "${GITHUB_SSH_USER}" bash -c 'export PATH="$HOME/.tfenv/bin:$PATH" && tfenv list-remote | head -n1') || {
        log "ERROR" "Failed to get latest Terraform version"
        mark_step "Terraform Installation" "FAILED"
        exit 1
    }
    log "INFO" "Using latest Terraform version: ${TF_VERSION}"
fi

# Install specified Terraform version
log "INFO" "Installing Terraform ${TF_VERSION}..."
sudo -u "${GITHUB_SSH_USER}" HOME="/home/${GITHUB_SSH_USER}" bash -c "
    set -e
    export PATH=\"\$HOME/.tfenv/bin:\$PATH\"
    tfenv install \"${TF_VERSION}\" || {
        echo 'Failed to install Terraform'
        exit 1
    }
    tfenv use \"${TF_VERSION}\"
" || {
    log "ERROR" "Terraform installation failed"
    mark_step "Terraform Installation" "FAILED"
    exit 1
}

# Verify Terraform installation and functionality
log "INFO" "Verifying Terraform installation..."
TF_VERSION_INSTALLED=$(sudo -u "${GITHUB_SSH_USER}" bash -c 'export PATH="$HOME/.tfenv/bin:$PATH" && terraform --version 2>/dev/null | head -n1') || {
    log "ERROR" "Failed to get Terraform version"
    mark_step "Terraform Installation" "FAILED"
    exit 1
}

if [[ "${TF_VERSION_INSTALLED}" == "Not installed" ]]; then
    log "ERROR" "Terraform installation verification failed"
    mark_step "Terraform Installation" "FAILED"
    exit 1
fi

# Test Terraform functionality
log "INFO" "Testing Terraform functionality..."
TF_TEST=$(sudo -u "${GITHUB_SSH_USER}" bash -c 'export PATH="$HOME/.tfenv/bin:$PATH" && terraform version -json 2>/dev/null') || {
    log "ERROR" "Terraform functionality test failed"
    mark_step "Terraform Installation" "FAILED"
    exit 1
}

log "INFO" "Terraform installation completed successfully:"
log "INFO" "  Version: ${TF_VERSION_INSTALLED}"
log "INFO" "  Full version info: ${TF_TEST}"
mark_step "Terraform Installation"

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

# Install ZSH
log "INFO" "Installing ZSH..."
apt-get install -y zsh || {
    log "ERROR" "ZSH installation failed"
    mark_step "Shell Setup" "FAILED"
    exit 1
}

# Install Oh My Zsh for GITHUB_SSH_USER
log "INFO" "Installing Oh My Zsh..."
sudo -u "${GITHUB_SSH_USER}" bash -c '
    set -e
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || {
            echo "Failed to install Oh My Zsh"
            exit 1
        }
    fi
' || {
    log "ERROR" "Oh My Zsh installation failed"
    mark_step "Shell Setup" "FAILED"
    exit 1
}

# Explicitly set zsh as the default shell for GITHUB_SSH_USER
log "INFO" "Setting zsh as default shell for ${GITHUB_SSH_USER}..."
chsh -s "$(which zsh)" "${GITHUB_SSH_USER}" || {
    log "ERROR" "Failed to set zsh as default shell for ${GITHUB_SSH_USER}"
    mark_step "Shell Setup" "FAILED"
    exit 1
}

# Install Powerlevel10k
    log "INFO" "Installing Powerlevel10k theme..."
sudo -u "${GITHUB_SSH_USER}" bash -c '
    set -e
    if [ ! -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" || {
            echo "Failed to install Powerlevel10k"
            exit 1
        }
    fi
' || {
    log "ERROR" "Powerlevel10k installation failed"
    mark_step "Shell Setup" "FAILED"
    exit 1
}

# Configure ZSH as default shell
log "INFO" "Setting ZSH as default shell..."
chsh -s "$(which zsh)" "${GITHUB_SSH_USER}" || {
    log "ERROR" "Failed to set ZSH as default shell"
    mark_step "Shell Setup" "FAILED"
    exit 1
}

log "INFO" "Shell setup completed successfully"
mark_step "Shell Setup"

# Font Installation (Nerd Fonts)
log "INFO" "Installing Nerd Fonts..."
debug_log "Starting Nerd Fonts installation"

# Create fonts directory
FONT_DIR="/home/${GITHUB_SSH_USER}/.local/share/fonts"
mkdir -p "${FONT_DIR}"
chown -R "${GITHUB_SSH_USER}:${GITHUB_SSH_USER}" "/home/${GITHUB_SSH_USER}/.local"

# Create temporary directory for font installation
TEMP_DIR=$(mktemp -d)
chown "${GITHUB_SSH_USER}:${GITHUB_SSH_USER}" "${TEMP_DIR}"

# Download and install IBM Plex Mono Nerd Font
log "INFO" "Downloading IBM Plex Mono Nerd Font..."
sudo -u "${GITHUB_SSH_USER}" bash -c "
    set -e
    cd \"${TEMP_DIR}\"
    curl -fLo 'IBMPlexMono.zip' \
        https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/IBMPlexMono.zip || {
        echo 'Failed to download font zip'
        exit 1
    }
    unzip -q 'IBMPlexMono.zip' || {
        echo 'Failed to extract font zip'
        exit 1
    }
    # Install all .ttf files
    find . -name '*.ttf' -exec cp {} \"${FONT_DIR}/\" \;
" || {
    log "ERROR" "Font installation failed"
    rm -rf "${TEMP_DIR}"
    mark_step "Font Installation" "FAILED"
    exit 1
}

# Clean up temporary directory
rm -rf "${TEMP_DIR}"

# Ensure fontconfig is installed for fc-cache
apt-get install -y fontconfig || {
    log "ERROR" "Failed to install fontconfig (fc-cache dependency)"
    mark_step "Font Installation" "FAILED"
    exit 1
}

# Update font cache
log "INFO" "Updating font cache..."
fc-cache -f "${FONT_DIR}" || {
    log "ERROR" "Failed to update font cache"
    mark_step "Font Installation" "FAILED"
    exit 1
}

log "INFO" "Font installation completed successfully"
mark_step "Font Installation"

############################################################
# Docker and Service Setup
############################################################
# This section:
# 1. Installs Docker and Docker Compose if not present
# 2. Configures Docker daemon and socket permissions
# 3. Adds user to docker group with immediate activation
# 4. Verifies Docker installation and functionality
# 5. Sets up Docker Compose services from config
#
# Dependencies:
# - apt-get for package installation
# - curl for downloading Docker Compose
# - systemd for service management
#
# Critical paths:
# - Docker socket: /var/run/docker.sock
# - Docker Compose binary: /usr/local/bin/docker-compose
# - Compose directory: ${COMPOSE_DIR} from config
############################################################
log "INFO" "Configuring Docker..."
debug_log "Starting Docker configuration"

# Check if Docker is already installed
if command -v docker &>/dev/null; then
    log "INFO" "Docker is already installed, checking version..."
    DOCKER_VERSION=$(docker --version)
    log "INFO" "Existing Docker version: ${DOCKER_VERSION}"
else
    # Install Docker dependencies
    log "INFO" "Installing Docker dependencies..."
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release || {
        log "ERROR" "Failed to install Docker dependencies"
        mark_step "Docker Setup" "FAILED"
        exit 1
    }

    # Add Docker repository
    log "INFO" "Adding Docker repository..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || {
        log "ERROR" "Failed to add Docker GPG key"
        mark_step "Docker Setup" "FAILED"
        exit 1
    }

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null || {
        log "ERROR" "Failed to add Docker repository"
        mark_step "Docker Setup" "FAILED"
        exit 1
    }

    # Install Docker
    log "INFO" "Installing Docker..."
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io || {
        log "ERROR" "Docker installation failed"
        mark_step "Docker Setup" "FAILED"
        exit 1
    }
fi

# Add user to docker group
log "INFO" "Adding ${GITHUB_SSH_USER} to docker group..."
if ! groups "${GITHUB_SSH_USER}" | grep -q docker; then
    usermod -aG docker "${GITHUB_SSH_USER}" || {
        log "ERROR" "Failed to add user to docker group"
        mark_step "Docker Setup" "FAILED"
        exit 1
    }
    log "INFO" "User added to docker group"
    
    # Fix Docker socket permissions
    log "INFO" "Setting Docker socket permissions..."
    chmod 666 /var/run/docker.sock || {
        log "ERROR" "Failed to set Docker socket permissions"
        mark_step "Docker Setup" "FAILED"
        exit 1
    }
    
    # Activate new group membership for current session
    log "INFO" "Activating new group membership..."
    # Create a temporary script for group activation
    GROUP_SCRIPT="/tmp/docker_group_activate.sh"
    cat > "${GROUP_SCRIPT}" << 'EOF'
#!/bin/bash
set -e
newgrp docker << EONG
docker ps &>/dev/null || {
    echo "Docker access test failed after group activation"
    exit 1
}
EONG
EOF

    chmod +x "${GROUP_SCRIPT}"
    sudo -u "${GITHUB_SSH_USER}" "${GROUP_SCRIPT}" || {
        log "ERROR" "Failed to activate docker group"
        rm -f "${GROUP_SCRIPT}"
        mark_step "Docker Setup" "FAILED"
        exit 1
    }
    rm -f "${GROUP_SCRIPT}"
else
    log "INFO" "User already in docker group"
fi

# Install Docker Compose
log "INFO" "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION="2.24.5"
if ! command -v docker-compose &>/dev/null; then
    log "INFO" "Downloading Docker Compose v${DOCKER_COMPOSE_VERSION}..."
    curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || {
        log "ERROR" "Failed to download Docker Compose"
        mark_step "Docker Setup" "FAILED"
        exit 1
    }
    chmod +x /usr/local/bin/docker-compose || {
        log "ERROR" "Failed to make Docker Compose executable"
        mark_step "Docker Setup" "FAILED"
        exit 1
    }
    log "INFO" "Docker Compose installed successfully"
else
    log "INFO" "Docker Compose already installed"
fi

# Start and enable Docker service
log "INFO" "Starting Docker service..."
systemctl start docker || {
    log "ERROR" "Failed to start Docker service"
    mark_step "Docker Setup" "FAILED"
    exit 1
}

systemctl enable docker || {
    log "ERROR" "Failed to enable Docker service"
    mark_step "Docker Setup" "FAILED"
    exit 1
}

# Verify Docker installation and functionality
log "INFO" "Verifying Docker installation..."
DOCKER_VERSION=$(docker --version) || {
    log "ERROR" "Failed to get Docker version"
    mark_step "Docker Setup" "FAILED"
    exit 1
}

DOCKER_COMPOSE_VERSION=$(docker-compose --version) || {
    log "ERROR" "Failed to get Docker Compose version"
    mark_step "Docker Setup" "FAILED"
    exit 1
}

# Test Docker functionality
log "INFO" "Testing Docker functionality..."
docker run --rm hello-world &>/dev/null || {
    log "ERROR" "Docker functionality test failed"
    mark_step "Docker Setup" "FAILED"
    exit 1
}

log "INFO" "Docker setup completed successfully:"
log "INFO" "  Docker version: ${DOCKER_VERSION}"
log "INFO" "  Docker Compose version: ${DOCKER_COMPOSE_VERSION}"
log "INFO" "  Docker service status: $(systemctl is-active docker)"
log "INFO" "  Docker service enabled: $(systemctl is-enabled docker)"
mark_step "Docker Setup"

############################################################
# Docker Compose Services Preflight Validation (Detailed Reporting)
############################################################
# This section runs before launching services:
# 1. Validates each compose file with 'docker-compose config'
# 2. Checks for required .env file and missing variables
# 3. Checks for required host paths in volumes
# 4. Logs a detailed PASS/FAIL report for each check
# 5. Summarizes all results in a table at the end
#
# Volume Path Validation Strategy:
# - For /storage/docker/* paths:
#   * Only checks if parent directory exists
#   * Docker will create the actual volume directories
#   * Example: For /storage/docker/radarr/config, checks /storage/docker/radarr
# - For other paths (e.g., /storage/media):
#   * Checks if the exact path exists
#   * These are typically media or download directories
#   * Must exist exactly as specified
#
# Dependencies:
# - docker-compose for config validation
# - yq for YAML parsing
# - grep, awk, sed for path extraction
#
# Critical paths:
# - Compose directory: ${COMPOSE_DIR}
# - Docker volume base: /storage/docker
# - Media paths: /storage/media, /storage/downloads
############################################################

############################################################
# Docker Compose Services Launch (only valid files)
############################################################
# This section:
# 1. Creates required Docker volume directories
# 2. Sets appropriate permissions
# 3. Launches services in priority order
# 4. Verifies service status
#
# Volume Directory Structure:
# /storage/docker/
# ├── dockge/
# │   ├── data/     # Dockge application data
# │   └── stacks/   # Dockge stack definitions
# ├── radarr/       # Radarr configuration
# ├── sonarr/       # Sonarr configuration
# ├── lidarr/       # Lidarr configuration
# ├── bazarr/       # Bazarr configuration
# ├── jackett/      # Jackett configuration
# ├── plex/         # Plex configuration
# └── tautulli/     # Tautulli configuration
#
# Directory Creation Strategy:
# - Creates parent directories only
# - Sets ownership to ${GITHUB_SSH_USER}
# - Sets permissions to 755
# - Docker creates actual volume directories
#
# Service Launch Order:
# 1. Dockge (container management)
# 2. Pi-hole (DNS)
# 3. Traefik (reverse proxy)
# 4. VPN (network)
# 5. Torrent stack (downloads)
# 6. Samba (file sharing)
# 7. Plex (media server)
# 8. Other services (in alphabetical order)
#
# Dependencies:
# - Docker daemon running
# - docker-compose installed
# - Valid compose files
# - Proper permissions
#
# Critical paths:
# - Docker socket: /var/run/docker.sock
# - Compose directory: ${COMPOSE_DIR}
# - Volume base: /storage/docker
############################################################

if [ ${#VALID_COMPOSE_FILES[@]} -eq 0 ]; then
    log "ERROR" "No valid compose files to launch after preflight checks."
    mark_step "Docker Compose Setup" "FAILED"
    exit 1
fi

# Create Docker volume directories
log "INFO" "Creating Docker volume directories..."
DOCKER_VOLUME_DIRS=(
    "/storage/docker/dockge/data"
    "/storage/docker/dockge/stacks"
    "/storage/docker/radarr"
    "/storage/docker/sonarr"
    "/storage/docker/lidarr"
    "/storage/docker/bazarr"
    "/storage/docker/jackett"
    "/storage/docker/plex"
    "/storage/docker/tautulli"
)

for dir in "${DOCKER_VOLUME_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        log "INFO" "Creating directory: $dir"
        mkdir -p "$dir" || {
            log "ERROR" "Failed to create directory: $dir"
            mark_step "Docker Compose Setup" "FAILED"
            exit 1
        }
        # Set appropriate permissions
        chown -R "${GITHUB_SSH_USER}:${GITHUB_SSH_USER}" "$dir" || {
            log "ERROR" "Failed to set permissions for directory: $dir"
            mark_step "Docker Compose Setup" "FAILED"
            exit 1
        }
        chmod 755 "$dir" || {
            log "ERROR" "Failed to set mode for directory: $dir"
            mark_step "Docker Compose Setup" "FAILED"
            exit 1
        }
    else
        log "INFO" "Directory already exists: $dir"
    fi
done

# Define launch priority
PRIORITY_FILES=(
    "docker-compose.dockge.yaml"
    "docker-compose.pihole.yaml"
    "docker-compose.traefik.yaml"
    "docker-compose.vpn.yaml"
    "docker-compose.torrent_stack.yaml"
    "docker-compose.samba.yaml"
    "docker-compose.plex.yaml"
)

# Build launch order: priority files first, then the rest
log "INFO" "Organizing services for launch in priority order..."
LAUNCH_ORDER=()
for pf in "${PRIORITY_FILES[@]}"; do
    for f in "${VALID_COMPOSE_FILES[@]}"; do
        if [[ "$(basename "$f")" == "$pf" ]]; then
            LAUNCH_ORDER+=("$f")
            log "INFO" "Added to priority launch: $(basename "$f")"
        fi
    done
done

# Add remaining files in alphabetical order
for f in "${VALID_COMPOSE_FILES[@]}"; do
    skip=0
    for pf in "${PRIORITY_FILES[@]}"; do
        if [[ "$(basename "$f")" == "$pf" ]]; then
            skip=1
            break
        fi
    done
    if [[ $skip -eq 0 ]]; then
        LAUNCH_ORDER+=("$f")
        log "INFO" "Added to standard launch: $(basename "$f")"
    fi
done

# Log launch order
log "INFO" "Docker Compose launch order will be:"
for f in "${LAUNCH_ORDER[@]}"; do
    log "INFO" "  - $(basename "$f")"
done

# Launch services in order
log "INFO" "Launching Docker Compose services in priority order..."
for compose_file in "${LAUNCH_ORDER[@]}"; do
    log "INFO" "Starting services from ${compose_file}..."
    docker-compose -f "${compose_file}" up -d || {
        log "ERROR" "Failed to start services from ${compose_file}"
        log "ERROR" "Check docker-compose logs for details"
        mark_step "Docker Compose Setup" "FAILED"
        exit 1
    }
    log "INFO" "Successfully started services from ${compose_file}"
    
    # Add a small delay between launches to ensure proper startup
    sleep 5
done

# Verify services are running
log "INFO" "Verifying Docker services..."
RUNNING_CONTAINERS=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}")
if [ -z "${RUNNING_CONTAINERS}" ]; then
    log "ERROR" "No containers are running"
    mark_step "Docker Compose Setup" "FAILED"
    exit 1
fi

log "INFO" "Running containers:"
echo "${RUNNING_CONTAINERS}"

log "INFO" "Docker Compose services started successfully"
mark_step "Docker Compose Setup"

############################################################
# Script Completion
############################################################
# Enable exit trap for summary printing
ALLOW_EXIT_TRAP=1
debug_log "Script completed, exit trap enabled"
mark_step "Script execution"
log "INFO" "Script execution completed successfully"
exit 0 