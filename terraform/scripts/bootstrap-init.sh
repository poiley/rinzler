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
############################################################
# Script Execution Order and Dependencies
############################################################
# The script is organized in a specific order to handle dependencies
# and ensure proper initialization. The order is:
#
# 1. Initial Checks (Pre-requisites)
#    - Root privileges verification
#    - SUDO_USER determination
#    - These must run first as they're required for all operations
#
# 2. Logging Setup
#    - Function definitions for logging
#    - Log file initialization
#    - Must be early as logging is used throughout the script
#    - Provides consistent logging before any operations start
#
# 3. Global Variables
#    - Environment setup
#    - Version configurations
#    - Must be after logging setup to properly log version decisions
#
# 4. System Package Installation
#    - Base dependencies
#    - Build tools
#    - Required for subsequent tool installations
#
# 5. Tool Installation Order
#    a. Homebrew
#       - Required for yq installation
#       - Sets up package management
#    b. yq
#       - Required for reading configuration
#       - Must be before any YAML parsing
#    c. Python (via pyenv)
#       - Development environment setup
#       - Requires build tools from step 4
#    d. Terraform (via tfenv)
#       - Infrastructure management setup
#    e. Shell Environment (ZSH + Oh My Zsh)
#       - User shell configuration
#    f. Docker + Compose
#       - Container runtime setup
#       - Service deployment
#
# Critical Dependencies:
# - Homebrew must be installed before yq
# - yq must be installed before any YAML configuration reading
# - Build tools must be installed before Python compilation
# - Docker must be running before compose services start
#
# User Context Transitions:
# - Script starts as root
# - Uses SUDO_USER for initial setup
# - Transitions to GITHUB_SSH_USER for service configuration
#
# Error Handling:
# - Each section has its own error checking
# - Failures are logged and can trigger script termination
# - Critical errors exit immediately
# - Non-critical errors are logged but allow continuation
#
# Logging Strategy:
# - All operations are logged
# - Error conditions include context
# - Success/failure status is tracked
# - Log rotation prevents unbounded growth
#
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

############################################################
# Logging Functions
############################################################
# Enhanced logging function with multiple severity levels and structured output
# Parameters:
#   $1: Log level (INFO/WARN/ERROR/DEBUG) or message if level not specified
#   $2: Message (if $1 is level)
#   $3: Optional context information
# Usage:
#   log "INFO" "Starting process"
#   log "ERROR" "Failed to execute command" "retry_count=3"
#   log "Simple message" (defaults to INFO)
log() {
    local level="INFO"
    local message="$1"
    local context="${3:-}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local script_name="${0##*/}"
    
    # Handle log level if provided
    case "$1" in
        INFO|WARN|ERROR|DEBUG)
        level="$1"
        message="$2"
            ;;
    esac
    
    # Add color coding for console output
    local color_start=""
    local color_end="\033[0m"
    if [ -t 1 ]; then  # Only use colors if outputting to terminal
        case "$level" in
            ERROR) color_start="\033[1;31m" ;;  # Bold Red
            WARN)  color_start="\033[1;33m" ;;  # Bold Yellow
            DEBUG) color_start="\033[1;36m" ;;  # Bold Cyan
            INFO)  color_start="\033[1;32m" ;;  # Bold Green
        esac
    fi
    
    # Add caller information for ERROR and DEBUG levels
    local caller_info=""
    case "$level" in
        ERROR|DEBUG)
            caller_info=" [${script_name}:${LINENO:-unknown}]"
            ;;
    esac
    
    # Add context information if provided
    local context_info=""
    if [ -n "${context}" ]; then
        context_info=" {${context}}"
    fi
    
    # Format log message
    local log_message="=== ${timestamp} === [${level}]${caller_info}${context_info} ${message}"
    local console_message="${color_start}${log_message}${color_end}"
    
    # Always output to console with colors if available
    echo -e "$console_message"
    
    # Try to write to log file if enabled (without color codes)
    if [ "${LOG_TO_FILE:-1}" = "1" ]; then
        if ! echo "$log_message" >> "${LOG_FILE}" 2>/dev/null; then
            echo -e "${color_start}WARNING: Failed to write to log file, disabling file logging${color_end}"
            LOG_TO_FILE=0
        fi
    fi
}

