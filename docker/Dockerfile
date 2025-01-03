FROM mcr.microsoft.com/dotnet/runtime:8.0-alpine

# Add community and testing repositories
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories

# Install required packages
RUN apk update && apk add --no-cache \
    # Disk imaging and manipulation
    partclone \
    parted \
    hdparm \
    e2fsprogs \
    xfsprogs \
    ntfs-3g \
    dosfstools \
    gptfdisk \
    mdadm \
    lvm2 \
    cryptsetup \
    # Network tools and services
    nfs-utils \
    curl \
    wget \
    rsync \
    iftop \
    ethtool \
    iproute2 \
    bridge \
    iputils \
    net-tools \
    nmap \
    tcpdump \
    open-iscsi \
    dnsmasq \
    # Wake-on-LAN
    wol \
    # System utilities
    util-linux \
    pciutils \
    usbutils \
    lsscsi \
    smartmontools \
    dmidecode \
    sysstat \
    acpi \
    # Process management
    procps \
    # Compression tools
    pigz \
    zstd \
    xz \
    # Logging and monitoring
    syslog-ng \
    logrotate \
    # Shell utilities
    bash \
    grep \
    sed \
    gawk \
        # Hardware detection
    hwids \
    # UEFI tools
    efibootmgr \
    efivar \
    # Additional utilities
    stress-ng \
    && rm -rf /var/cache/apk/*

# Create a non-root user for the service
RUN adduser -D serviceuser

# Set up working directory for the service
WORKDIR /app

# Create necessary directories
RUN mkdir -p \
    /mnt/nfs \
    /mnt/image \
    /mnt/target \
    /var/lib/images \
    /var/log/imaging \
    /var/cache/multicast \
    /etc/network-scripts

# Add common configuration directories
RUN mkdir -p \
    /etc/network-imaging \
    /etc/partclone \
    /etc/multicast

# Set up basic logging configuration
RUN touch /var/log/imaging.log && \
    chown serviceuser:serviceuser /var/log/imaging.log

# Copy ImagingService.dll to /opt/imaging-service/
COPY ImagingService.dll /opt/imaging-service/

# Set the working directory to /opt/imaging-service/
WORKDIR /opt/imaging-service/

# Run the ImagingService as the entry point
ENTRYPOINT ["dotnet", "ImagingService.dll"]

# Switch to bash as default shell
SHELL ["/bin/bash", "-c"]
CMD ["/bin/bash"]

# Add labels for identification
LABEL maintainer="your-email@domain.com" \
      description="Network imaging system based on Alpine Linux" \
      version="1.0"
