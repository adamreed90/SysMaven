#!/bin/bash

# Exit on any error
set -e

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to log errors and exit
error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
    exit 1
}

# Function to clean up on exit
cleanup() {
    log "Cleaning up..."
    if [ -d "$WORK_DIR/$CUSTOM_ROOTFS" ]; then
        umount -l "$WORK_DIR/$CUSTOM_ROOTFS/dev" 2>/dev/null || true
        umount -l "$WORK_DIR/$CUSTOM_ROOTFS/proc" 2>/dev/null || true
        umount -l "$WORK_DIR/$CUSTOM_ROOTFS/sys" 2>/dev/null || true
    fi
}

# Register cleanup function
trap cleanup EXIT

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
fi

# Configuration variables
ALPINE_VERSION="3.21"
WORK_DIR="alpine-custom"
CUSTOM_ROOTFS="custom-rootfs"

# Fix /dev/null if needed
log "Checking and fixing /dev/null..."
if [ ! -c /dev/null ] || [ ! -w /dev/null ]; then
    rm -f /dev/null
    mknod -m 666 /dev/null c 1 3
fi

# Install required packages
log "Installing required packages..."
export DEBIAN_FRONTEND=noninteractive

# First install gpg
apt-get -o Dpkg::Options::="--force-confold" install --reinstall -y gpg gpgv

# Then install other required packages
apt-get -qq update
apt-get -o Dpkg::Options::="--force-confold" install -y \
    squashfs-tools \
    xorriso \
    wget \
    syslinux \
    isolinux \
    grub-efi-amd64-bin \
    mtools || error "Failed to install required packages"

# Create and enter working directory
log "Creating working directory..."
mkdir -p "$WORK_DIR"
cd "$WORK_DIR" || error "Failed to enter working directory"

# Download Alpine Linux base
log "Downloading Alpine Linux minirootfs..."
wget -q "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64/alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz" || \
    error "Failed to download Alpine Linux"

# Create and extract to custom rootfs
log "Creating custom rootfs..."
mkdir -p "$CUSTOM_ROOTFS"
cd "$CUSTOM_ROOTFS" || error "Failed to enter custom rootfs directory"
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
log "Creating chroot script..."
cat > chroot-script.sh << 'EOF'
#!/bin/sh
set -e

# Configure repositories
cat > /etc/apk/repositories << REPO
https://dl-cdn.alpinelinux.org/alpine/v3.21/main
https://dl-cdn.alpinelinux.org/alpine/v3.21/community
REPO

# Update and install base packages
apk update
apk add \
    alpine-base \
    linux-lts \
    mkinitfs \
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

# Configure mkinitfs with additional required features
mkdir -p /etc/mkinitfs/features.d
cat > /etc/mkinitfs/features.d/netboot.modules << NETBOOT
kernel/drivers/net/ethernet/*
kernel/drivers/net/phy/*
kernel/drivers/net/*
kernel/net/*
NETBOOT

cat > /etc/mkinitfs/mkinitfs.conf << MKINITFS
features="ata base cdrom squashfs ext4 mmc scsi usb virtio network dhcp"
MKINITFS

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

# Make chroot script executable and run it
chmod +x chroot-script.sh
log "Executing chroot script..."
chroot . /chroot-script.sh || error "Chroot configuration failed"

# Return to working directory
cd ..

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
cp "$CUSTOM_ROOTFS/boot/vmlinuz-lts" iso/boot/ || error "Failed to copy kernel"
cp "$CUSTOM_ROOTFS/boot/initramfs-lts" iso/boot/ || error "Failed to copy initramfs"
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
