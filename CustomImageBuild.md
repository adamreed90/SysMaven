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

## 5. Clean Up and Optimize Image

```bash
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

# Optionally remove language files if not needed
sudo rm -rf usr/share/locale/*

# Clear any temp files
sudo find . -name '*.pyc' -delete
sudo find . -name '*.pyo' -delete
sudo find . -name '*__pycache__*' -delete

## 6. Create Network Boot Image

```bash
# Create squashfs image with optimized compression
cd ..
sudo mksquashfs custom-rootfs alpine-custom.squashfs -comp xz -Xbcj x86 -Xdict-size 1M -b 1M -no-exports -no-recovery -always-use-fragments

# Copy kernel and create initial ramdisk
mkdir -p bootfiles
cp custom-rootfs/boot/vmlinuz-lts bootfiles/
cp custom-rootfs/boot/initramfs-lts bootfiles/
```

## 6. Network Boot Process and Configuration

### Boot Process Overview

1. **Initial PXE Boot**:
   - System BIOS/UEFI starts PXE boot
   - DHCP server provides network configuration and points to iPXE binary
   - iPXE binary is loaded and executed

2. **iPXE Script Execution**:
   - iPXE requests script from your control service
   - Script initiates download of kernel, initramfs, and eventually squashfs

3. **Kernel and Initramfs Boot**:
   - Kernel starts with specified parameters
   - Initramfs creates initial runtime environment
   - Network is initialized using DHCP
   - Squashfs download and mount process begins

4. **Root Filesystem Setup**:
   - Initramfs downloads squashfs image using HTTP
   - Creates RAM disk and mounts squashfs
   - Switches root to the mounted squashfs
   - Continues boot process from squashfs

### iPXE Script Configuration

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
    alpine_repo="http://your-image-server" \
    modloop=http://your-image-server/alpine-custom.squashfs \
    modules=loop,squashfs alpine_dev=loop0
initrd http://your-image-server/initramfs-custom
boot
```

### Key Boot Parameters Explained

- `root=/dev/ram0`: Initial root filesystem is in RAM
- `ip=dhcp`: Configure network via DHCP
- `console=`: Configure both VGA and serial console output
- `modloop=`: URL of the squashfs image to download
- `modules=loop,squashfs`: Required kernel modules for mounting squashfs
- `alpine_dev=loop0`: Device to mount the squashfs on
- `nomodeset`: Prevents video mode changes
- `panic=30`: Reboot after 30 seconds if kernel panic
- `quiet loglevel=3`: Reduce boot messages
- `ipv6.disable=1`: Speed up network configuration

### Required HTTP Server Files

Your HTTP server (your-image-server) must serve:
```
/vmlinuz-lts           # The Linux kernel
/initramfs-custom      # The initial RAM filesystem
/alpine-custom.squashfs # Our custom system image
```

### Error Handling

The boot process includes several fallback mechanisms:

1. **Network Issues**:
   - DHCP timeout/retry is handled by iPXE
   - Multiple network interface support available via `ip=` parameter

2. **Download Failures**:
   - initramfs will retry downloads with exponential backoff
   - Kernel panic will trigger reboot after timeout

3. **Mount Failures**:
   - Failed squashfs mount drops to recovery shell
   - Network remains configured for manual intervention

### Monitoring Boot Process

You can monitor the boot process through:

1. **Serial Console Output**:
   - All boot messages appear on configured serial port
   - Critical errors are logged to both console outputs

2. **Network Status**:
   - Optional status reporting to control service
   - DHCP server logs client acquisition
   - HTTP server logs file downloads

### Boot Flow Sequence

1. System powers on
2. PXE ROM loads iPXE
3. iPXE loads script from your control service
4. Kernel and initramfs download begins
5. Kernel starts, initramfs loaded
6. Network configuration via DHCP
7. Squashfs download begins
8. RAM disk created
9. Squashfs mounted
10. Root switched to squashfs
11. System services start
12. .NET service launches

To troubleshoot boot issues, you can:
1. Add `debug` to kernel parameters for verbose output
2. Remove `quiet` for more boot messages
3. Monitor serial console output
4. Check HTTP server logs for download completion

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
