#!/bin/bash

# Exit on any error
set -e

# Script configuration
SCRIPT_VERSION="1.0.0"
SCRIPT_NAME=$(basename "$0")

# Directory structure
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/../src"
BUILD_DIR="${SCRIPT_DIR}/../build"
LOG_DIR="${BUILD_DIR}/logs"
LOG_FILE="${LOG_DIR}/deploy-$(date +%Y%m%d-%H%M%S).log"
DEPLOY_DIR="/opt/network-imaging"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log() {
    local level=$1
    shift
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] $*"
    echo -e "${message}" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}$*${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}$*${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}$*${NC}" | tee -a "$LOG_FILE"
}

# Error handling
error_handler() {
    log_error "Error occurred in script at line: $1"
    exit 1
}

trap 'error_handler ${LINENO}' ERR

# Check for root privileges
check_root() {
    log "INFO" "Checking root privileges..."
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
    log_success "Root privileges confirmed"
}

# Verify environment
verify_environment() {
    log "INFO" "Verifying deployment environment..."
    if [ ! -d "${SRC_DIR}" ]; then
        log_error "Source directory not found: ${SRC_DIR}"
        exit 1
    fi
    log_success "Deployment environment verified"
}

# Create necessary directories
create_directories() {
    log "INFO" "Creating necessary directories..."
    mkdir -p "${DEPLOY_DIR}"
    log_success "Directories created"
}

# Deploy the project
deploy_project() {
    log "INFO" "Deploying the project..."
    cp -r "${BUILD_DIR}/Release/net8.0/publish/"* "${DEPLOY_DIR}/"
    log_success "Project deployed successfully"
}

# Main function
main() {
    echo "Deploy Script v${SCRIPT_VERSION}"
    echo "-----------------------------"
    
    # Create log directory if it doesn't exist
    mkdir -p "${LOG_DIR}"
    
    log "INFO" "Starting deployment process..."
    
    check_root
    verify_environment
    create_directories
    deploy_project
    
    log_success "Deployment process completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Review the log file at: ${LOG_FILE}"
    echo
}

# Run main function
main "$@"
