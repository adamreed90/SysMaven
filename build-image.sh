#!/bin/bash

# Exit on error
set -e

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
    exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root or with sudo"
fi

# Configuration variables
ALPINE_VERSION="3.21"
WORK_DIR="alpine-custom"
CUSTOM_ROOTFS="custom-rootfs"

# Required packages
REQUIRED_PACKAGES=(
    squashfs-tools
    xorriso
    wget
    syslinux
    isolinux
    grub-efi-amd64-bin
    mtools
)

log "Starting Alpine Linux Network Boot Image build process..."

# Install required packages
log "Installing required packages..."
apt-get update
apt-get install -y "${REQUIRED_PACKAGES[@]}" || error "Failed to install required packages"

# Create working directory
log "Creating working directory..."
mkdir -p "$WORK_DIR"
cd "$WORK_DIR" || error "Failed to change to working directory"

# Download Alpine Linux base
log "Downloading Alpine Linux minirootfs..."
wget -q "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64/alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz" || error "Failed to download Alpine Linux"

# Create and extract to custom rootfs
log "Creating custom rootfs..."
mkdir -p "$CUSTOM_ROOTFS"
cd "$CUSTOM_ROOTFS" || error "Failed to change to custom rootfs directory"
tar xzf "../alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz" || error "Failed to extract Alpine Linux"

# Prepare chroot environment
log "Preparing chroot environment..."
cp /etc/resolv.conf etc/ || error "Failed to copy resolv.conf"

# Mount virtual filesystems
log "Mounting virtual filesystems..."
mount -t proc none proc || error "Failed to mount proc"
mount -t sysfs none sys || error "Failed to mount sysfs"
mount -t devtmpfs none dev || error "Failed to mount devtmpfs"

# Create chroot script
cat > chroot-script.sh << 'EOF'
#!/bin/sh
set -e

# Configure repositories
cat > /etc/apk/repositories << REPO
https://dl-cdn.alpinelinux.org/alpine/v3.21/main
https://dl-cdn.alpinelinux.org/alpine/v3.21/community
REPO

# Update and install packages
apk update
apk add bash

# Install necessary packages
apk add --no-cache \
    alpine-base \
    linux-lts \
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

# Install .NET 8.0 Runtime dependencies
apk add --no-cache \
    icu-libs \
    krb5-libs \
    libgcc \
    libintl \
    libssl1.1 \
    libstdc++ \
    zlib \
    ca-certificates

# Create dotnet directory
mkdir -p /usr/share/dotnet

# Download and install .NET Runtime directly
cd /usr/share/dotnet
DOTNET_VERSION="8.0.11"
DOTNET_URL="https://download.visualstudio.microsoft.com/download/pr/3a7c5ed3-4c0c-4471-9cb4-2df32847d28f/5ff96f5dd65a188b3365a160ba4592e7/dotnet-runtime-8.0.11-linux-musl-x64.tar.gz"

echo "Downloading .NET Runtime ${DOTNET_VERSION}..."
wget -q --no-check-certificate "$DOTNET_URL" -O dotnet-runtime.tar.gz || {
    echo "Failed to download .NET Runtime, skipping..."
    exit 0  # Continue build without .NET
}

echo "Extracting .NET Runtime..."
tar xzf dotnet-runtime.tar.gz || {
    echo "Failed to extract .NET Runtime, skipping..."
    rm -f dotnet-runtime.tar.gz
    exit 0  # Continue build without .NET
}

rm -f dotnet-runtime.tar.gz
ln -sf /usr/share/dotnet/dotnet /usr/bin/dotnet

# Verify installation
if command -v dotnet >/dev/null 2>&1; then
    echo ".NET Runtime installation successful"
    dotnet --info || true
else
    echo ".NET Runtime installation failed, continuing without .NET"
fi

cd /

# Install mkinitfs and configure
apk add mkinitfs
KERNEL_VERSION=$(ls /lib/modules)
echo "Installing kernel version: $KERNEL_VERSION"

# Configure initramfs features
cat > /etc/mkinitfs/mkinitfs.conf << MKINITFS
features="ata base cdrom squashfs ext4 mmc scsi usb virtio network dhcp"
MKINITFS

# Generate initramfs explicitly for the LTS kernel
KERNEL_VERSION=$(ls /lib/modules)
echo "Generating initramfs for kernel version: $KERNEL_VERSION"

