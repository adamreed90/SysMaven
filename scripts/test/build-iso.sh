#!/bin/sh
set -e

echo "Starting ISO build process..."

# Create working directory
WORK_DIR="/tmp/iso-build"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Generate the custom answers file
cat > "$WORK_DIR/answers" << 'EOF'
KEYMAPOPTS="us us"
HOSTNAMEOPTS="-n imaging-system"
INTERFACESOPTS="auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
"
TIMEZONEOPTS="-z UTC"
PROXYOPTS="none"
APKREPOSOPTS="-1"
SSHDOPTS="-c openssh"
NTPOPTS="-c chrony"
DISKOPTS="-m sys /dev/sda"
EOF

# Create custom setup script
cat > "$WORK_DIR/custom-setup.sh" << 'EOF'
#!/bin/sh

# Create necessary directories
mkdir -p /mnt/nfs /mnt/image /mnt/target /var/lib/images /var/log/imaging /var/cache/multicast /etc/network-scripts
mkdir -p /etc/network-imaging /etc/partclone /etc/multicast

# Set up imaging service
mkdir -p /opt/imaging-service
cp /tmp/ImagingService.dll /opt/imaging-service/

# Create service user
adduser -D serviceuser

# Set up logging
touch /var/log/imaging.log
chown serviceuser:serviceuser /var/log/imaging.log

# Create systemd service for imaging
cat > /etc/init.d/imaging-service << 'EOFS'
#!/sbin/openrc-run

name="imaging-service"
description="Network Imaging Service"
command="/usr/bin/dotnet"
command_args="/opt/imaging-service/ImagingService.dll"
command_user="serviceuser"
command_background=true
pidfile="/run/${RC_SVCNAME}.pid"
output_log="/var/log/imaging.log"
error_log="/var/log/imaging.log"

depend() {
    need net
    after firewall
}

start_pre() {
    checkpath --directory --owner serviceuser:serviceuser --mode 0755 \
        /var/log/imaging /var/lib/images /var/cache/multicast
}
EOFS

chmod +x /etc/init.d/imaging-service
rc-update add imaging-service default

# Enable required services
rc-update add networking boot
rc-update add syslog boot
rc-update add acpid default

# Set up basic networking
cat > /etc/network/interfaces << 'EOFN'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOFN

EOF
chmod +x "$WORK_DIR/custom-setup.sh"

# Create package list
cat > "$WORK_DIR/packages" << 'EOF'
alpine-base
openssh
chrony
dotnet8-runtime
bash
partclone
parted
hdparm
e2fsprogs
xfsprogs
ntfs-3g
dosfstools
gptfdisk
mdadm
lvm2
cryptsetup
nfs-utils
curl
wget
rsync
iftop
ethtool
iproute2
bridge
iputils
net-tools
nmap
tcpdump
open-iscsi
dnsmasq
wol
util-linux
pciutils
usbutils
lsscsi
smartmontools
dmidecode
sysstat
acpi
procps
pigz
zstd
xz
syslog-ng
logrotate
bash
grep
sed
gawk
hwids
efibootmgr
efivar
stress-ng
EOF

echo "Building bootable ISO..."
alpine-make-vm-image \
    --image-format iso \
    --arch x86_64 \
    --profile virt \
    --packages "$(cat $WORK_DIR/packages)" \
    --answer-file "$WORK_DIR/answers" \
    --script-chroot \
    --script "$WORK_DIR/custom-setup.sh" \
    /output/imaging-system.iso

echo "ISO build complete: /output/imaging-system.iso"
