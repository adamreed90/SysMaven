#!/bin/sh
set -e

# First build your imaging service Docker image
docker build -t imaging-service .

# Then build the ISO
docker run --rm --privileged \
    -v "$(pwd)/output:/output" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    alpine:latest /build-scripts/build-iso.sh
