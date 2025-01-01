#!/bin/bash

# Exit on any error
set -e

# Script configuration
SCRIPT_VERSION="1.0.0"
SCRIPT_NAME=$(basename "$0")
ALPINE_VERSION="3.21"

# Directory structure
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/alpine-custom"
LOG_DIR="${BUILD_DIR}/logs"
LOG_FILE="${LOG_DIR}/setup-$(date +%Y%m%d-%H%M%S).log"
CUSTOM_ROOTFS="${BUILD_DIR}/custom-rootfs"

# Required space in GB
REQUIRED_SPACE=4

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
    
    # Send errors to stderr
    if [[ ${level} == "ERROR" ]]; then
        echo -e "${message}" >&2
    fi
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
    local line_number=$1
    local error_code=$2
    log "ERROR" "Error occurred in script $SCRIPT_NAME at line: ${line_number}, error code: ${error_code}"
    exit 1
}

trap 'error_handler ${LINENO} $?' ERR

# Display script banner
show_banner() {
    cat << "EOF"
    _    _      _            ____        _ _     _ 
   / \  | |_ __(_)_ __   ___| __ ) _   _(_) | __| |
  / _ \ | | '_ \| | '_ \ / _ \  _ \| | | | | |/ _` |
 / ___ \| | |_) | | | | |  __/ |_) | |_| | | | (_| |
/_/   \_\_| .__/|_|_| |_|\___|____/ \__,_|_|_|\__,_|
          |_|                                        
EOF
    echo "Alpine Linux Network Boot Image Build Environment Setup v${SCRIPT_VERSION}"
    echo "--------------------------------------------------------"
}

# Check for root privileges
check_root() {
    log "INFO" "Checking root privileges..."
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
    log_success "Root privileges confirmed"
}

# Check Ubuntu version
check_ubuntu_version() {
    log "INFO" "Checking Ubuntu version..."
    if ! grep -q "Ubuntu 22.04" /etc/os-release; then
        log_error "This script is designed for Ubuntu 22.04"
        exit 1
    fi
    log_success "Ubuntu 22.04 confirmed"
}

# Check available disk space
check_disk_space() {
    log "INFO" "Checking available disk space..."
    local available_space_gb=$(df -BG . | awk 'NR==2 {print $4}' | tr -d 'G')
    
    if [ "${available_space_gb}" -lt "${REQUIRED_SPACE}" ]; then
        log_error "Insufficient disk space. ${REQUIRED_SPACE}GB required, ${available_space_gb}GB available"
        exit 1
    fi
    log_success "Sufficient disk space available: ${available_space_gb}GB"
}

# Install required packages
install_prerequisites() {
    log "INFO" "Installing required packages..."
    
    # Update package list
    if ! apt-get update; then
        log_error "Failed to update package list"
        exit 1
    fi
    
    # Install required packages
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        squashfs-tools \
        xorriso \
        wget \
        syslinux \
        isolinux \
        grub-efi-amd64-bin \
        mtools \
        gdisk \
        || { log_error "Failed to install prerequisites"; exit 1; }
    
    log_success "Prerequisites installed successfully"
}

# Create directory structure
create_directories() {
    log "INFO" "Creating directory structure..."
    
    local dirs=(
        "${BUILD_DIR}"
        "${LOG_DIR}"
        "${CUSTOM_ROOTFS}"
    )
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir" || { log_error "Failed to create directory: $dir"; exit 1; }
        fi
    done
    
    log_success "Directory structure created successfully"
}

# Download Alpine Linux base
download_alpine() {
    log "INFO" "Downloading Alpine Linux ${ALPINE_VERSION}..."
    
    local alpine_url="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64/alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz"
    local alpine_file="${BUILD_DIR}/alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz"
    
    # Download if file doesn't exist
    if [ ! -f "$alpine_file" ]; then
        wget -O "$alpine_file" "$alpine_url" || { 
            log_error "Failed to download Alpine Linux"
            rm -f "$alpine_file"
            exit 1
        }
    else
        log_warning "Alpine Linux archive already exists, skipping download"
    fi
    
    # Verify download integrity
    log "INFO" "Verifying download integrity..."
    if ! gunzip -t "$alpine_file"; then
        log_error "Downloaded file is corrupted"
        rm -f "$alpine_file"
        exit 1
    fi
    
    # Extract Alpine Linux
    log "INFO" "Extracting Alpine Linux..."
    if [ -d "${CUSTOM_ROOTFS}" ] && [ "$(ls -A ${CUSTOM_ROOTFS})" ]; then
        log_warning "Custom rootfs directory is not empty. Cleaning..."
        rm -rf "${CUSTOM_ROOTFS:?}/"*
    fi
    
    tar xzf "$alpine_file" -C "$CUSTOM_ROOTFS" || { 
        log_error "Failed to extract Alpine Linux"
        exit 1
    }
    
    log_success "Alpine Linux downloaded and extracted successfully"
}

# Main function
main() {
    show_banner
    
    # Create log directory if it doesn't exist
    mkdir -p "${LOG_DIR}"
    
    log "INFO" "Starting setup script..."
    
    # Run setup steps
    check_root
    check_ubuntu_version
    check_disk_space
    install_prerequisites
    create_directories
    download_alpine
    
    log_success "Setup completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Review the log file at: ${LOG_FILE}"
    echo "2. Proceed with building the Alpine Linux image"
    echo
}

cleanup_mounts() {
    log "Cleaning up mounts..."
    umount -l "${CUSTOM_ROOTFS}/dev" 2>/dev/null || true
    umount -l "${CUSTOM_ROOTFS}/proc" 2>/dev/null || true
    umount -l "${CUSTOM_ROOTFS}/sys" 2>/dev/null || true
}

#cleanup_mounts
#rm -rf ${BUILD_DIR}
# Run main function
main "$@"
