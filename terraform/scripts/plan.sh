#!/bin/bash

# Exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to print status
print_status() {
    echo -e "${YELLOW}==>${NC} $1"
}

# Function to print success
print_success() {
    echo -e "${GREEN}==>${NC} $1"
}

# Function to print error
print_error() {
    echo -e "${RED}==>${NC} $1"
}

# Function to cleanup temporary files
cleanup() {
    print_status "Cleaning up temporary files..."
    if [ -f "/tmp/terraform.tfvars" ]; then
        rm -f "/tmp/terraform.tfvars"
    fi
    if [ -f "${ENVIRONMENT}.plan" ]; then
        rm -f "${ENVIRONMENT}.plan"
    fi
    if [ -f "${ENVIRONMENT}-plan.txt" ]; then
        rm -f "${ENVIRONMENT}-plan.txt"
    fi
    print_success "Cleanup complete"
}

# Check if environment is set
check_environment() {
    if [ -z "${ENVIRONMENT}" ]; then
        print_error "ENVIRONMENT variable is not set. Please set it to 'dev' or 'test'"
        exit 1
    fi
    
    if [[ "${ENVIRONMENT}" != "dev" && "${ENVIRONMENT}" != "test" ]]; then
        print_error "ENVIRONMENT must be either 'dev' or 'test'"
        exit 1
    fi
    
    print_success "Using ${ENVIRONMENT} environment"
}

# Check if required commands exist
check_requirements() {
    print_status "Checking requirements..."
    
    local missing=()
    
    for cmd in terraform yq; do
        if ! command -v $cmd &> /dev/null; then
            missing+=($cmd)
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        print_error "Missing required commands: ${missing[*]}"
        exit 1
    fi
    
    print_success "All requirements met"
}

# Run Terraform plan
run_terraform_plan() {
    print_status "Running Terraform plan for ${ENVIRONMENT} environment..."
    
    # Get absolute path of terraform directory
    TERRAFORM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    cd "$TERRAFORM_DIR"
    
    # Generate terraform.tfvars and get its path
    print_status "Generating terraform.tfvars..."
    TFVARS_FILE="/tmp/terraform.tfvars"
    if ! "${TERRAFORM_DIR}/scripts/generate-tfvars.sh" > /dev/null; then
        print_error "Failed to generate terraform.tfvars"
        exit 1
    fi
    
    # Verify the file exists and is readable
    if [ ! -f "$TFVARS_FILE" ]; then
        print_error "terraform.tfvars file not found at: $TFVARS_FILE"
        exit 1
    fi
    
    print_status "Using terraform.tfvars at: $TFVARS_FILE"
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Format check and fix if needed
    print_status "Checking format..."
    if ! terraform fmt -check -recursive -diff; then
        print_status "Formatting..."
        terraform fmt -recursive
    fi
    
    # Validate
    print_status "Validating configuration..."
    if ! terraform validate; then
        print_error "Validation failed"
        exit 1
    fi
    
    # Plan with terraform.tfvars
    print_status "Creating plan..."
    if ! terraform plan -var-file="$TFVARS_FILE" -out="${ENVIRONMENT}.plan" -lock=false; then
        print_error "Plan creation failed"
        exit 1
    fi
    
    # Save plan to file for review
    print_status "Saving plan to file..."
    if ! terraform show -no-color "${ENVIRONMENT}.plan" > "${ENVIRONMENT}-plan.txt"; then
        print_error "Failed to save plan to file"
        exit 1
    fi
    
    print_success "Plan saved to terraform/${ENVIRONMENT}-plan.txt"
    print_status "Review the plan to ensure it matches your expectations"
    
    print_success "Plan completed"
}

# Main execution
main() {
    print_status "Starting Terraform plan..."
    
    check_environment
    check_requirements
    run_terraform_plan
    
    print_success "Plan completed successfully"
    cleanup
}

# Run main function with all arguments
main "$@" 