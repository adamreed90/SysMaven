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
    cleanup_mounts
    exit 1
}

trap 'error_handler ${LINENO}' ERR

# Cleanup function
cleanup_mounts() {
    log "INFO" "Cleaning up mounts..."
    umount -l "${CUSTOM_ROOTFS}/dev" 2>/dev/null || true
    umount -l "${CUSTOM_ROOTFS}/proc" 2>/dev/null || true
    umount -l "${CUSTOM_ROOTFS}/sys" 2>/dev/null || true
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

# Verify environment
verify_environment() {
    log "INFO" "Verifying build environment..."
    if [ ! -d "${CUSTOM_ROOTFS}" ] || [ ! "$(ls -A ${CUSTOM_ROOTFS})" ]; then
        log_error "Custom rootfs not found or empty. Please run build-prep.sh first."
        exit 1
    fi
    log_success "Build environment verified"
}

# Prepare chroot environment
prepare_chroot() {
    log "INFO" "Preparing chroot environment..."
    cp /etc/resolv.conf "${CUSTOM_ROOTFS}/etc/"
    mount -t proc none "${CUSTOM_ROOTFS}/proc"
    mount -t sysfs none "${CUSTOM_ROOTFS}/sys"
    mount -t devtmpfs none "${CUSTOM_ROOTFS}/dev"
    log_success "Chroot environment prepared"
}

# Generate chroot script
generate_chroot_script() {
    log "INFO" "Generating chroot script..."
    
    cat > "${CHROOT_SCRIPT}" << 'EOF'
#!/bin/sh
set -e

# Setup repositories
cat > /etc/apk/repositories << 'REPOEOF'
https://dl-cdn.alpinelinux.org/alpine/v3.21/main
https://dl-cdn.alpinelinux.org/alpine/v3.21/community
REPOEOF

# Update and install base packages
apk update
apk add --no-cache \
    alpine-base \
    linux-lts \
    mkinitfs \
    openrc \
    dhcpcd \
    bash \
    e2fsprogs \
    util-linux \
    parted \
    dosfstools \
    gptfdisk \
    cfdisk \
    sfdisk \
    efibootmgr \
    hvtools \
    dotnet8-runtime

# Configure mkinitfs
cat > /etc/mkinitfs/mkinitfs.conf << 'MKINITEOF'
features="base network squashfs cdrom virtio"
kernel_opts="console=tty0 console=ttyS0,115200 quiet rootfstype=squashfs"
initramfs_features="base virtio network squashfs cdrom"
MKINITEOF

# Create directory for custom initramfs features
mkdir -p /etc/mkinitfs/features.d/

# Setup custom modules
cat > /etc/mkinitfs/features.d/custom.modules << 'MODULESEOF'
kernel/drivers/net/ethernet
kernel/net/ipv4
kernel/net/packet
kernel/drivers/virtio
kernel/drivers/block
kernel/drivers/cdrom
kernel/drivers/ata
kernel/drivers/scsi/sr_mod
kernel/drivers/scsi/sd_mod
kernel/fs/squashfs
MODULESEOF

# Create boot logging script
cat > /etc/local.d/10-boot-log.start << 'BOOTLOG'
#!/bin/sh

# Create log directory if it doesn't exist
mkdir -p /var/log/boot

# Get system information
echo "=== Boot Log $(date) ===" > /var/log/boot/startup.log
echo "Hostname: $(hostname)" >> /var/log/boot/startup.log
echo "Kernel: $(uname -r)" >> /var/log/boot/startup.log
echo "Network Interfaces:" >> /var/log/boot/startup.log
ip addr show >> /var/log/boot/startup.log
echo "Memory Info:" >> /var/log/boot/startup.log
free -m >> /var/log/boot/startup.log
echo "Service Status:" >> /var/log/boot/startup.log
rc-status >> /var/log/boot/startup.log
echo "Mount Points:" >> /var/log/boot/startup.log
mount >> /var/log/boot/startup.log
echo "Block Devices:" >> /var/log/boot/startup.log
lsblk >> /var/log/boot/startup.log

# Log .NET runtime version
echo ".NET Runtime Version:" >> /var/log/boot/startup.log
dotnet --info >> /var/log/boot/startup.log

# Make the log readable
chmod 644 /var/log/boot/startup.log
BOOTLOG

chmod +x /etc/local.d/10-boot-log.start
rc-update add local default

# Setup system for DVD boot
mkdir -p /media/cdrom
cat > /etc/fstab << 'FSTABEOF'
/dev/cdrom  /media/cdrom  iso9660  ro,noauto  0 0
FSTABEOF

# Configure serial console
cat > /etc/inittab << 'INITTABEOF'
# System initialization
::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default

# Set up getty
tty1::respawn:/sbin/getty 38400 tty1
tty2::respawn:/sbin/getty 38400 tty2
tty3::respawn:/sbin/getty 38400 tty3
ttyS0::respawn:/sbin/getty -L 115200 ttyS0 vt100

# Trap CTRL-ALT-DELETE
::ctrlaltdel:/sbin/reboot

# Shutdown
::shutdown:/sbin/openrc shutdown
INITTABEOF

# Configure network
cat > /etc/network/interfaces << 'NETEOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
NETEOF

# Enable necessary services
rc-update add networking boot
rc-update add dhcpcd boot
rc-update add hv_fcopy_daemon default
rc-update add hv_kvp_daemon default
rc-update add hv_vss_daemon default

# Create service directory
mkdir -p /opt/imaging-service
adduser -D -h /opt/imaging-service imaging-service
chown imaging-service:imaging-service /opt/imaging-service

# Create service configuration
cat > /etc/init.d/imaging-service << 'SERVICEEOF'
#!/sbin/openrc-run

name="imaging-service"
description="Imaging Service"
command="/usr/bin/dotnet"
command_args="/opt/imaging-service/ImagingService.dll"
directory="/opt/imaging-service"
user="imaging-service"
group="imaging-service"
pidfile="/run/${RC_SVCNAME}.pid"
output_log="/var/log/imaging-service/service.log"
error_log="/var/log/imaging-service/error.log"
start_stop_daemon_args="--background --make-pidfile"

start_pre() {
    # Create log directory
    mkdir -p /var/log/imaging-service
    chown ${user}:${group} /var/log/imaging-service
    
    # Log startup
    echo "=== Service Starting $(date) ===" >> "$output_log"
    echo "Environment: $(printenv)" >> "$output_log"
}

depend() {
    need net
    after net
}
SERVICEEOF

# Create service log directory
mkdir -p /var/log/imaging-service
chown imaging-service:imaging-service /var/log/imaging-service

chmod +x /etc/init.d/imaging-service
rc-update add imaging-service default

# Check for existing initramfs-lts
echo "Checking boot files..."
if [ ! -f "/boot/initramfs-lts" ]; then
    echo "No existing initramfs-lts found, generating new one..."
    KERNEL_VERSION=$(ls /lib/modules)
    echo "Kernel version: ${KERNEL_VERSION}"
    echo "Contents of /boot before initramfs generation:"
    ls -la /boot/

    # Try to generate initramfs with current kernel version
    if ! mkinitfs "${KERNEL_VERSION}"; then
        echo "Failed to generate initramfs"
        exit 1
    fi
fi

echo "Contents of /boot:"
ls -la /boot/

# Verify critical files exist
echo "Verifying boot files..."
for file in vmlinuz-lts initramfs-lts; do
    if [ ! -f "/boot/${file}" ]; then
        echo "Critical file missing: /boot/${file}"
        ls -la /boot/
        exit 1
    fi
    echo "Found: /boot/${file}"
done
EOF

    chmod +x "${CHROOT_SCRIPT}"
    log_success "Chroot script generated"
}

# Execute chroot script
execute_chroot_script() {
    log "INFO" "Executing chroot script..."
    cp "${CHROOT_SCRIPT}" "${CUSTOM_ROOTFS}/chroot_commands.sh"
    chroot "${CUSTOM_ROOTFS}" /chroot_commands.sh
    rm "${CUSTOM_ROOTFS}/chroot_commands.sh"
    log_success "Chroot script executed"
}

# Main function
main() {
    echo "Alpine Linux Image Build Script v${SCRIPT_VERSION}"
    echo "----------------------------------------"
    
    # Create log directory if it doesn't exist
    mkdir -p "${LOG_DIR}"
    
    log "INFO" "Starting image build..."
    
    check_root
    verify_environment
    prepare_chroot
    generate_chroot_script
    execute_chroot_script
    cleanup_mounts
    
    log_success "Image build completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Review the log file at: ${LOG_FILE}"
    echo "2. Proceed with ISO creation using build-iso.sh"
    echo
}

# Run main function
main "$@"