# Debug logging function for execution flow tracking with enhanced context
debug_log() {
    local message="$1"
    local context="${2:-}"
    local line_context="line:${LINENO:-unknown}"
    
    if [ -n "${context}" ]; then
        line_context="${line_context}, ${context}"
    fi
    
    log "DEBUG" "FLOW: $message" "${line_context}"
}

# Function to log command execution with timing
log_command() {
    local description="$1"
    local command="$2"
    local timeout="${3:-}"
    local start_time=$(date +%s)
    
    debug_log "Executing: ${description}" "command='${command}'"
    
    # Execute command with optional timeout
    local output
    local exit_code
    if [ -n "${timeout}" ]; then
        output=$(timeout "${timeout}" bash -c "${command}" 2>&1) || exit_code=$?
    else
        output=$(bash -c "${command}" 2>&1) || exit_code=$?
    fi
    exit_code=${exit_code:-0}
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Log command result
    if [ ${exit_code} -eq 0 ]; then
        log "INFO" "${description} completed in ${duration}s"
    else
        log "ERROR" "${description} failed after ${duration}s" "exit_code=${exit_code}"
        log "DEBUG" "Command output:" "output='${output}'"
    fi
    
    return ${exit_code}
}

# Function to rotate log files if they get too large
rotate_logs() {
    local max_size_mb="${1:-100}"
    local max_size_bytes=$((max_size_mb * 1024 * 1024))
    
    if [ -f "${LOG_FILE}" ]; then
        local current_size
        current_size=$(stat -f%z "${LOG_FILE}" 2>/dev/null || stat -c%s "${LOG_FILE}" 2>/dev/null || echo 0)
        if [ "${current_size}" -gt "${max_size_bytes}" ]; then
            local backup_file="${LOG_FILE}.$(date +%Y%m%d-%H%M%S).bak"
            mv "${LOG_FILE}" "${backup_file}" 2>/dev/null || true
            touch "${LOG_FILE}" 2>/dev/null || true
            log "INFO" "Rotated log file" "old_size=${current_size}bytes,new_file=${backup_file}"
        fi
    fi
}

# Automatically rotate logs every 1000 lines
LOG_LINES_SINCE_ROTATION=0
log_with_rotation() {
    LOG_LINES_SINCE_ROTATION=$((LOG_LINES_SINCE_ROTATION + 1))
    if [ "${LOG_LINES_SINCE_ROTATION}" -ge 1000 ]; then
        rotate_logs
        LOG_LINES_SINCE_ROTATION=0
    fi
    log "$@"
}

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

# Log initial setup information with enhanced context
log "INFO" "Bootstrap initialization started" "version=1.0.0"
log "INFO" "Log file location: ${LOG_FILE}" "permissions=$(stat -c%a "${LOG_FILE}" 2>/dev/null || echo 'unknown')"
log "INFO" "Running as user: ${SUDO_USER}" "groups=$(groups ${SUDO_USER} 2>/dev/null || echo 'unknown')"
log "INFO" "Current directory: $(pwd)" "disk_space=$(df -h . | tail -n1 | awk '{print $4}' 2>/dev/null || echo 'unknown')"

# Remove -e flag to prevent exiting on errors, we'll handle errors ourselves
set -u # Exit on undefined variables

############################################################
# Global Variable Declarations
############################################################
# Initialize tracking variables
FAILED_STEPS=0
SUCCESSFUL_STEPS=0
RESULTS=""
CURRENT_STEP=""
STEP_START_TIME=0

