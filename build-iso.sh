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
LOG_FILE="${LOG_DIR}/iso-$(date +%Y%m%d-%H%M%S).log"
CUSTOM_ROOTFS="${BUILD_DIR}/custom-rootfs"
ISO_DIR="${BUILD_DIR}/iso"
OUTPUT_ISO="${BUILD_DIR}/alpine-custom.iso"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log() {
    local level=$1
    shift
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] $*"
    echo -e "${message}" | tee -a "$LOG_FILE"
    
    if [[ ${level} == "ERROR" ]]; then
        echo -e "${message}" >&2
    fi
}

log_success() {
    echo -e "${GREEN}$*${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}$*${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}$*${NC}" | tee -a "$LOG_FILE"
}

# Error handling
error_handler() {
    local line_number=$1
    local error_code=$2
    log "ERROR" "Error occurred in script $SCRIPT_NAME at line: ${line_number}, error code: ${error_code}"
    exit 1
}

trap 'error_handler ${LINENO} $?' ERR

# Check for root privileges
check_root() {
    log "INFO" "Checking root privileges..."
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
    log_success "Root privileges confirmed"
}

# Verify build environment
verify_environment() {
    log "INFO" "Verifying build environment..."
    
    # Check if custom rootfs exists and is properly built
    if [ ! -d "${CUSTOM_ROOTFS}" ] || [ ! -f "${CUSTOM_ROOTFS}/boot/vmlinuz-lts" ]; then
        log_error "Custom rootfs not found or incomplete. Please run build script first."
        exit 1
    fi
    
    # Verify required tools
    local required_tools=(
        "mksquashfs"
        "xorriso"
        "grub-mkstandalone"
    )
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "${tool}" &> /dev/null; then
            log_error "Required tool not found: ${tool}"
            exit 1
        fi
    done
    
    log_success "Build environment verified"
}

# Create squashfs image
create_squashfs() {
    log "INFO" "Creating squashfs image..."
    
    local squashfs_file="${BUILD_DIR}/alpine-custom.squashfs"
    
    # Remove existing squashfs if it exists
    [ -f "${squashfs_file}" ] && rm "${squashfs_file}"
    
    # Create squashfs with optimal compression
    mksquashfs "${CUSTOM_ROOTFS}" "${squashfs_file}" \
        -comp xz \
        -Xbcj x86 \
        -Xdict-size 1M \
        -b 1M \
        -no-exports \
        -no-recovery \
        -always-use-fragments || {
            log_error "Failed to create squashfs image"
            exit 1
        }
    
    log_success "Squashfs image created successfully"
}

# Create ISO directory structure
create_iso_structure() {
    log "INFO" "Creating ISO directory structure..."
    
    # Remove existing ISO directory if it exists
    [ -d "${ISO_DIR}" ] && rm -rf "${ISO_DIR}"
    
    # Create directory structure
    mkdir -p "${ISO_DIR}/boot/syslinux"
    mkdir -p "${ISO_DIR}/boot/grub"
    mkdir -p "${ISO_DIR}/EFI/BOOT"
    
    log_success "ISO directory structure created"
}

# Copy boot files
copy_boot_files() {
    log "INFO" "Copying boot files..."
    
    # Get kernel version
    KERNEL_VERSION=$(ls "${CUSTOM_ROOTFS}/lib/modules")
    
    # Copy kernel
    cp "${CUSTOM_ROOTFS}/boot/vmlinuz-lts" "${ISO_DIR}/boot/" || {
        log_error "Failed to copy kernel"
        exit 1
    }
    
    # Look for initramfs with kernel version first, then try lts symlink
    if [ -f "${CUSTOM_ROOTFS}/boot/initramfs-${KERNEL_VERSION}" ]; then
        cp "${CUSTOM_ROOTFS}/boot/initramfs-${KERNEL_VERSION}" "${ISO_DIR}/boot/initramfs-lts" || {
            log_error "Failed to copy initramfs"
            exit 1
        }
    elif [ -f "${CUSTOM_ROOTFS}/boot/initramfs-lts" ]; then
        cp "${CUSTOM_ROOTFS}/boot/initramfs-lts" "${ISO_DIR}/boot/initramfs-lts" || {
            log_error "Failed to copy initramfs"
            exit 1
        }
    else
        log_error "No initramfs found in ${CUSTOM_ROOTFS}/boot/"
        ls -la "${CUSTOM_ROOTFS}/boot/"
        exit 1
    fi
    
    # Copy squashfs
    cp "${BUILD_DIR}/alpine-custom.squashfs" "${ISO_DIR}/boot/" || {
        log_error "Failed to copy squashfs"
        exit 1
    }
    
    # Copy BIOS boot files
    cp /usr/lib/ISOLINUX/isolinux.bin "${ISO_DIR}/boot/syslinux/" || {
        log_error "Failed to copy isolinux.bin"
        exit 1
    }
    
    for module in ldlinux.c32 libcom32.c32 libutil.c32 menu.c32 vesamenu.c32 chain.c32 reboot.c32; do
        if [ -f "/usr/lib/syslinux/modules/bios/${module}" ]; then
            cp "/usr/lib/syslinux/modules/bios/${module}" "${ISO_DIR}/boot/syslinux/" || {
                log_error "Failed to copy syslinux module: ${module}"
                exit 1
            }
        else
            log_warning "Syslinux module not found: ${module}"
        fi
    done
    
    log_success "Boot files copied successfully"
}

