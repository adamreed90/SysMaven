# Complete Alpine Linux Network Boot Image Build Guide

## 1. Set Up Build Environment

```bash
# Install required packages
sudo apt-get update
sudo apt-get install -y \
    squashfs-tools \
    xorriso \
    wget \
    syslinux \
    isolinux

# Create working directory
mkdir alpine-custom
cd alpine-custom
```

## 2. Download Alpine Linux Base

```bash
# Download latest Alpine Linux minirootfs
ALPINE_VERSION="3.21"
wget https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/x86_64/alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz

# Create a work directory and extract
mkdir custom-rootfs
cd custom-rootfs
sudo tar xzf ../alpine-minirootfs-${ALPINE_VERSION}.0-x86_64.tar.gz
```

## 3. Prepare and Enter chroot Environment

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

## 4. Configure System in chroot

```bash
# Configure repositories
cat > /etc/apk/repositories << EOF
https://dl-cdn.alpinelinux.org/alpine/edge/main
https://dl-cdn.alpinelinux.org/alpine/edge/community
https://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF

# Update and add bash
apk update
apk add bash

# Now install all necessary packages
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

# Install .NET 8.0 Runtime
wget https://dot.net/v1/dotnet-install.sh
chmod +x dotnet-install.sh
./dotnet-install.sh --runtime dotnet --channel 8.0 --install-dir /usr/share/dotnet
ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet

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

# Exit chroot
exit
```

## 5. Clean Up and Unmount

```bash
# Ensure proper unmounting of virtual filesystems
cd ..
sudo umount -l custom-rootfs/dev
sudo umount -l custom-rootfs/proc
sudo umount -l custom-rootfs/sys

# Remove unnecessary files
cd custom-rootfs
sudo rm -rf \
    usr/share/man/* \
    usr/share/doc/* \
    usr/share/info/* \
    usr/share/i18n/* \
    usr/share/locale/* \
    usr/share/zoneinfo/* \
    var/cache/apk/* \
    var/cache/misc/* \
    var/log/* \
    tmp/*

cd ..
```

## 6. Create Boot Images

```bash
# Create squashfs image with optimized compression
sudo mksquashfs custom-rootfs alpine-custom.squashfs -comp xz -Xbcj x86 -Xdict-size 1M -b 1M -no-exports -no-recovery -always-use-fragments

# Copy kernel and create initial ramdisk
mkdir -p bootfiles
sudo cp custom-rootfs/boot/vmlinuz-lts bootfiles/
sudo cp custom-rootfs/boot/initramfs-lts bootfiles/

# Create ISO directory structure
mkdir -p iso/boot/syslinux
mkdir -p iso/apks

# Copy boot files
sudo cp bootfiles/vmlinuz-lts iso/boot/
sudo cp bootfiles/initramfs-lts iso/boot/
sudo cp alpine-custom.squashfs iso/boot/

# Install syslinux for ISO creation
sudo apt-get install -y syslinux isolinux syslinux-utils

# Copy syslinux files
sudo cp /usr/lib/ISOLINUX/isolinux.bin iso/boot/syslinux/
sudo cp /usr/lib/syslinux/modules/bios/ldlinux.c32 iso/boot/syslinux/
sudo cp /usr/lib/syslinux/modules/bios/libcom32.c32 iso/boot/syslinux/
sudo cp /usr/lib/syslinux/modules/bios/libutil.c32 iso/boot/syslinux/
sudo cp /usr/lib/syslinux/modules/bios/vesamenu.c32 iso/boot/syslinux/

# Create syslinux configuration
cat > iso/boot/syslinux/syslinux.cfg << EOF
TIMEOUT 20
PROMPT 1
DEFAULT genti

LABEL genti
    MENU LABEL Custom Alpine Linux
    KERNEL /boot/vmlinuz-lts
    INITRD /boot/initramfs-lts
    APPEND root=/dev/ram0 console=tty0 console=ttyS0,115200n8 nomodeset quiet modloop=/boot/alpine-custom.squashfs modules=loop,squashfs alpine_dev=loop0
EOF

# Create ISO
sudo xorriso -as mkisofs \
    -o alpine-custom.iso \
    -b boot/syslinux/isolinux.bin \
    -c boot/syslinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -l -J -R \
    -V "ALPINE_CUSTOM" \
    iso/

# Make ISO bootable (hybrid ISO)
sudo isohybrid alpine-custom.iso
```

## 7. iPXE Boot Configuration

Create an iPXE script that your service will serve:

```
#!ipxe

# Network configuration
dhcp
set ipaddr ${net0/ip}

# Report boot status to control service (optional)
chain --timeout 5000 http://your-control-service/api/boot-status?ip=${ipaddr} || goto boot

:boot
# Boot the kernel and initramfs with squashfs
kernel http://your-image-server/vmlinuz-lts root=/dev/ram0 ip=dhcp \
    console=tty0 console=ttyS0,115200n8 \
    nomodeset panic=30 quiet loglevel=3 ipv6.disable=1 \
    modloop=http://your-image-server/alpine-custom.squashfs \
    modules=loop,squashfs alpine_dev=loop0
initrd http://your-image-server/initramfs-custom
boot
```

## 8. For Rebuilds

Before rebuilding the image:

```bash
# Ensure nothing is mounted
sudo umount -l custom-rootfs/dev || true
sudo umount -l custom-rootfs/proc || true
sudo umount -l custom-rootfs/sys || true

# Remove previous build artifacts
sudo rm -f alpine-custom.squashfs

# Clean temporary directories
sudo rm -rf custom-rootfs/var/cache/*
sudo rm -rf custom-rootfs/var/log/*
sudo rm -rf custom-rootfs/var/tmp/*
sudo rm -rf custom-rootfs/tmp/*
sudo rm -rf custom-rootfs/run/*
```

Then proceed with the build process from step 3 (mounting and chroot).
