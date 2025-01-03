# Deployment Guide

This document provides the steps and requirements for deploying the Network Imaging System.

## Prerequisites

Before deploying the system, ensure you have the following prerequisites:

- Docker installed on the target machine
- Access to the Docker Hub repository or the ability to build the Docker image locally
- Network access to the target machines for imaging

## Building the Docker Image

To build the Docker image locally, follow these steps:

1. Clone the repository:
   ```bash
   git clone https://github.com/adamreed90/SysMaven.git
   cd SysMaven
   ```

2. Build the Docker image:
   ```bash
   docker build -t network-imaging-system .
   ```

## Running the Docker Container

To run the Docker container, use the following command:

```bash
docker run -d --name network-imaging-system \
  -v /path/to/config:/etc/network-imaging \
  -v /path/to/images:/var/lib/images \
  -v /path/to/logs:/var/log/imaging \
  --network host \
  network-imaging-system
```

Replace `/path/to/config`, `/path/to/images`, and `/path/to/logs` with the appropriate paths on your host machine.

## Configuration

The system configuration files are located in the `/etc/network-imaging` directory. Ensure that the configuration files are properly set up before starting the container.

## Logging

Logs are stored in the `/var/log/imaging` directory. You can access the logs to monitor the system's activities and troubleshoot any issues.

## Network Boot Setup

To set up network booting, follow these steps:

1. Configure your DHCP server to support iPXE booting.
2. Set up the TFTP server to serve the iPXE boot files.
3. Ensure that the network boot settings in the configuration files are correctly configured.

## Multicast Deployment

For multicast image deployment, ensure that the `dnsmasq` service is properly configured and running. The multicast settings can be adjusted in the configuration files.

## Storage Management

The system uses various disk utilities for storage management. Ensure that the storage devices and partitions are properly configured before starting the imaging process.

## System Monitoring

The system provides basic monitoring capabilities. You can check the system status using the provided API endpoints.

## Troubleshooting

If you encounter any issues during deployment, refer to the logs for detailed information. You can also check the system status using the API endpoints to diagnose any problems.

## Support

For support and assistance, please contact the maintainer at your-email@domain.com.
