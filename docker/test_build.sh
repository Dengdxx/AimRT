#!/bin/bash
# Test build script for AimRT with iceoryx2 plugin
# Run this inside the Docker container

set -e

echo "=== AimRT iceoryx2 Build Test ==="
echo "Date: $(date)"
echo "Working directory: $(pwd)"
echo ""

# Check ROS2
echo "=== Checking ROS2 ==="
source /opt/ros/humble/setup.bash
ros2 --help > /dev/null 2>&1 && echo "ROS2 Humble: OK" || echo "ROS2: Not available"
echo ""

# Check CMake
echo "=== Checking CMake ==="
cmake --version
echo ""

# Setup Rust environment if local installation exists
RUST_LOCAL_DIR="${PWD}/_deps/rust"
if [ -d "$RUST_LOCAL_DIR/cargo/bin" ]; then
    echo "=== Using existing local Rust installation ==="
    export RUSTUP_HOME="$RUST_LOCAL_DIR/rustup"
    export CARGO_HOME="$RUST_LOCAL_DIR/cargo"
    export PATH="$CARGO_HOME/bin:$PATH"
    cargo --version
    rustc --version
    echo ""
fi

# Test iceoryx2 plugin build (minimal, no ROS2 plugins)
echo "=== Testing iceoryx2 Plugin Build (Minimal) ==="
rm -rf build_test

# Set environment variables for Rust toolchain (will be installed during cmake configure)
export RUSTUP_HOME="$RUST_LOCAL_DIR/rustup"
export CARGO_HOME="$RUST_LOCAL_DIR/cargo"

cmake -B build_test \
    -DCMAKE_BUILD_TYPE=Release \
    -DAIMRT_BUILD_TESTS=ON \
    -DAIMRT_BUILD_EXAMPLES=OFF \
    -DAIMRT_BUILD_DOCUMENT=OFF \
    -DAIMRT_BUILD_RUNTIME=ON \
    -DAIMRT_BUILD_WITH_PROTOBUF=ON \
    -DAIMRT_BUILD_WITH_ROS2=OFF \
    -DAIMRT_BUILD_ICEORYX2_PLUGIN=ON \
    -DAIMRT_BUILD_NET_PLUGIN=OFF \
    -DAIMRT_BUILD_MQTT_PLUGIN=OFF \
    -DAIMRT_BUILD_ZENOH_PLUGIN=OFF \
    -DAIMRT_BUILD_ICEORYX_PLUGIN=OFF \
    -DAIMRT_BUILD_ROS2_PLUGIN=OFF \
    -DAIMRT_BUILD_RECORD_PLAYBACK_PLUGIN=OFF \
    -DAIMRT_BUILD_TIME_MANIPULATOR_PLUGIN=OFF \
    -DAIMRT_BUILD_PARAMETER_PLUGIN=OFF \
    -DAIMRT_BUILD_LOG_CONTROL_PLUGIN=OFF \
    -DAIMRT_BUILD_SERVICE_INTROSPECTION_PLUGIN=OFF \
    -DAIMRT_BUILD_TOPIC_LOGGER_PLUGIN=OFF \
    -DAIMRT_BUILD_OPENTELEMETRY_PLUGIN=OFF \
    -DAIMRT_BUILD_GRPC_PLUGIN=OFF \
    -DAIMRT_BUILD_ECHO_PLUGIN=OFF \
    -DAIMRT_BUILD_PROXY_PLUGIN=OFF \
    -DAIMRT_BUILD_PYTHON_RUNTIME=OFF

# Add Rust to PATH after cmake configure (it installs Rust if needed)
if [ -d "$CARGO_HOME/bin" ]; then
    export PATH="$CARGO_HOME/bin:$PATH"
    echo ""
    echo "=== Rust Environment ==="
    echo "CARGO_HOME: $CARGO_HOME"
    echo "RUSTUP_HOME: $RUSTUP_HOME"
    cargo --version
    rustc --version
fi

echo ""
echo "=== Building Plugin ==="
cmake --build build_test --config Release --parallel 8 --target aimrt_iceoryx2_plugin

echo ""
echo "=== Build Results ==="
ls -lh build_test/libaimrt_iceoryx2_plugin.so 2>/dev/null || ls -lh build_test/aimrt_iceoryx2_plugin.so 2>/dev/null || echo "Plugin not found at expected location"

echo ""
echo "=== Building Tests ==="
cmake --build build_test --config Release --parallel 8 --target aimrt_iceoryx2_plugin_test

echo ""
echo "=== Running Tests ==="
cd build_test && ctest -R aimrt_iceoryx2_plugin_test --output-on-failure

echo ""
echo "=== Test Complete ==="
