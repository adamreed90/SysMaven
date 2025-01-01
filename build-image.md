# Alpine Linux Network Boot Image Build Guide

## Prerequisites

- Ubuntu/Debian-based system for building
- Root/sudo access
- At least 4GB free disk space
- Internet connection for downloading packages

## 1. Set Up Build Environment

```bash
# Install required packages
sudo apt-get update
sudo apt-get install -y \
    squashfs-tools \
    xorriso \
    wget \
    syslinux \
    isolinux \
    grub-efi-amd64-bin \
    mtools

# Create working directory
mkdir alpine-custom
cd alpine-custom
```

## 2. Download Alpine Linux Base

```bash
# Download latest Alpine Linux minirootfs
ALPINE_VERSION="3.21"
wget https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64/alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz

# Create work directory and extract
mkdir custom-rootfs
cd custom-rootfs
sudo tar xzf ../alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz
```

## 3. Prepare chroot Environment

```bash
# Copy resolv.conf for network access during chroot
sudo cp /etc/resolv.conf etc/

# Mount necessary filesystems
sudo mount -t proc none proc
sudo mount -t sysfs none sys
sudo mount -t devtmpfs none dev

# Enter chroot with sh (Alpine's default shell)
sudo chroot . /bin/sh
```

## 4. Configure System

```bash
# Inside chroot environment

# Configure repositories
cat > /etc/apk/repositories << EOF
https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main
https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/community
EOF

# Update and add bash
apk update
apk add bash

# Install necessary packages
apk add --no-cache \
    alpine-base \
    linux-lts \
    linux-firmware \
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
wget https://dot.net/v1/dotnet-install.sh
chmod +x dotnet-install.sh
./dotnet-install.sh --runtime dotnet --channel 8.0 --install-dir /usr/share/dotnet
ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet

# Configure mkinitfs for network boot
apk add mkinitfs
KERNEL_VERSION=$(ls /lib/modules)
echo "Installing kernel version: $KERNEL_VERSION"

# Configure mkinitfs features for network boot
cat > /etc/mkinitfs/mkinitfs.conf << EOF
features="ata base cdrom squashfs ext4 mmc scsi usb virtio network dhcp nfs"
modloop=yes
EOF

# Create custom features.d file for network boot
cat > /etc/mkinitfs/features.d/netboot.modules << EOF
kernel/drivers/net/*
kernel/net/*
EOF

# Generate initramfs with network support
mkinitfs -n -o /boot/initramfs-$KERNEL_VERSION $KERNEL_VERSION
ls -l /boot/initramfs-* || echo "Warning: initramfs not found!"

# Create service user
adduser -D -h /opt/imaging-service imaging-service
mkdir -p /opt/imaging-service

# Create service startup script
cat > /etc/init.d/imaging-service << 'EOF'
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
EOF

chmod +x /etc/init.d/imaging-service
rc-update add imaging-service default

# Configure serial console for headless operation
cat > /etc/inittab << EOF
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
EOF

# Verify kernel and initramfs before exiting chroot
echo "Verifying boot files:"
ls -l /boot/vmlinuz-lts /boot/initramfs-*

# Exit chroot
exit
```

[Rest of sections 5-8 remain the same...]
