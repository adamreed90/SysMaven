#!/bin/sh
set -e

echo "Starting ISO build process..."

# Create working directory
WORK_DIR="/tmp/iso-build"
ISO_ROOT="$WORK_DIR/iso-root"
mkdir -p "$ISO_ROOT"
cd "$WORK_DIR"

# Create ISO directory structure
mkdir -p "$ISO_ROOT"/boot/syslinux
mkdir -p "$ISO_ROOT"/apks
mkdir -p "$ISO_ROOT"/opt/imaging-service

# Install necessary packages for boot
apk add --no-cache \
    linux-lts \
    linux-firmware-none \
    alpine-base \
    syslinux \
    mkinitfs

# Copy boot files
cp /boot/vmlinuz-lts "$ISO_ROOT"/boot/vmlinuz
cp /boot/initramfs-lts "$ISO_ROOT"/boot/initfs

# Copy syslinux files
cp /usr/share/syslinux/isolinux.bin "$ISO_ROOT"/boot/syslinux/
cp /usr/share/syslinux/ldlinux.c32 "$ISO_ROOT"/boot/syslinux/
cp /usr/share/syslinux/libcom32.c32 "$ISO_ROOT"/boot/syslinux/
cp /usr/share/syslinux/libutil.c32 "$ISO_ROOT"/boot/syslinux/
cp /usr/share/syslinux/menu.c32 "$ISO_ROOT"/boot/syslinux/

# Create syslinux configuration
cat > "$ISO_ROOT"/boot/syslinux/syslinux.cfg << 'EOF'
TIMEOUT 20
PROMPT 1
DEFAULT imaging

LABEL imaging
    MENU LABEL Network Imaging System
    LINUX /boot/vmlinuz
    APPEND initrd=/boot/initfs modules=loop,squashfs,sd-mod,usb-storage console=tty0 console=ttyS0,115200
EOF

# Create Alpine Linux system structure
mkdir -p "$ISO_ROOT"/etc/apk
cp /etc/apk/repositories "$ISO_ROOT"/etc/apk/
cp -r /etc/apk/keys "$ISO_ROOT"/etc/apk/

# Copy your imaging service
cp /tmp/ImagingService.dll "$ISO_ROOT"/opt/imaging-service/

# Create init script
mkdir -p "$ISO_ROOT"/etc/local.d
cat > "$ISO_ROOT"/etc/local.d/imaging.start << 'EOF'
#!/bin/sh
# Start imaging service
dotnet /opt/imaging-service/ImagingService.dll &
EOF
chmod +x "$ISO_ROOT"/etc/local.d/imaging.start

# Create basic system configuration
mkdir -p "$ISO_ROOT"/etc/network
cat > "$ISO_ROOT"/etc/network/interfaces << 'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

# Create the ISO
xorriso -as mkisofs \
    -b boot/syslinux/isolinux.bin \
    -c boot/syslinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -joliet \
    -rock \
    -o /output/imaging-system.iso \
    "$ISO_ROOT"

# Make the ISO hybrid (bootable from USB)
isohybrid /output/imaging-system.iso

echo "ISO build complete: /output/imaging-system.iso"
