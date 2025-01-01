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
LOG_FILE="${LOG_DIR}/build-$(date +%Y%m%d-%H%M%S).log"
CUSTOM_ROOTFS="${BUILD_DIR}/custom-rootfs"
CHROOT_SCRIPT="${BUILD_DIR}/chroot_commands.sh"

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
    cleanup_mounts
    exit 1
}

trap 'error_handler ${LINENO} $?' ERR

# Cleanup function
cleanup_mounts() {
    log "INFO" "Cleaning up mounts..."
    local mounts=("dev" "proc" "sys")
    
    for mount in "${mounts[@]}"; do
        if mountpoint -q "${CUSTOM_ROOTFS}/${mount}"; then
            log "INFO" "Unmounting ${mount}..."
            umount -l "${CUSTOM_ROOTFS}/${mount}" || log_warning "Failed to unmount ${mount}"
        fi
    done
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

# Verify build environment
verify_environment() {
    log "INFO" "Verifying build environment..."
    
    # Check if custom rootfs exists and is not empty
    if [ ! -d "${CUSTOM_ROOTFS}" ] || [ ! "$(ls -A ${CUSTOM_ROOTFS})" ]; then
        log_error "Custom rootfs not found or empty. Please run setup script first."
        exit 1
    fi
    
    log_success "Build environment verified"
}

# Prepare chroot environment
prepare_chroot() {
    log "INFO" "Preparing chroot environment..."
    
    # Copy resolv.conf for network access
    cp /etc/resolv.conf "${CUSTOM_ROOTFS}/etc/" || {
        log_error "Failed to copy resolv.conf"
        exit 1
    }
    
    # Mount virtual filesystems
    local mounts=(
        "proc|proc|none"
        "sys|sysfs|none"
        "dev|devtmpfs|none"
    )
    
    for mount in "${mounts[@]}"; do
        IFS="|" read -r dir type opts <<< "${mount}"
        mount_point="${CUSTOM_ROOTFS}/${dir}"
        
        if ! mountpoint -q "${mount_point}"; then
            log "INFO" "Mounting ${dir}..."
            mount -t "${type}" "${opts}" "${mount_point}" || {
                log_error "Failed to mount ${dir}"
                cleanup_mounts
                exit 1
            }
        else
            log_warning "${dir} is already mounted"
        fi
    done
    
    log_success "Chroot environment prepared"
}

# Generate chroot script
generate_chroot_script() {
    log "INFO" "Generating chroot script..."
    
    cat > "${CHROOT_SCRIPT}" << 'EOF'
#!/bin/sh
set -e

# Function to log messages
log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Configure repositories
log_msg "Configuring repositories..."
cat > /etc/apk/repositories << REPOEOF
https://dl-cdn.alpinelinux.org/alpine/v3.21/main
https://dl-cdn.alpinelinux.org/alpine/v3.21/community
REPOEOF

# Update and install base packages
log_msg "Updating package index..."
apk update

log_msg "Installing base packages..."
apk add --no-cache bash linux-lts linux-firmware

# Install necessary packages
log_msg "Installing additional packages..."
apk add --no-cache \
    alpine-base \
    icu \
    krb5-libs \
    libgcc \
    libintl \
    libssl3 \
    libstdc++ \
    zlib \
    busybox-extras \
    nfs-utils \
    partclone \
    parted \
    e2fsprogs \
    e2fsprogs-extra \
    ntfs-3g \
    ntfs-3g-progs \
    dosfstools \
    hdparm \
    smartmontools \
    lsblk \
    util-linux \
    udev \
    pciutils \
    usbutils \
    rsync \
    ddrescue \
    gptfdisk \
    sfdisk \
    dmidecode \
    tar \
    gzip \
    xz \
    lshw \
    nvme-cli \
    fio \
    ipmitool \
    lm-sensors \
    ethtool \
    memtester \
    stress-ng \
    sysstat \
    strace \
    ltrace

# Install .NET 8.0 Runtime
log_msg "Installing .NET Runtime..."
wget https://dot.net/v1/dotnet-install.sh
chmod +x dotnet-install.sh
./dotnet-install.sh --runtime dotnet --channel 8.0 --install-dir /usr/share/dotnet
ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet

# Configure mkinitfs
log_msg "Configuring mkinitfs..."
apk add mkinitfs
KERNEL_VERSION=$(ls /lib/modules)
echo "Kernel version: $KERNEL_VERSION"

# Configure mkinitfs features
log_msg "Setting up mkinitfs configuration..."
cat > /etc/mkinitfs/mkinitfs.conf << MKINITEOF
features="ata base cdrom squashfs ext4 mmc scsi usb virtio network dhcp nfs"
modloop=yes
MKINITEOF

# Create netboot features
log_msg "Creating netboot features..."
mkdir -p /etc/mkinitfs/features.d
cat > /etc/mkinitfs/features.d/netboot.modules << NETBOOTEOF
kernel/drivers/net/*
kernel/net/*
NETBOOTEOF

# Generate initramfs
log_msg "Generating initramfs..."
mkinitfs -n -o /boot/initramfs-$KERNEL_VERSION $KERNEL_VERSION

# Verify initramfs
if [ ! -f "/boot/initramfs-$KERNEL_VERSION" ]; then
    echo "ERROR: initramfs generation failed"
    exit 1
fi

# Create service user
log_msg "Creating service user..."
adduser -D -h /opt/imaging-service imaging-service
mkdir -p /opt/imaging-service

# Configure service
log_msg "Configuring imaging service..."
cat > /etc/init.d/imaging-service << SERVICEEOF
#!/sbin/openrc-run

name="imaging-service"
description="Imaging Service"
command="/usr/bin/dotnet"
command_args="/opt/imaging-service/ImagingService.dll"
directory="/opt/imaging-service"
user="imaging-service"
group="imaging-service"
pidfile="/run/\${RC_SVCNAME}.pid"
start_stop_daemon_args="--background --make-pidfile"

depend() {
    need net
    after net
}
SERVICEEOF

chmod +x /etc/init.d/imaging-service
rc-update add imaging-service default

# Configure serial console
log_msg "Configuring serial console..."
cat > /etc/inittab << INITTABEOF
# System initialization
::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default

# Set up getty on serial console
ttyS0::respawn:/sbin/getty -L 115200 ttyS0 vt100

# Trap CTRL-ALT-DELETE
::ctrlaltdel:/sbin/reboot

# Shutdown
::shutdown:/sbin/openrc shutdown
INITTABEOF

# Verify boot files
log_msg "Verifying boot files..."
ls -l /boot/vmlinuz-lts /boot/initramfs-*

log_msg "Chroot configuration completed successfully"
EOF

    chmod +x "${CHROOT_SCRIPT}"
    log_success "Chroot script generated"
}

# Execute chroot commands
execute_chroot() {
    log "INFO" "Executing chroot commands..."
    
    # Copy chroot script into rootfs
    cp "${CHROOT_SCRIPT}" "${CUSTOM_ROOTFS}/chroot_commands.sh" || {
        log_error "Failed to copy chroot script"
        return 1
    }
    
    # Execute chroot script
    chroot "${CUSTOM_ROOTFS}" /chroot_commands.sh || {
        log_error "Chroot commands failed"
        return 1
    }
    
    # Clean up chroot script
    rm "${CUSTOM_ROOTFS}/chroot_commands.sh"
    
    log_success "Chroot commands executed successfully"
}

# Verify build
verify_build() {
    log "INFO" "Verifying build..."
    
    # Check for essential files
    local required_files=(
        "boot/vmlinuz-lts"
        "boot/initramfs-"
        "etc/init.d/imaging-service"
        "usr/bin/dotnet"
    )
    
    for file in "${required_files[@]}"; do
        if ! ls "${CUSTOM_ROOTFS}/${file}"* 1> /dev/null 2>&1; then
            log_error "Required file not found: ${file}"
            return 1
        fi
    done
    
    log_success "Build verification completed"
}

# Main function
main() {
    echo "Alpine Linux Image Build Script v${SCRIPT_VERSION}"
    echo "----------------------------------------"
    
    # Create log directory if it doesn't exist
    mkdir -p "${LOG_DIR}"
    
    log "INFO" "Starting build script..."
    
    # Run build steps
    check_root
    verify_environment
    prepare_chroot
    generate_chroot_script
    execute_chroot
    verify_build
    cleanup_mounts
    
    log_success "Build completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Review the log file at: ${LOG_FILE}"
    echo "2. Proceed with creating the ISO image"
    echo
}

# Run main function
main "$@"
