#!/bin/bash
# Script to build and run Docker test environment
# Run from AimRT root directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIMRT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

IMAGE_NAME="aimrt-test:latest"
CONTAINER_NAME="aimrt-build-test"

echo "=== Building Docker Image ==="
docker build -t "$IMAGE_NAME" -f "$SCRIPT_DIR/Dockerfile.test" "$SCRIPT_DIR"

echo ""
echo "=== Running Build Test in Docker ==="
docker run --rm \
    --name "$CONTAINER_NAME" \
    -v "$AIMRT_ROOT:/workspace" \
    -w /workspace \
    "$IMAGE_NAME" \
    ./docker/test_build.sh

echo ""
echo "=== Docker Test Complete ==="
