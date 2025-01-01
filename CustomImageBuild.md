# Minimal Alpine Linux Network Boot Image Build Guide

## Prerequisites
- Ubuntu 22.04 host system
- Root or sudo access
- Internet connection

## 1. Set Up Build Environment

```bash
# Install required packages
sudo apt-get update
sudo apt-get install -y \
    squashfs-tools \
    xorriso \
    wget

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
# Configure repositories
cat > /etc/apk/repositories << EOF
https://dl-cdn.alpinelinux.org/alpine/edge/main
https://dl-cdn.alpinelinux.org/alpine/edge/community
https://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF

# Update and add bash
apk update
apk add bash

# Install all necessary packages
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

## 5. Create Network Boot Image

```bash
# Create squashfs image
cd ..
sudo mksquashfs custom-rootfs alpine-custom.squashfs -comp xz -b 1M

# Copy kernel and create initial ramdisk
mkdir -p bootfiles
cp custom-rootfs/boot/vmlinuz-lts bootfiles/
cp custom-rootfs/boot/initramfs-lts bootfiles/
```

## 6. Network Boot Configuration

The .NET control service should serve an iPXE script similar to:

```
#!ipxe

# Network configuration
dhcp
set ipaddr ${net0/ip}

# Boot the kernel and initramfs
kernel http://your-image-server/vmlinuz-lts root=/dev/ram0 ip=dhcp console=tty0 console=ttyS0,115200n8 nomodeset panic=30 quiet loglevel=3 ipv6.disable=1
initrd http://your-image-server/initramfs-custom
boot
```

## Final Steps

1. Deploy your compiled .NET service to `/opt/imaging-service/` in the image
2. Host the following files on your HTTP server:
   - vmlinuz-lts
   - initramfs-custom
   - alpine-custom.squashfs

## Notes

- The system is configured for minimal footprint
- All disk operations, NFS mounting, etc. will be handled by the .NET service
- Serial console is configured for headless operation
- IPv6 is disabled to speed up network boot
- The system will automatically start the .NET service after network initialization