# Version configurations
if [ -f ".python-version" ]; then
    PYTHON_FULL_VERSION=$(cat ".python-version" | tr -d '[:space:]')
    PYTHON_VERSION=$(echo "${PYTHON_FULL_VERSION}" | cut -d. -f1,2)
    log "INFO" "Found .python-version file, using version: ${PYTHON_FULL_VERSION}"
else
    log "WARN" ".python-version not found, using default version 3.12"
    PYTHON_VERSION="3.12"
    PYTHON_FULL_VERSION="${PYTHON_VERSION}"
fi

if [ -f "terraform/.terraform-version" ]; then
    TF_VERSION=$(cat terraform/.terraform-version)
else
    log "WARN" "terraform/.terraform-version not found, using latest stable version"
    TF_VERSION="latest"
fi

# Debug mode toggle for enhanced logging
DEBUG=${DEBUG:-0}

############################################################
# Main Execution Flow
############################################################

# Initial system packages
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
        exit 1
    fi
done

# Log installed versions of critical packages
log "INFO" "Installed versions of critical packages:"
for pkg in zlib1g-dev libssl-dev libffi-dev libreadline-dev; do
    VERSION=$(dpkg-query -W -f='${Version}' "${pkg}" 2>/dev/null)
    log "INFO" "  ${pkg}: ${VERSION}"
done

log "INFO" "=== Initial Setup Completed ==="

# Homebrew installation
log "INFO" "=== Starting Homebrew Installation ==="

# Verify we have a valid SUDO_USER
if [ -z "${SUDO_USER}" ]; then
    log "ERROR" "SUDO_USER is not set. Cannot proceed with Homebrew installation."
    exit 1
fi

# Verify SUDO_USER exists
if ! id "${SUDO_USER}" &>/dev/null; then
    log "ERROR" "User ${SUDO_USER} does not exist. Cannot proceed with Homebrew installation."
    exit 1
fi

# Create Homebrew directory with proper permissions
log "INFO" "Setting up Homebrew directories..."
mkdir -p /home/linuxbrew/.linuxbrew
chown -R "${SUDO_USER}:${SUDO_USER}" /home/linuxbrew

# Install Homebrew as SUDO_USER with proper environment
log "INFO" "Installing Homebrew for user ${SUDO_USER}..."
sudo -u "${SUDO_USER}" bash -c '
    # Set up environment for non-interactive installation
    export NONINTERACTIVE=1
    export HOMEBREW_NO_ANALYTICS=1
    export HOMEBREW_NO_ENV_HINTS=1
    export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
    export HOMEBREW_CELLAR="/home/linuxbrew/.linuxbrew/Cellar"
    export HOMEBREW_REPOSITORY="/home/linuxbrew/.linuxbrew/Homebrew"
    export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
    export MANPATH="/home/linuxbrew/.linuxbrew/share/man:$MANPATH"
    export INFOPATH="/home/linuxbrew/.linuxbrew/share/info:$INFOPATH"
    
    # Run Homebrew installation script
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        echo "Homebrew installation failed"
        exit 1
    }
' || {
    log "ERROR" "Homebrew installation failed"
    exit 1
}

# Verify Homebrew installation and environment
log "INFO" "Verifying Homebrew installation..."
if ! [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
    log "ERROR" "Homebrew binary not found at expected location"
    exit 1
fi

# Add Homebrew to PATH and verify
log "INFO" "Setting up Homebrew environment..."
sudo -u "${SUDO_USER}" bash -c '
    # Set up Homebrew environment
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" || {
        echo "Failed to set up Homebrew environment"
        exit 1
    }
    # Verify Homebrew functionality
    brew --version || {
        echo "Failed to get Homebrew version"
        exit 1
    }
' || {
    log "ERROR" "Failed to set up Homebrew environment"
    exit 1
}

# Get Homebrew version for logging
BREW_VERSION=$(sudo -u "${SUDO_USER}" bash -c 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && brew --version') || {
    log "ERROR" "Failed to get Homebrew version"
    exit 1
}

