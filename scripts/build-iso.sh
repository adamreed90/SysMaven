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
        log_error "Custom rootfs not found or incomplete. Please run build-image.sh first."
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
    mkdir -p "${ISO_DIR}"/{boot/{grub,syslinux},EFI/BOOT}
    
    log_success "ISO directory structure created"
}

# Copy boot files
copy_boot_files() {
    log "INFO" "Copying boot files..."
    
    # Create syslinux directory if it doesn't exist
    mkdir -p "${ISO_DIR}/boot/syslinux"
    
    # Essential ISOLINUX files
    if [ ! -f "/usr/lib/ISOLINUX/isolinux.bin" ]; then
        log_error "isolinux.bin not found. Please install isolinux package."
        exit 1
    }
    
    if [ ! -f "/usr/lib/syslinux/modules/bios/ldlinux.c32" ]; then
        log_error "syslinux modules not found. Please install syslinux-common package."
        exit 1
    }
    
    # Copy ISOLINUX files
    cp "/usr/lib/ISOLINUX/isolinux.bin" "${ISO_DIR}/boot/syslinux/" || {
        log_error "Failed to copy isolinux.bin"
        exit 1
    }
    
    # Required modules for basic menu functionality
    local required_modules=(
        "ldlinux.c32"      # Core module
        "libcom32.c32"     # Required by menu
        "libutil.c32"      # Required by menu
        "menu.c32"         # Basic menu system
        "vesamenu.c32"     # Graphical menu
    )
    
    for module in "${required_modules[@]}"; do
        cp "/usr/lib/syslinux/modules/bios/${module}" "${ISO_DIR}/boot/syslinux/" || {
            log_error "Failed to copy required module: ${module}"
            exit 1
        }
    }
    
    # Rename isolinux.bin to syslinux.bin for consistency
    cp "${ISO_DIR}/boot/syslinux/isolinux.bin" "${ISO_DIR}/boot/syslinux/syslinux.bin"
    
    # Modify syslinux config to be more basic for debugging
    cat > "${ISO_DIR}/boot/syslinux/syslinux.cfg" << 'EOF'
DEFAULT menu.c32
PROMPT 0
TIMEOUT 50
MENU TITLE Boot Menu

LABEL alpine
    MENU LABEL Boot Alpine Linux
    LINUX /boot/vmlinuz
    INITRD /boot/initramfs
    APPEND root=/dev/ram0 modules=loop,squashfs,sd-mod,usb-storage quiet
EOF

    log_success "Boot files copied successfully"
}

# Create boot configurations
create_boot_configs() {
    log "INFO" "Creating boot configurations..."
    
    # Create syslinux configuration (BIOS)
    cat > "${ISO_DIR}/boot/syslinux/syslinux.cfg" << 'EOF'
TIMEOUT 30
PROMPT 1
DEFAULT custom_alpine

LABEL custom_alpine
    MENU LABEL Custom Alpine Linux
    LINUX /boot/vmlinuz
    INITRD /boot/initramfs
    APPEND root=/dev/ram0 console=tty0 console=ttyS0,115200n8 modules=loop,squashfs,sr_mod modloop=/boot/alpine-custom.squashfs alpine_dev=cdrom quiet

LABEL custom_alpine_debug
    MENU LABEL Custom Alpine Linux (Debug Mode)
    LINUX /boot/vmlinuz
    INITRD /boot/initramfs
    APPEND root=/dev/ram0 console=tty0 console=ttyS0,115200n8 modules=loop,squashfs,sr_mod modloop=/boot/alpine-custom.squashfs alpine_dev=cdrom debug_init=1
EOF
    
    # Create GRUB configuration (UEFI)
    cat > "${ISO_DIR}/boot/grub/grub.cfg" << 'EOF'
set default=0
set timeout=3

insmod all_video
insmod gfxterm
insmod png
insmod serial

terminal_input console serial
terminal_output console serial

serial --unit=0 --speed=115200

menuentry "Custom Alpine Linux" {
    linux /boot/vmlinuz root=/dev/ram0 console=tty0 console=ttyS0,115200n8 modules=loop,squashfs,sr_mod modloop=/boot/alpine-custom.squashfs alpine_dev=cdrom quiet
    initrd /boot/initramfs
}

menuentry "Custom Alpine Linux (Debug Mode)" {
    linux /boot/vmlinuz root=/dev/ram0 console=tty0 console=ttyS0,115200n8 modules=loop,squashfs,sr_mod modloop=/boot/alpine-custom.squashfs alpine_dev=cdrom debug_init=1
    initrd /boot/initramfs
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
        --modules="part_gpt part_msdos fat iso9660" \
        "boot/grub/grub.cfg=${ISO_DIR}/boot/grub/grub.cfg" || {
            log_error "Failed to create UEFI boot loader"
            exit 1
        }
    
    # Create UEFI boot image using truncate instead of dd
    truncate -s 4M "${ISO_DIR}/boot/efiboot.img" || {
        log_error "Failed to create UEFI boot image"
        exit 1
    }
    
    mkfs.vfat "${ISO_DIR}/boot/efiboot.img" || {
        log_error "Failed to format UEFI boot image"
        exit 1
    }
    
    # Create and copy EFI structure
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
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
        -partition_offset 16 \
        -J -R -l \
        -c boot/syslinux/boot.cat \
        -b boot/syslinux/isolinux.bin \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -eltorito-alt-boot \
        -e boot/efiboot.img \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
        -volid "ALPINE_CUSTOM" \
        "${ISO_DIR}/" || {
            log_error "Failed to create ISO"
            exit 1
        }
    
    # Make ISO hybrid
    isohybrid --uefi "${OUTPUT_ISO}" || {
        log_error "Failed to make ISO hybrid"
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
    echo "2. Test the ISO in Hyper-V:"
    echo "   - For UEFI boot: Enable Secure Boot"
    echo "   - For BIOS boot: Disable Secure Boot"
    echo "3. The ISO is located at: ${OUTPUT_ISO}"
    echo
}

# Run main function
main "$@"
