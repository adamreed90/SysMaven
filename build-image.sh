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

# Logging functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Error handling
error_handler() {
    log "ERROR: Error occurred in script at line: $1"
    cleanup_mounts
    exit 1
}

trap 'error_handler ${LINENO}' ERR

# Cleanup function
cleanup_mounts() {
    log "Cleaning up mounts..."
    umount -l "${CUSTOM_ROOTFS}/dev" 2>/dev/null || true
    umount -l "${CUSTOM_ROOTFS}/proc" 2>/dev/null || true
    umount -l "${CUSTOM_ROOTFS}/sys" 2>/dev/null || true
}

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    log "This script must be run as root"
    exit 1
fi

# Verify environment
if [ ! -d "${CUSTOM_ROOTFS}" ] || [ ! "$(ls -A ${CUSTOM_ROOTFS})" ]; then
    log "Custom rootfs not found or empty. Please run setup script first."
    exit 1
fi

# Prepare chroot
log "Preparing chroot environment..."
cp /etc/resolv.conf "${CUSTOM_ROOTFS}/etc/"
mount -t proc none "${CUSTOM_ROOTFS}/proc"
mount -t sysfs none "${CUSTOM_ROOTFS}/sys"
mount -t devtmpfs none "${CUSTOM_ROOTFS}/dev"

# Generate chroot script
cat > "${CHROOT_SCRIPT}" << 'EOF'
#!/bin/sh
set -e

# Setup repositories
cat > /etc/apk/repositories << REPOEOF
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
    dotnet8-runtime

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

# Log .NET runtime version
echo ".NET Runtime Version:" >> /var/log/boot/startup.log
dotnet --info >> /var/log/boot/startup.log

# Make the log readable
chmod 644 /var/log/boot/startup.log
BOOTLOG

chmod +x /etc/local.d/10-boot-log.start
rc-update add local default

# Configure root mounting in initramfs
cat > /etc/mkinitfs/mkinitfs.conf << MKINITEOF
features="base network squashfs"
kernel_opts="console=tty0 console=ttyS0,115200 quiet rootfstype=squashfs root=/dev/ram0"
initramfs_features="base virtio network squashfs"
MKINITEOF

# Create custom init script
mkdir -p /etc/mkinitfs/features.d/
cat > /etc/mkinitfs/features.d/custom.modules << 'MODULESEOF'
kernel/drivers/net/ethernet
kernel/net/ipv4
kernel/net/packet
kernel/drivers/virtio
kernel/drivers/block
MODULESEOF

# Setup modloop options
cat > /etc/mkinitfs/modloop.conf << MODLOOPEOF
# Modloop settings
modloop_verify=no
MODLOOPEOF

# Generate initramfs
mkinitfs -c /etc/mkinitfs/mkinitfs.conf -n "$KERNEL_VERSION"

# Configure serial console
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

# Configure network
cat > /etc/network/interfaces << NETEOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
NETEOF

# Enable necessary services
rc-update add networking boot
rc-update add dhcpcd boot

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

# Verify critical files
ls -l /boot/vmlinuz-lts /boot/initramfs-*
EOF

chmod +x "${CHROOT_SCRIPT}"

# Execute chroot script
log "Executing chroot script..."
cp "${CHROOT_SCRIPT}" "${CUSTOM_ROOTFS}/chroot_commands.sh"
chroot "${CUSTOM_ROOTFS}" /chroot_commands.sh
rm "${CUSTOM_ROOTFS}/chroot_commands.sh"

# Cleanup
cleanup_mounts

log "Build completed successfully!"