# Log Homebrew environment for debugging
log "INFO" "Homebrew environment details:"
log "INFO" "  Version: ${BREW_VERSION}"
log "INFO" "  Path: $(which brew)"
log "INFO" "  Home: $(brew --prefix)"
log "INFO" "  Cellar: /home/linuxbrew/.linuxbrew/Cellar"
log "INFO" "  Repository: /home/linuxbrew/.linuxbrew/Homebrew"

log "INFO" "=== Homebrew Installation Completed ==="

# After Homebrew installation, update PATH to include Homebrew binary directory
export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"

############################################################
# Helper Functions
############################################################
# Function to log messages with timestamp and level
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}"
}

# Function for debug logging
debug_log() {
    local message="$1"
    if [[ "${DEBUG}" == "true" ]]; then
        log "DEBUG" "${message}"
    fi
}

# Function to mark a step as complete or failed
mark_step() {
    local step="$1"
    local status="${2:-DONE}"
    log "INFO" "=== ${step} ${status} ==="
}

# Function to read YAML values using yq
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

# Function to read secrets using yq with GITHUB_SSH_USER context
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

# yq installation
log "INFO" "=== Installing yq ==="

# Install yq using Homebrew
log "INFO" "Installing yq via Homebrew..."
sudo -u "${SUDO_USER}" bash -c 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && brew install yq' || {
    log "ERROR" "yq installation failed"
    exit 1
}

# Verify yq installation and functionality
log "INFO" "Verifying yq installation..."
YQ_PATH=$(sudo -u "${SUDO_USER}" bash -c 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && which yq') || {
    log "ERROR" "yq not found in PATH"
    exit 1
}

# Get and verify yq version
YQ_VERSION=$(sudo -u "${SUDO_USER}" bash -c 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && yq --version') || {
    log "ERROR" "Failed to get yq version"
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
    exit 1
}

if [[ -z "${YQ_TEST}" ]]; then
    log "ERROR" "yq test output was empty"
    rm -f "${TEST_YAML}"
    exit 1
fi

if [[ "${YQ_TEST}" != "value" ]]; then
    log "ERROR" "yq test output mismatch: expected 'value', got '${YQ_TEST}'"
    rm -f "${TEST_YAML}"
    exit 1
fi

rm -f "${TEST_YAML}"
log "INFO" "yq installation and verification completed successfully"

log "INFO" "=== yq Installation Completed ==="

# GitHub user setup
log "INFO" "=== Reading GitHub Configuration ==="

# Verify config file exists
if [ ! -f "config/runner.yaml" ]; then
    log "ERROR" "Configuration file 'config/runner.yaml' not found"
    exit 1
fi

# Critical: First YAML read to get GITHUB_SSH_USER
log "INFO" "Reading GitHub configuration..."
GITHUB_OWNER=$(read_yaml "config/runner.yaml" ".runner.github.owner")
if [[ -z "${GITHUB_OWNER}" ]]; then
    log "ERROR" "Failed to read GitHub owner from config"
    exit 1
fi

REPOSITORY_NAME=$(read_yaml "config/runner.yaml" ".runner.github.repo_name")
if [[ -z "${REPOSITORY_NAME}" ]]; then
    log "ERROR" "Failed to read repository name from config"
    exit 1
fi

GITHUB_SSH_USER=$(read_yaml "config/runner.yaml" ".runner.github.ssh.user")
if [[ -z "${GITHUB_SSH_USER}" ]]; then
    log "ERROR" "Failed to read GITHUB_SSH_USER from config"
    exit 1
fi

# Verify user exists
if ! id "${GITHUB_SSH_USER}" &>/dev/null; then
    log "ERROR" "User ${GITHUB_SSH_USER} does not exist"
    exit 1
fi

