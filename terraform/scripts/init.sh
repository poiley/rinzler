#!/bin/bash 

# Set the script to exit on error and enable debugging
set -e
set -x

BRANCH="test"
REPO="rinzler"
GH_USER="poiley"

# Create a log file for debugging
LOG_FILE="/home/poile/init-script.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== INIT SCRIPT STARTED at $(date) ==="
echo "Running as user: $(whoami)"
echo "Home directory: $HOME"
echo "Current directory: $(pwd)"

# Reset Path
cd $HOME
echo "Changed to home directory: $(pwd)"

# Clone the repository
echo "Cloning repository..."
if [ -d "$REPO" ]; then
    echo "Repository already exists, removing it first..."
    rm -rf "$REPO"
fi

git clone -b $BRANCH https://github.com/$GH_USER/$REPO  
echo "Repository cloned successfully"

cd $REPO 
echo "Changed to repository directory: $(pwd)"
echo "Repository contents:"
ls -la

clear

# Check if bootstrap script exists
BOOTSTRAP_SCRIPT="./terraform/scripts/bootstrap-init.sh"
if [ ! -f "$BOOTSTRAP_SCRIPT" ]; then
    echo "ERROR: Bootstrap script not found at $BOOTSTRAP_SCRIPT"
    echo "Available files in terraform/scripts/:"
    ls -la terraform/scripts/ || echo "terraform/scripts/ directory not found"
    exit 1
fi

echo "Bootstrap script found, checking permissions..."
ls -la "$BOOTSTRAP_SCRIPT"

# Make sure it's executable
chmod +x "$BOOTSTRAP_SCRIPT"
echo "Made bootstrap script executable"

# Check if required config files exist
echo "Checking for required configuration files..."
for config_file in "config/bootstrap.yaml" "config/runner.yaml"; do
    if [ -f "$config_file" ]; then
        echo "✓ Found: $config_file"
    else
        echo "✗ Missing: $config_file"
    fi
done

# Run the bootstrap script with detailed logging
echo "=== STARTING BOOTSTRAP SCRIPT at $(date) ==="
echo "Running: sudo $BOOTSTRAP_SCRIPT"

# Run with explicit error handling
if sudo "$BOOTSTRAP_SCRIPT"; then
    echo "=== BOOTSTRAP SCRIPT COMPLETED SUCCESSFULLY at $(date) ==="
else
    EXIT_CODE=$?
    echo "=== BOOTSTRAP SCRIPT FAILED at $(date) with exit code $EXIT_CODE ==="
    echo "Check the bootstrap logs for more details"
    exit $EXIT_CODE
fi

echo "=== INIT SCRIPT COMPLETED at $(date) ===" 