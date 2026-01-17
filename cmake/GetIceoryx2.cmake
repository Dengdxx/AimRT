# Copyright (c) 2023, AgiBot Inc.
# All rights reserved.
#
# GetIceoryx2.cmake
# Fetches and configures iceoryx2 library for AimRT

include_guard(GLOBAL)
include(FetchContent)
include(EnsureRustToolchain)

message(STATUS "Getting iceoryx2...")

# Ensure Rust toolchain is available first
ensure_rust_toolchain()

if(NOT RUST_TOOLCHAIN_READY)
  message(WARNING "ICEORYX2: Rust toolchain not available. "
                  "Install Rust manually: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain nightly")
  return()
endif()

# Add cargo to PATH for iceoryx2 build
get_filename_component(CARGO_BIN_DIR "${CARGO_EXECUTABLE}" DIRECTORY)
set(ENV{PATH} "${CARGO_BIN_DIR}:$ENV{PATH}")

message(STATUS "[iceoryx2] Using Rust toolchain:")
message(STATUS "  CARGO: ${CARGO_EXECUTABLE}")
message(STATUS "  RUSTC: ${RUSTC_EXECUTABLE}")

# iceoryx2 version
set(ICEORYX2_VERSION
    "v0.8.0"
    CACHE STRING "Iceoryx2 version to fetch")
set(iceoryx2_DOWNLOAD_URL
    "https://github.com/eclipse-iceoryx/iceoryx2/archive/refs/tags/${ICEORYX2_VERSION}.tar.gz"
    CACHE STRING "")

# iceoryx2 build options
set(IOX2_CXX_STD_VERSION
    17
    CACHE STRING "C++ standard version for iceoryx2")
set(BUILD_SHARED_LIBS_SAVED ${BUILD_SHARED_LIBS})
set(BUILD_SHARED_LIBS OFF)

if(iceoryx2_LOCAL_SOURCE)
  FetchContent_Declare(
    iceoryx2
    SOURCE_DIR ${iceoryx2_LOCAL_SOURCE}
    OVERRIDE_FIND_PACKAGE)
else()
  FetchContent_Declare(
    iceoryx2
    URL ${iceoryx2_DOWNLOAD_URL}
    DOWNLOAD_EXTRACT_TIMESTAMP ON
    OVERRIDE_FIND_PACKAGE)
endif()

# Wrap in function to restrict variable scope
function(get_iceoryx2)
  FetchContent_GetProperties(iceoryx2)
  if(NOT iceoryx2_POPULATED)
    # Set iceoryx2 options
    set(BUILD_TESTING
        OFF
        CACHE BOOL "" FORCE)
    set(BUILD_EXAMPLES
        OFF
        CACHE BOOL "" FORCE)
    set(BUILD_CXX
        ON
        CACHE BOOL "" FORCE)

    # Disable warnings as errors for iceoryx2 (it may have warnings with newer compilers)
    set(WARNING_AS_ERROR
        OFF
        CACHE BOOL "" FORCE)

    FetchContent_MakeAvailable(iceoryx2)
  endif()
endfunction()

get_iceoryx2()

# Restore BUILD_SHARED_LIBS
set(BUILD_SHARED_LIBS ${BUILD_SHARED_LIBS_SAVED})

message(STATUS "[iceoryx2] Configuration complete")
