FROM alpine:latest

# Install required packages
RUN apk update && apk add --no-cache \
    # .NET Runtime
    dotnet8-runtime \
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
    bridge-utils \
    iputils \
    net-tools \
    nmap \
    tcpdump \
    iscsi-utils \
    multicast-tools \
    dhcp-helper \
    dnsmasq \
    # Wake-on-LAN
    wol \
    etherwake \
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
    awk \
    # Hardware detection
    hwids \
    # UEFI tools
    efibootmgr \
    efivar \
    # Additional utilities
    memtester \
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

# Set environment variables
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Create necessary device nodes (if needed during runtime)
# Note: This might need to be done at runtime depending on the use case
# RUN mknod -m 622 /dev/console c 5 1
# RUN mknod -m 666 /dev/null c 1 3
# RUN mknod -m 666 /dev/zero c 1 5

# Set up basic logging configuration
RUN touch /var/log/imaging.log && \
    chown serviceuser:serviceuser /var/log/imaging.log

# Switch to bash as default shell
SHELL ["/bin/bash", "-c"]
CMD ["/bin/bash"]

# Add labels for identification
LABEL maintainer="project@sysmaven.org" \
      description="Network imaging system based on Alpine Linux" \
      version="1.0"