# Log configuration details
log "INFO" "Successfully read GitHub configuration:"
log "INFO" "  Owner: ${GITHUB_OWNER}"
log "INFO" "  Repository: ${REPOSITORY_NAME}"
log "INFO" "  SSH User: ${GITHUB_SSH_USER}"
log "INFO" "  User Home: $(eval echo ~${GITHUB_SSH_USER})"
log "INFO" "  User Groups: $(groups ${GITHUB_SSH_USER})"

log "INFO" "=== GitHub User Setup Completed ==="

# Python setup
log "INFO" "=== Starting Python Setup ==="

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

# Set build optimization flags
log "INFO" "Configuring Python build optimizations..."

# Use all available CPU cores for compilation
export PYTHON_BUILD_MAKE_OPTS="-j$(nproc)"
log "INFO" "Using $(nproc) CPU cores for compilation"

# Configure build options for better build time
export PYTHON_CONFIGURE_OPTS="--enable-shared --without-lto"
log "INFO" "Build configured with shared libraries, without LTO"

# Set up local cache to avoid redownloading
export PYTHON_BUILD_CACHE_PATH="/home/${GITHUB_SSH_USER}/.cache/pyenv"
if [ ! -d "${PYTHON_BUILD_CACHE_PATH}" ]; then
    mkdir -p "${PYTHON_BUILD_CACHE_PATH}"
    chown -R "${GITHUB_SSH_USER}:${GITHUB_SSH_USER}" "$(dirname "${PYTHON_BUILD_CACHE_PATH}")"
fi
log "INFO" "Using build cache at ${PYTHON_BUILD_CACHE_PATH}"

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
    exit 1
fi

log "INFO" "Found matching Python version: ${PYTHON_FULL_VERSION}"
log "INFO" "Verifying version string format..."

# Verify the version format is valid (major.minor.patch)
if ! echo "${PYTHON_FULL_VERSION}" | grep -qE "^[0-9]+\.[0-9]+\.[0-9]+$"; then
    log "ERROR" "Selected version '${PYTHON_FULL_VERSION}' does not match expected format"
    log "ERROR" "Expected format: major.minor.patch (e.g., 3.12.10)"
    exit 1
fi

# Extract and verify major.minor matches expected version
DETECTED_VERSION=$(echo "${PYTHON_FULL_VERSION}" | cut -d. -f1,2)
if [ "${DETECTED_VERSION}" != "${PYTHON_VERSION}" ]; then
    log "ERROR" "Version '${PYTHON_FULL_VERSION}' does not match expected version ${PYTHON_VERSION}.x"
    exit 1
fi

log "INFO" "Version string format verified"
log "INFO" "Proceeding with installation..."

# Install Python with build environment
log "INFO" "Installing Python ${PYTHON_FULL_VERSION}..."

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
    exit 1
fi

log "INFO" "Python ${PYTHON_VERSIONS} installed successfully"
log "INFO" "Python version: ${PYTHON_VERSION_INSTALLED}"

log "INFO" "=== Python Setup Completed ==="

# Terraform Environment Setup (tfenv)
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
    exit 1
}

# Verify tfenv installation
if ! [ -f "/home/${GITHUB_SSH_USER}/.tfenv/bin/tfenv" ]; then
    log "ERROR" "tfenv binary not found after installation"
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
        exit 1
    }
    
log "INFO" "tfenv version: ${TFENV_VERSION}"

# Get available Terraform versions
log "INFO" "Fetching available Terraform versions..."
if [[ "${TF_VERSION}" == "latest" ]]; then
    TF_VERSION=$(sudo -u "${GITHUB_SSH_USER}" bash -c 'export PATH="$HOME/.tfenv/bin:$PATH" && tfenv list-remote | head -n1') || {
        log "ERROR" "Failed to get latest Terraform version"
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
    exit 1
}

# Verify Terraform installation and functionality
log "INFO" "Verifying Terraform installation..."
TF_VERSION_INSTALLED=$(sudo -u "${GITHUB_SSH_USER}" bash -c 'export PATH="$HOME/.tfenv/bin:$PATH" && terraform --version 2>/dev/null | head -n1') || {
    log "ERROR" "Failed to get Terraform version"
    exit 1
}

