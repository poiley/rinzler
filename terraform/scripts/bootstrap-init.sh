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
#
# CHECKPOINT SYSTEM:
# The script implements a checkpoint system to track progress and enable
# recovery from failures. Checkpoints are stored in:
#   ~/.bootstrap/checkpoints/
# 
# Each major step creates a checkpoint file containing:
# - Timestamp of completion
# - Status (SUCCESS/FAILED)
# - Environment state
# - Last successful operation
#
# To resume from a checkpoint, run with:
#   RESUME=1 sudo ./bootstrap-init.sh
#
# To force clean run:
#   CLEAN=1 sudo ./bootstrap-init.sh
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
    PYTHON_VERSION=$(cat .python-version)
else
    log "WARN" ".python-version not found, using default version 3.12"
    PYTHON_VERSION="3.12"
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
# Checkpoint System Setup
############################################################
# Initialize checkpoint directory
CHECKPOINT_DIR="/home/${SUDO_USER}/.bootstrap/checkpoints"
mkdir -p "${CHECKPOINT_DIR}" 2>/dev/null || true
chmod 755 "${CHECKPOINT_DIR}" 2>/dev/null || true

# Checkpoint management functions
create_checkpoint() {
    local step_name="$1"
    local status="${2:-SUCCESS}"
    local checkpoint_file="${CHECKPOINT_DIR}/${step_name// /_}.checkpoint"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Ensure checkpoint directory exists and is writable
    if ! [ -d "${CHECKPOINT_DIR}" ] || ! [ -w "${CHECKPOINT_DIR}" ]; then
        log "WARN" "Cannot write to checkpoint directory" "dir=${CHECKPOINT_DIR}"
        return 1
    }
    
    # Create checkpoint with metadata
    {
        echo "TIMESTAMP=${timestamp}"
        echo "STATUS=${status}"
        echo "STEP=${step_name}"
        echo "PWD=$(pwd)"
        echo "USER=${SUDO_USER}"
        echo "LAST_LOG=$(tail -n 1 "${LOG_FILE}" 2>/dev/null || echo 'No log available')"
    } > "${checkpoint_file}" 2>/dev/null || {
        log "WARN" "Failed to create checkpoint file" "file=${checkpoint_file}"
        return 1
    }
    
    debug_log "Created checkpoint for: ${step_name}" "status=${status}"
    return 0
}

check_checkpoint() {
    local step_name="$1"
    local checkpoint_file="${CHECKPOINT_DIR}/${step_name// /_}.checkpoint"
    
    # Skip checkpoint check if CLEAN=1
    if [ "${CLEAN:-0}" = "1" ]; then
        return 1
    }
    
    # Check if checkpoint exists and is valid
    if [ -f "${checkpoint_file}" ] && [ "${RESUME:-0}" = "1" ]; then
        local status
        status=$(grep '^STATUS=' "${checkpoint_file}" 2>/dev/null | cut -d'=' -f2)
        if [ "${status}" = "SUCCESS" ]; then
            debug_log "Found valid checkpoint" "step=${step_name},status=${status}"
            return 0
        fi
        debug_log "Found invalid checkpoint" "step=${step_name},status=${status}"
    fi
    
    return 1
}