# Configure mkinitfs with additional required features
cat > /etc/mkinitfs/features.d/netboot.modules << EOF
kernel/drivers/net/ethernet/*
kernel/drivers/net/phy/*
kernel/drivers/net/*
kernel/net/*
EOF

# Create chroot script
cat > "custom-rootfs/chroot-script.sh" << 'EOF'
#!/bin/sh
set -e

# Configure repositories
cat > /etc/apk/repositories << REPO
https://dl-cdn.alpinelinux.org/alpine/v3.21/main
https://dl-cdn.alpinelinux.org/alpine/v3.21/community
REPO

# Update and install base packages
apk update
apk add mkinitfs linux-lts

# Configure mkinitfs with additional required features
mkdir -p /etc/mkinitfs/features.d
cat > /etc/mkinitfs/features.d/netboot.modules << NETBOOT
kernel/drivers/net/ethernet/*
kernel/drivers/net/phy/*
kernel/drivers/net/*
kernel/net/*
NETBOOT

# Get kernel version and create initramfs
KERNEL_VERSION=$(ls /lib/modules)
echo "Creating initramfs-lts with network support for kernel $KERNEL_VERSION..."
mkinitfs -n -o /boot/initramfs-lts $KERNEL_VERSION

# Verify initramfs creation
if [ ! -f /boot/initramfs-lts ]; then
    echo "Failed to create initramfs-lts"
    exit 1
fi

# Show resulting files
ls -lh /boot/
EOF

# Make chroot script executable
chmod +x "custom-rootfs/chroot-script.sh"

# Execute chroot script
log "Executing chroot script..."
chroot "custom-rootfs" /chroot-script.sh

# Verify initramfs creation
if [ ! -f /boot/initramfs-lts ]; then
    echo "Failed to create initramfs-lts, attempting fallback method..."
    mkinitfs -n -o /boot/initramfs-lts
fi

# Check final initramfs size
if [ -f /boot/initramfs-lts ]; then
    echo "Verifying initramfs-lts size:"
    ls -lh /boot/initramfs-lts
else
    echo "ERROR: Failed to create initramfs-lts"
    exit 1
fi

# Create service user
adduser -D -h /opt/imaging-service imaging-service
mkdir -p /opt/imaging-service

# Create service startup script
cat > /etc/init.d/imaging-service << 'INIT'
#!/sbin/openrc-run

name="imaging-service"
description="Imaging Service"
command="/usr/bin/dotnet"
command_args="/opt/imaging-service/ImagingService.dll"
directory="/opt/imaging-service"
user="imaging-service"
group="imaging-service"
pidfile="/run/${RC_SVCNAME}.pid"
start_stop_daemon_args="--background --make-pidfile"

depend() {
    need net
    after net
}
INIT

chmod +x /etc/init.d/imaging-service
rc-update add imaging-service default

# Configure serial console
cat > /etc/inittab << INITTAB
::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default
ttyS0::respawn:/sbin/getty -L 115200 ttyS0 vt100
::ctrlaltdel:/sbin/reboot
::shutdown:/sbin/openrc shutdown
INITTAB

# Verify boot files
ls -l /boot/vmlinuz-lts /boot/initramfs-*
EOF

# Make chroot script executable and run it
chmod +x chroot-script.sh
chroot . /bin/sh ./chroot-script.sh || error "Chroot configuration failed"

# Clean up and unmount
log "Cleaning up and unmounting..."
cd ..
umount -l "$CUSTOM_ROOTFS/dev"
umount -l "$CUSTOM_ROOTFS/proc"
umount -l "$CUSTOM_ROOTFS/sys"

# Remove unnecessary files
log "Removing unnecessary files..."
rm -rf "$CUSTOM_ROOTFS/usr/share/man/"* \
       "$CUSTOM_ROOTFS/usr/share/doc/"* \
       "$CUSTOM_ROOTFS/usr/share/info/"* \
       "$CUSTOM_ROOTFS/usr/share/i18n/"* \
       "$CUSTOM_ROOTFS/usr/share/locale/"* \
       "$CUSTOM_ROOTFS/usr/share/zoneinfo/"* \
       "$CUSTOM_ROOTFS/var/cache/apk/"* \
       "$CUSTOM_ROOTFS/var/cache/misc/"* \
       "$CUSTOM_ROOTFS/var/log/"* \
       "$CUSTOM_ROOTFS/tmp/"*

# Create squashfs image
log "Creating squashfs image..."
mksquashfs "$CUSTOM_ROOTFS" alpine-custom.squashfs \
    -comp xz -Xbcj x86 -Xdict-size 1M -b 1M \
    -no-exports -no-recovery -always-use-fragments || error "Failed to create squashfs image"

# Create ISO directory structure
log "Creating ISO directory structure..."
mkdir -p iso/{boot/{syslinux,grub},EFI/BOOT,apks}

# Copy boot files
log "Copying boot files..."
KERNEL_VERSION=$(ls "$CUSTOM_ROOTFS/lib/modules")
cp "$CUSTOM_ROOTFS/boot/vmlinuz-lts" iso/boot/ || error "Failed to copy kernel"

# Try to find and copy the correct initramfs
if [ -f "$CUSTOM_ROOTFS/boot/initramfs-lts" ]; then
    cp "$CUSTOM_ROOTFS/boot/initramfs-lts" iso/boot/ || error "Failed to copy initramfs-lts"
elif [ -f "$CUSTOM_ROOTFS/boot/initramfs-$KERNEL_VERSION" ]; then
    cp "$CUSTOM_ROOTFS/boot/initramfs-$KERNEL_VERSION" iso/boot/initramfs-lts || error "Failed to copy kernel-specific initramfs"
elif [ -f "$CUSTOM_ROOTFS/boot/initramfs-generic" ]; then
    cp "$CUSTOM_ROOTFS/boot/initramfs-generic" iso/boot/initramfs-lts || error "Failed to copy generic initramfs"
else
    error "No suitable initramfs found in $CUSTOM_ROOTFS/boot/"
fi
cp alpine-custom.squashfs iso/boot/

# Copy BIOS boot files
log "Copying BIOS boot files..."
cp /usr/lib/ISOLINUX/isolinux.bin iso/boot/syslinux/
cp /usr/lib/syslinux/modules/bios/{ldlinux.c32,libcom32.c32,libutil.c32,vesamenu.c32} iso/boot/syslinux/

# Create syslinux configuration
log "Creating boot configurations..."
cat > iso/boot/syslinux/syslinux.cfg << 'EOF'
TIMEOUT 20
PROMPT 1
DEFAULT custom_alpine

LABEL custom_alpine
    MENU LABEL Custom Alpine Linux
    KERNEL /boot/vmlinuz-lts
    INITRD /boot/initramfs-lts
    APPEND root=/dev/ram0 console=tty0 console=ttyS0,115200n8 nomodeset quiet modloop=/boot/alpine-custom.squashfs modules=loop,squashfs alpine_dev=loop0
EOF

# Create GRUB configuration
cat > iso/boot/grub/grub.cfg << 'EOF'
set timeout=20
set default=0

menuentry "Custom Alpine Linux" {
    linux /boot/vmlinuz-lts root=/dev/ram0 console=tty0 console=ttyS0,115200n8 nomodeset quiet modloop=/boot/alpine-custom.squashfs modules=loop,squashfs alpine_dev=loop0
    initrd /boot/initramfs-lts
}
EOF

# Create UEFI boot loader
log "Creating UEFI boot loader..."
grub-mkstandalone \
    --format=x86_64-efi \
    --output=iso/EFI/BOOT/BOOTX64.EFI \
    --locales="" \
    --fonts="" \
    "boot/grub/grub.cfg=iso/boot/grub/grub.cfg" || error "Failed to create UEFI boot loader"

# Create UEFI boot disk image
log "Creating UEFI boot disk image..."
dd if=/dev/zero of=iso/boot/efiboot.img bs=1M count=4
mkfs.vfat iso/boot/efiboot.img
LC_ALL=C mmd -i iso/boot/efiboot.img ::/EFI
LC_ALL=C mmd -i iso/boot/efiboot.img ::/EFI/BOOT
LC_ALL=C mcopy -i iso/boot/efiboot.img iso/EFI/BOOT/BOOTX64.EFI ::/EFI/BOOT/

# Create hybrid ISO
log "Creating hybrid ISO..."
xorriso -as mkisofs \
    -o alpine-custom.iso \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "ALPINE_CUSTOM" \
    -eltorito-boot boot/syslinux/isolinux.bin \
    -eltorito-catalog boot/syslinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot \
    -e boot/efiboot.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    iso/ || error "Failed to create ISO"

log "Build completed successfully!"
log "Created ISO: $(pwd)/alpine-custom.iso"
ls -lh alpine-custom.iso