if [[ "${TF_VERSION_INSTALLED}" == "Not installed" ]]; then
    log "ERROR" "Terraform installation verification failed"
    exit 1
fi

# Test Terraform functionality
log "INFO" "Testing Terraform functionality..."
TF_TEST=$(sudo -u "${GITHUB_SSH_USER}" bash -c 'export PATH="$HOME/.tfenv/bin:$PATH" && terraform version -json 2>/dev/null') || {
    log "ERROR" "Terraform functionality test failed"
    exit 1
}

log "INFO" "Terraform installation completed successfully:"
log "INFO" "  Version: ${TF_VERSION_INSTALLED}"
log "INFO" "  Full version info: ${TF_TEST}"

log "INFO" "=== Terraform Installation Completed ==="

# Shell Environment Setup (ZSH + Oh My Zsh)
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
    exit 1
}

# Explicitly set zsh as the default shell for GITHUB_SSH_USER
log "INFO" "Setting zsh as default shell for ${GITHUB_SSH_USER}..."
chsh -s "$(which zsh)" "${GITHUB_SSH_USER}" || {
    log "ERROR" "Failed to set zsh as default shell for ${GITHUB_SSH_USER}"
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
    exit 1
}

# Configure ZSH as default shell
log "INFO" "Setting ZSH as default shell..."
chsh -s "$(which zsh)" "${GITHUB_SSH_USER}" || {
    log "ERROR" "Failed to set ZSH as default shell"
    exit 1
}

log "INFO" "Shell setup completed successfully"

log "INFO" "=== Shell Setup Completed ==="

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
    exit 1
}

# Clean up temporary directory
rm -rf "${TEMP_DIR}"

# Ensure fontconfig is installed for fc-cache
apt-get install -y fontconfig || {
    log "ERROR" "Failed to install fontconfig (fc-cache dependency)"
    exit 1
}

# Update font cache
log "INFO" "Updating font cache..."
fc-cache -f "${FONT_DIR}" || {
    log "ERROR" "Failed to update font cache"
    exit 1
}

log "INFO" "Font installation completed successfully"

log "INFO" "=== Font Installation Completed ==="

# Docker and Service Setup
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
        exit 1
    }

    # Add Docker repository
    log "INFO" "Adding Docker repository..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || {
        log "ERROR" "Failed to add Docker GPG key"
        exit 1
    }

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null || {
        log "ERROR" "Failed to add Docker repository"
        exit 1
    }

    # Install Docker
    log "INFO" "Installing Docker..."
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io || {
        log "ERROR" "Docker installation failed"
        exit 1
    }
fi

# Add user to docker group
log "INFO" "Adding ${GITHUB_SSH_USER} to docker group..."
if ! groups "${GITHUB_SSH_USER}" | grep -q docker; then
    usermod -aG docker "${GITHUB_SSH_USER}" || {
        log "ERROR" "Failed to add user to docker group"
        exit 1
    }
    log "INFO" "User added to docker group"
    
    # Fix Docker socket permissions
    log "INFO" "Setting Docker socket permissions..."
    chmod 666 /var/run/docker.sock || {
        log "ERROR" "Failed to set Docker socket permissions"
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
        exit 1
    }
    chmod +x /usr/local/bin/docker-compose || {
        log "ERROR" "Failed to make Docker Compose executable"
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
    exit 1
}

systemctl enable docker || {
    log "ERROR" "Failed to enable Docker service"
    exit 1
}

# Verify Docker installation and functionality
log "INFO" "Verifying Docker installation..."
DOCKER_VERSION=$(docker --version) || {
    log "ERROR" "Failed to get Docker version"
    exit 1
}

DOCKER_COMPOSE_VERSION=$(docker-compose --version) || {
    log "ERROR" "Failed to get Docker Compose version"
    exit 1
}