clear_checkpoints() {
    if [ "${CLEAN:-0}" = "1" ]; then
        debug_log "Clearing all checkpoints" "dir=${CHECKPOINT_DIR}"
        if [ -d "${CHECKPOINT_DIR}" ]; then
            rm -rf "${CHECKPOINT_DIR:?}"/* 2>/dev/null || {
                log "WARN" "Failed to clear checkpoints" "dir=${CHECKPOINT_DIR}"
                return 1
            }
        fi
    fi
    return 0
}

# Clear checkpoints if CLEAN=1
clear_checkpoints

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
for dir in "${LOG_DIRS}"; do
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
# Parameters:
#   $1: Message
#   $2: Optional context information
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
# Parameters:
#   $1: Command description
#   $2: Command to execute
#   $3: Optional timeout in seconds
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
# Parameters:
#   $1: Maximum size in MB (default: 100)
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

# Log initial setup information with enhanced context
log "INFO" "Bootstrap initialization started" "version=1.0.0"
log "INFO" "Log file location: ${LOG_FILE}" "permissions=$(stat -c%a "${LOG_FILE}" 2>/dev/null || echo 'unknown')"
log "INFO" "Running as user: ${SUDO_USER}" "groups=$(groups ${SUDO_USER} 2>/dev/null || echo 'unknown')"
log "INFO" "Current directory: $(pwd)" "disk_space=$(df -h . | tail -n1 | awk '{print $4}' 2>/dev/null || echo 'unknown')"

############################################################
# Main Execution Flow
############################################################

# Clear checkpoints if requested
if [ "${CLEAN:-0}" = "1" ]; then
    log "INFO" "Cleaning previous checkpoints" "clean_mode=true"
    clear_checkpoints
fi

# Initial system packages
start_step "Initial System Setup" "packages=curl,openssl"
{
    # ... existing initial setup code ...
} || error_handler $? ${LINENO}
mark_step "Initial System Setup"

# Homebrew installation
start_step "Homebrew Installation" "user=${SUDO_USER}"
{
    # ... existing Homebrew installation code ...
} || error_handler $? ${LINENO}
mark_step "Homebrew Installation"

# yq installation
start_step "yq Installation" "version=latest"
{
    # ... existing yq installation code ...
} || error_handler $? ${LINENO}
mark_step "yq Installation"

# GitHub user setup
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
#
# CHECKPOINT SYSTEM:
# The script implements a checkpoint system to track progress and enable
# recovery from failures. Checkpoints are stored in:
#   ~/.bootstrap/checkpoints/
# 
# Each major step creates a checkpoint file containing:
# - Timestamp of completion
# - Status (SUCCESS/FAILED)
# - Environment state
# - Last successful operation
#
# To resume from a checkpoint, run with:
#   RESUME=1 sudo ./bootstrap-init.sh
#
# To force clean run:
#   CLEAN=1 sudo ./bootstrap-init.sh
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
    PYTHON_VERSION=$(cat .python-version)
else
    log "WARN" ".python-version not found, using default version 3.12"
    PYTHON_VERSION="3.12"
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
# Checkpoint System Setup
############################################################
# Initialize checkpoint directory
CHECKPOINT_DIR="/home/${SUDO_USER}/.bootstrap/checkpoints"
mkdir -p "${CHECKPOINT_DIR}" 2>/dev/null || true
chmod 755 "${CHECKPOINT_DIR}" 2>/dev/null || true

# Checkpoint management functions
create_checkpoint() {
    local step_name="$1"
    local status="${2:-SUCCESS}"
    local checkpoint_file="${CHECKPOINT_DIR}/${step_name// /_}.checkpoint"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Ensure checkpoint directory exists and is writable
    if ! [ -d "${CHECKPOINT_DIR}" ] || ! [ -w "${CHECKPOINT_DIR}" ]; then
        log "WARN" "Cannot write to checkpoint directory" "dir=${CHECKPOINT_DIR}"
        return 1
    }
    
    # Create checkpoint with metadata
    {
        echo "TIMESTAMP=${timestamp}"
        echo "STATUS=${status}"
        echo "STEP=${step_name}"
        echo "PWD=$(pwd)"
        echo "USER=${SUDO_USER}"
        echo "LAST_LOG=$(tail -n 1 "${LOG_FILE}" 2>/dev/null || echo 'No log available')"
    } > "${checkpoint_file}" 2>/dev/null || {
        log "WARN" "Failed to create checkpoint file" "file=${checkpoint_file}"
        return 1
    }
    
    debug_log "Created checkpoint for: ${step_name}" "status=${status}"
    return 0
}

check_checkpoint() {
    local step_name="$1"
    local checkpoint_file="${CHECKPOINT_DIR}/${step_name// /_}.checkpoint"
    
    # Skip checkpoint check if CLEAN=1
    if [ "${CLEAN:-0}" = "1" ]; then
        return 1
    }
    
    # Check if checkpoint exists and is valid
    if [ -f "${checkpoint_file}" ] && [ "${RESUME:-0}" = "1" ]; then
        local status
        status=$(grep '^STATUS=' "${checkpoint_file}" 2>/dev/null | cut -d'=' -f2)
        if [ "${status}" = "SUCCESS" ]; then
            debug_log "Found valid checkpoint" "step=${step_name},status=${status}"
            return 0
        fi
        debug_log "Found invalid checkpoint" "step=${step_name},status=${status}"
    fi
    
    return 1
}

clear_checkpoints() {
    if [ "${CLEAN:-0}" = "1" ]; then
        debug_log "Clearing all checkpoints" "dir=${CHECKPOINT_DIR}"
        if [ -d "${CHECKPOINT_DIR}" ]; then
            rm -rf "${CHECKPOINT_DIR:?}"/* 2>/dev/null || {
                log "WARN" "Failed to clear checkpoints" "dir=${CHECKPOINT_DIR}"
                return 1
            }
        fi
    fi
    return 0
}

# Clear checkpoints if CLEAN=1
clear_checkpoints

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
for dir in "${LOG_DIRS}"; do
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
# Parameters:
#   $1: Message
#   $2: Optional context information
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
# Parameters:
#   $1: Command description
#   $2: Command to execute
#   $3: Optional timeout in seconds
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
# Parameters:
#   $1: Maximum size in MB (default: 100)
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

# Log initial setup information with enhanced context
log "INFO" "Bootstrap initialization started" "version=1.0.0"
log "INFO" "Log file location: ${LOG_FILE}" "permissions=$(stat -c%a "${LOG_FILE}" 2>/dev/null || echo 'unknown')"
log "INFO" "Running as user: ${SUDO_USER}" "groups=$(groups ${SUDO_USER} 2>/dev/null || echo 'unknown')"
log "INFO" "Current directory: $(pwd)" "disk_space=$(df -h . | tail -n1 | awk '{print $4}' 2>/dev/null || echo 'unknown')"

############################################################
# Main Execution Flow
############################################################

# Clear checkpoints if requested
if [ "${CLEAN:-0}" = "1" ]; then
    log "INFO" "Cleaning previous checkpoints" "clean_mode=true"
    clear_checkpoints
fi

# Initial system packages
start_step "Initial System Setup" "packages=curl,openssl"
{
    # ... existing initial setup code ...
} || error_handler $? ${LINENO}
mark_step "Initial System Setup"

# Homebrew installation
start_step "Homebrew Installation" "user=${SUDO_USER}"
{
    # ... existing Homebrew installation code ...
} || error_handler $? ${LINENO}
mark_step "Homebrew Installation"

# yq installation
start_step "yq Installation" "version=latest"
{
    # ... existing yq installation code ...
} || error_handler $? ${LINENO}
mark_step "yq Installation"

# GitHub user setup
start_step "GitHub User Setup" "config_file=config/runner.yaml"
{
    # ... existing GitHub user setup code ...
} || error_handler $? ${LINENO}
mark_step "GitHub User Setup"

# Python setup
start_step "Python Setup" "version=${PYTHON_VERSION}"
{
    # ... existing Python setup code ...
} || error_handler $? ${LINENO}
mark_step "Python Setup"

# Terraform setup
start_step "Terraform Installation" "version=${TF_VERSION}"
{
    # ... existing Terraform setup code ...
} || error_handler $? ${LINENO}
mark_step "Terraform Installation"

# Shell setup
start_step "Shell Setup" "shell=zsh,theme=powerlevel10k"
{
    # ... existing shell setup code ...
} || error_handler $? ${LINENO}
mark_step "Shell Setup"

# Font installation
start_step "Font Installation" "font=IBMPlexMono"
{
    # ... existing font installation code ...
} || error_handler $? ${LINENO}
mark_step "Font Installation"

# Docker setup
start_step "Docker Setup" "version=latest"
{
    # ... existing Docker setup code ...
} || error_handler $? ${LINENO}
mark_step "Docker Setup"

# Enable exit trap for normal completion
ALLOW_EXIT_TRAP=1

# Create final checkpoint
create_checkpoint "Bootstrap Complete" "SUCCESS"

# Log completion
log "INFO" "Bootstrap initialization completed successfully" "steps_completed=${SUCCESSFUL_STEPS}"

exit 0 