# Create boot configurations
create_boot_configs() {
    log "INFO" "Creating boot configurations..."
    
    # Create syslinux configuration (BIOS)
    cat > "${ISO_DIR}/boot/syslinux/syslinux.cfg" << 'EOF'
DEFAULT menu.c32
PROMPT 0
TIMEOUT 50
MENU TITLE Custom Alpine Linux Boot Menu

LABEL custom_alpine
    MENU LABEL Custom Alpine Linux
    KERNEL /boot/vmlinuz-lts
    APPEND initrd=/boot/initramfs-lts root=/dev/ram0 console=tty0 console=ttyS0,115200n8 modloop=/boot/alpine-custom.squashfs modules=loop,squashfs alpine_dev=loop0 panic=60
    
LABEL custom_alpine_debug
    MENU LABEL Custom Alpine Linux (Debug Mode)
    KERNEL /boot/vmlinuz-lts
    APPEND initrd=/boot/initramfs-lts root=/dev/ram0 console=tty0 console=ttyS0,115200n8 debug_init=1 modloop=/boot/alpine-custom.squashfs modules=loop,squashfs alpine_dev=loop0 panic=60
EOF
    
    # Create GRUB configuration (UEFI)
    cat > "${ISO_DIR}/boot/grub/grub.cfg" << 'EOF'
set timeout=20
set default=0

menuentry "Custom Alpine Linux" {
    linux /boot/vmlinuz-lts root=/dev/ram0 console=tty0 console=ttyS0,115200n8 nomodeset quiet modloop=/boot/alpine-custom.squashfs modules=loop,squashfs alpine_dev=loop0
    initrd /boot/initramfs-lts
}
EOF
    
    log_success "Boot configurations created"
}

# Create UEFI boot support
create_uefi_boot() {
    log "INFO" "Creating UEFI boot support..."
    
    # Create UEFI boot loader
    grub-mkstandalone \
        --format=x86_64-efi \
        --output="${ISO_DIR}/EFI/BOOT/BOOTX64.EFI" \
        --locales="" \
        --fonts="" \
        "boot/grub/grub.cfg=${ISO_DIR}/boot/grub/grub.cfg" || {
            log_error "Failed to create UEFI boot loader"
            exit 1
        }
    
    # Create UEFI boot image
    fallocate -l 4M "${ISO_DIR}/boot/efiboot.img" || {
        log_error "Failed to create UEFI boot image"
        exit 1
    }
    
    # Ensure the file is zeroed
    truncate -s 4M "${ISO_DIR}/boot/efiboot.img" || {
        log_error "Failed to zero UEFI boot image"
        exit 1
    }
    
    mkfs.vfat "${ISO_DIR}/boot/efiboot.img" || {
        log_error "Failed to format UEFI boot image"
        exit 1
    }
    
    # Create EFI directory structure in the boot image
    LC_ALL=C mmd -i "${ISO_DIR}/boot/efiboot.img" ::/EFI
    LC_ALL=C mmd -i "${ISO_DIR}/boot/efiboot.img" ::/EFI/BOOT
    LC_ALL=C mcopy -i "${ISO_DIR}/boot/efiboot.img" "${ISO_DIR}/EFI/BOOT/BOOTX64.EFI" ::/EFI/BOOT/
    
    log_success "UEFI boot support created"
}

# Create final ISO
create_iso() {
    log "INFO" "Creating final ISO..."
    
    # Remove existing ISO if it exists
    [ -f "${OUTPUT_ISO}" ] && rm "${OUTPUT_ISO}"
    
    xorriso -as mkisofs \
        -o "${OUTPUT_ISO}" \
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
        "${ISO_DIR}/" || {
            log_error "Failed to create ISO"
            exit 1
        }
    
    log_success "ISO created successfully: ${OUTPUT_ISO}"
}

# Verify ISO
verify_iso() {
    log "INFO" "Verifying ISO..."
    
    if [ ! -f "${OUTPUT_ISO}" ]; then
        log_error "ISO file not found"
        exit 1
    fi
    
    local iso_size=$(stat -c%s "${OUTPUT_ISO}")
    if [ "${iso_size}" -lt 50000000 ]; then  # 50MB minimum size
        log_error "ISO file seems too small (${iso_size} bytes)"
        exit 1
    fi
    
    log_success "ISO verification passed"
    log "INFO" "ISO size: $(numfmt --to=iec-i --suffix=B ${iso_size})"
}

# Main function
main() {
    echo "Alpine Linux ISO Creation Script v${SCRIPT_VERSION}"
    echo "----------------------------------------"
    
    # Create log directory if it doesn't exist
    mkdir -p "${LOG_DIR}"
    
    log "INFO" "Starting ISO creation..."
    
    # Run ISO creation steps
    check_root
    verify_environment
    create_squashfs
    create_iso_structure
    copy_boot_files
    create_boot_configs
    create_uefi_boot
    create_iso
    verify_iso
    
    log_success "ISO creation completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Review the log file at: ${LOG_FILE}"
    echo "2. Test the ISO using QEMU or similar"
    echo "3. The ISO is located at: ${OUTPUT_ISO}"
    echo
}

# Run main function
main "$@"