# Test Docker functionality
log "INFO" "Testing Docker functionality..."
docker run --rm hello-world &>/dev/null || {
    log "ERROR" "Docker functionality test failed"
    exit 1
}

log "INFO" "Docker setup completed successfully:"
log "INFO" "  Docker version: ${DOCKER_VERSION}"
log "INFO" "  Docker Compose version: ${DOCKER_COMPOSE_VERSION}"
log "INFO" "  Docker service status: $(systemctl is-active docker)"
log "INFO" "  Docker service enabled: $(systemctl is-enabled docker)"

log "INFO" "=== Docker Setup Completed ==="

# Docker Compose Services Preflight Validation
log "INFO" "=== Starting Docker Compose Validation ==="

# Initialize arrays for compose files
declare -a VALID_COMPOSE_FILES=()
declare -a INVALID_COMPOSE_FILES=()

# Find all docker-compose files
COMPOSE_DIR="compose"
if [ ! -d "${COMPOSE_DIR}" ]; then
    log "WARN" "Compose directory '${COMPOSE_DIR}' not found, skipping Docker Compose setup"
    exit 0
fi

# Validate each compose file
log "INFO" "Validating Docker Compose files..."
while IFS= read -r -d '' compose_file; do
    log "INFO" "Checking ${compose_file}..."
    if docker-compose -f "${compose_file}" config >/dev/null 2>&1; then
        VALID_COMPOSE_FILES+=("${compose_file}")
        log "INFO" "  ✓ Valid: $(basename "${compose_file}")"
    else
        INVALID_COMPOSE_FILES+=("${compose_file}")
        log "WARN" "  ✗ Invalid: $(basename "${compose_file}")"
    fi
done < <(find "${COMPOSE_DIR}" -type f -name "docker-compose*.y*ml" -print0)

# Log validation results
log "INFO" "Docker Compose validation results:"
log "INFO" "  Valid files: ${#VALID_COMPOSE_FILES[@]}"
log "INFO" "  Invalid files: ${#INVALID_COMPOSE_FILES[@]}"

