#!/bin/sh
set -e

# Build the ISO builder image
docker build -t iso-builder .

# Run the builder to create ISO
docker run --rm --privileged \
    -v "$(pwd)/output:/output" \
    -v "$(pwd)/ImagingService.dll:/tmp/ImagingService.dll" \
    iso-builder /usr/local/bin/build-iso.sh
