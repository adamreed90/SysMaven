#!/bin/sh
set -e

echo "Starting ISO build process..."

# Create working directory
WORK_DIR="/tmp/iso-build"
ISO_ROOT="$WORK_DIR/iso-root"
DOCKER_ROOT="$WORK_DIR/docker-root"
mkdir -p "$ISO_ROOT" "$DOCKER_ROOT"
cd "$WORK_DIR"

# First, build and export your Docker image's filesystem
echo "Exporting Docker image filesystem..."
docker create --name temp_container imaging-service
docker export temp_container | tar -x -C "$DOCKER_ROOT"
docker rm temp_container

# Create ISO directory structure
mkdir -p "$ISO_ROOT"/boot/syslinux
mkdir -p "$ISO_ROOT"/apks

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

# Copy the entire Docker image filesystem into the ISO
# but exclude some directories we don't want
cp -a "$DOCKER_ROOT"/* "$ISO_ROOT"/ 2>/dev/null || true

# Create init script to start your service
mkdir -p "$ISO_ROOT"/etc/local.d
cat > "$ISO_ROOT"/etc/local.d/imaging.start << 'EOF'
#!/bin/sh

# Ensure all necessary directories exist and have correct permissions
mkdir -p \
    /mnt/nfs \
    /mnt/image \
    /mnt/target \
    /var/lib/images \
    /var/log/imaging \
    /var/cache/multicast \
    /etc/network-scripts \
    /etc/network-imaging \
    /etc/partclone \
    /etc/multicast

# Ensure service user exists
if ! id serviceuser >/dev/null 2>&1; then
    adduser -D serviceuser
fi

# Set correct permissions
chown -R serviceuser:serviceuser \
    /var/log/imaging \
    /var/lib/images \
    /var/cache/multicast

# Start the imaging service
cd /opt/imaging-service
exec dotnet ImagingService.dll
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

# Create a squashfs of the root filesystem (better compression)
mksquashfs "$ISO_ROOT" "$WORK_DIR"/rootfs.squashfs

# Create final ISO structure
FINAL_ISO="$WORK_DIR/final-iso"
mkdir -p "$FINAL_ISO"/boot/syslinux
cp "$ISO_ROOT"/boot/syslinux/* "$FINAL_ISO"/boot/syslinux/
cp "$ISO_ROOT"/boot/vmlinuz "$FINAL_ISO"/boot/
cp "$ISO_ROOT"/boot/initfs "$FINAL_ISO"/boot/
mv "$WORK_DIR"/rootfs.squashfs "$FINAL_ISO"/boot/

# Update syslinux config to use squashfs
cat > "$FINAL_ISO"/boot/syslinux/syslinux.cfg << 'EOF'
TIMEOUT 20
PROMPT 1
DEFAULT imaging

LABEL imaging
    MENU LABEL Network Imaging System
    LINUX /boot/vmlinuz
    APPEND initrd=/boot/initfs root=/dev/ram0 rw modules=loop,squashfs,sd-mod,usb-storage console=tty0 console=ttyS0,115200
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
    "$FINAL_ISO"

# Make the ISO hybrid (bootable from USB)
isohybrid /output/imaging-system.iso

echo "ISO build complete: /output/imaging-system.iso"