if [ ${#VALID_COMPOSE_FILES[@]} -eq 0 ]; then
    log "WARN" "No valid compose files found in ${COMPOSE_DIR}, skipping Docker Compose setup"
    exit 0
fi

log "INFO" "=== Docker Compose Validation Completed ==="

# Create Docker volume directories
log "INFO" "Creating Docker volume directories..."
DOCKER_VOLUME_DIRS=(
    # Dockge directories
    "/storage/docker/dockge/data"
    "/storage/docker/dockge/stacks"
    # Media service directories
    "/storage/docker/radarr"
    "/storage/docker/sonarr"
    "/storage/docker/lidarr"
    "/storage/docker/bazarr"
    "/storage/docker/jackett"
    "/storage/docker/plex"
    "/storage/docker/tautulli"
    # Pi-hole specific directories
    "/storage/docker/pihole/etc-pihole"
    "/storage/docker/pihole/etc-dnsmasq.d"
    # VPN and network directories
    "/storage/docker/vpn"
    "/storage/docker/traefik"
    # Torrent directories
    "/storage/docker/qbittorrent/config"
    "/storage/docker/qbittorrent/downloads"
)

# Create directories with proper permissions
for dir in "${DOCKER_VOLUME_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        log "INFO" "Creating directory: $dir"
        mkdir -p "$dir" || {
            log "ERROR" "Failed to create directory: $dir"
            exit 1
        }
        # Set appropriate permissions
        chown -R "${GITHUB_SSH_USER}:${GITHUB_SSH_USER}" "$dir" || {
            log "ERROR" "Failed to set permissions for directory: $dir"
            exit 1
        }
        chmod 755 "$dir" || {
            log "ERROR" "Failed to set mode for directory: $dir"
            exit 1
        }
    else
        log "INFO" "Directory already exists: $dir"
        # Ensure correct permissions even for existing directories
        chown -R "${GITHUB_SSH_USER}:${GITHUB_SSH_USER}" "$dir" 2>/dev/null || log "WARN" "Could not update ownership of existing directory: $dir"
        chmod 755 "$dir" 2>/dev/null || log "WARN" "Could not update permissions of existing directory: $dir"
    fi
done

# Create any required parent directories
log "INFO" "Creating required parent directories..."
PARENT_DIRS=(
    "/storage/media"
    "/storage/downloads"
    "/storage/backups"
)

for dir in "${PARENT_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        log "INFO" "Creating parent directory: $dir"
        mkdir -p "$dir" || {
            log "ERROR" "Failed to create parent directory: $dir"
            exit 1
        }
        chown "${GITHUB_SSH_USER}:${GITHUB_SSH_USER}" "$dir" || {
            log "ERROR" "Failed to set permissions for parent directory: $dir"
            exit 1
        }
        chmod 755 "$dir" || {
            log "ERROR" "Failed to set mode for parent directory: $dir"
            exit 1
        }
    else
        log "INFO" "Parent directory already exists: $dir"
    fi
done

log "INFO" "All required directories created and configured"

# Docker Compose Service Launch
log "INFO" "=== Starting Docker Compose Services ==="

# Define service launch order based on dependencies
declare -a SERVICE_ORDER=(
    "docker-compose.traefik.yaml"        # Core networking
    "docker-compose.vpn.yaml"            # VPN service
    "docker-compose.monitoring.yaml"      # Monitoring stack
    "docker-compose.dockge.yaml"         # Container management
    "docker-compose.pihole.yaml"         # DNS service
    "docker-compose.flaresolverr.yaml"   # Cloudflare resolver
    "docker-compose.plex.yaml"           # Media server
    "docker-compose.tautulli.yaml"       # Plex monitoring
    "docker-compose.radarr.yaml"         # Movies
    "docker-compose.sonarr.yaml"         # TV Shows
    "docker-compose.lidarr.yaml"         # Music
    "docker-compose.bazarr.yaml"         # Subtitles
    "docker-compose.jackett.yaml"        # Torrent indexer
    "docker-compose.torrent_stack.yaml"  # Torrent client
    "docker-compose.samba.yaml"          # File sharing
)

# Function to start a compose service
start_compose_service() {
    local compose_file="$1"
    local service_name=$(basename "${compose_file}" .yaml)
    
    log "INFO" "Starting ${service_name}..."
    if [ -f "${COMPOSE_DIR}/${compose_file}" ]; then
        cd "${COMPOSE_DIR}" && \
        sudo -u "${GITHUB_SSH_USER}" docker-compose -f "${compose_file}" up -d || {
            log "ERROR" "Failed to start ${service_name}"
            return 1
        }
        log "INFO" "Successfully started ${service_name}"
        # Wait for containers to be healthy
        sleep 5
    else
        log "WARN" "Compose file not found: ${compose_file}"
        return 1
    fi
}

# Start services in order
log "INFO" "Launching services in priority order..."
for compose_file in "${SERVICE_ORDER[@]}"; do
    start_compose_service "${compose_file}"
done

# Verify all services are running
log "INFO" "Verifying service health..."
cd "${COMPOSE_DIR}"
for compose_file in "${SERVICE_ORDER[@]}"; do
    if [ -f "${compose_file}" ]; then
        service_name=$(basename "${compose_file}" .yaml)
        log "INFO" "Checking ${service_name}..."
        sudo -u "${GITHUB_SSH_USER}" docker-compose -f "${compose_file}" ps --format json | grep -q "running" || {
            log "WARN" "${service_name} may not be running properly"
        }
    fi
done

# Final status check
log "INFO" "All services launched. Current status:"
sudo -u "${GITHUB_SSH_USER}" docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

log "INFO" "=== Docker Compose Services Started ==="

############################################################
# Script Completion
############################################################
# Log completion
log "INFO" "Script execution completed successfully"
exit 0 