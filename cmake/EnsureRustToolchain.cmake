# Copyright (c) 2023, AgiBot Inc.
# All rights reserved.
#
# EnsureRustToolchain.cmake
# Detects or installs Rust nightly toolchain to a local directory without polluting system environment.
#
# Sets the following variables:
#   RUST_TOOLCHAIN_READY - TRUE if Rust toolchain is available
#   CARGO_EXECUTABLE     - Path to cargo executable
#   RUSTC_EXECUTABLE     - Path to rustc executable
#   RUSTUP_EXECUTABLE    - Path to rustup executable
#
# Environment variables set:
#   RUSTUP_HOME - Local rustup directory
#   CARGO_HOME  - Local cargo directory

include_guard(GLOBAL)

# Configuration
set(RUST_REQUIRED_CHANNEL "nightly" CACHE STRING "Required Rust channel (stable, beta, nightly)")
set(RUST_LOCAL_DIR "${CMAKE_SOURCE_DIR}/_deps/rust" CACHE PATH "Local Rust installation directory")

function(ensure_rust_toolchain)
  set(RUSTUP_HOME "${RUST_LOCAL_DIR}/rustup")
  set(CARGO_HOME "${RUST_LOCAL_DIR}/cargo")
  set(LOCAL_CARGO "${CARGO_HOME}/bin/cargo")
  set(LOCAL_RUSTC "${CARGO_HOME}/bin/rustc")
  set(LOCAL_RUSTUP "${CARGO_HOME}/bin/rustup")

  # Export environment variables for subprocesses
  set(ENV{RUSTUP_HOME} "${RUSTUP_HOME}")
  set(ENV{CARGO_HOME} "${CARGO_HOME}")

  # Helper function to check if toolchain is nightly
  function(_check_rust_is_nightly CARGO_PATH RESULT_VAR)
    execute_process(
      COMMAND "${CARGO_PATH}" --version
      OUTPUT_VARIABLE CARGO_VERSION_OUTPUT
      ERROR_QUIET
      OUTPUT_STRIP_TRAILING_WHITESPACE
      RESULT_VARIABLE CARGO_VERSION_RESULT
    )
    if(CARGO_VERSION_RESULT EQUAL 0 AND CARGO_VERSION_OUTPUT MATCHES "nightly")
      set(${RESULT_VAR} TRUE PARENT_SCOPE)
    else()
      set(${RESULT_VAR} FALSE PARENT_SCOPE)
    endif()
  endfunction()

  # 1. Check if local installation already exists
  if(EXISTS "${LOCAL_CARGO}")
    message(STATUS "[Rust] Found local installation at ${CARGO_HOME}")
    _check_rust_is_nightly("${LOCAL_CARGO}" IS_NIGHTLY)
    if(IS_NIGHTLY OR NOT RUST_REQUIRED_CHANNEL STREQUAL "nightly")
      set(RUST_TOOLCHAIN_READY TRUE PARENT_SCOPE)
      set(CARGO_EXECUTABLE "${LOCAL_CARGO}" PARENT_SCOPE)
      set(RUSTC_EXECUTABLE "${LOCAL_RUSTC}" PARENT_SCOPE)
      set(RUSTUP_EXECUTABLE "${LOCAL_RUSTUP}" PARENT_SCOPE)
      message(STATUS "[Rust] Using local Rust toolchain")
      return()
    else()
      message(STATUS "[Rust] Local installation exists but is not nightly, will reinstall")
    endif()
  endif()

  # 2. Check system Rust (only if RUST_PREFER_SYSTEM is ON)
  option(RUST_PREFER_SYSTEM "Prefer system Rust over local installation" OFF)
  if(RUST_PREFER_SYSTEM)
    find_program(SYSTEM_CARGO cargo)
    if(SYSTEM_CARGO)
      _check_rust_is_nightly("${SYSTEM_CARGO}" IS_NIGHTLY)
      if(IS_NIGHTLY OR NOT RUST_REQUIRED_CHANNEL STREQUAL "nightly")
        message(STATUS "[Rust] Using system Rust toolchain: ${SYSTEM_CARGO}")
        set(RUST_TOOLCHAIN_READY TRUE PARENT_SCOPE)
        set(CARGO_EXECUTABLE "${SYSTEM_CARGO}" PARENT_SCOPE)
        get_filename_component(CARGO_DIR "${SYSTEM_CARGO}" DIRECTORY)
        set(RUSTC_EXECUTABLE "${CARGO_DIR}/rustc" PARENT_SCOPE)
        set(RUSTUP_EXECUTABLE "${CARGO_DIR}/rustup" PARENT_SCOPE)
        return()
      else()
        message(STATUS "[Rust] System Rust is not nightly, will install locally")
      endif()
    endif()
  endif()

  # 3. Auto-install Rust to local directory
  message(STATUS "[Rust] Installing Rust ${RUST_REQUIRED_CHANNEL} to ${RUST_LOCAL_DIR}...")
  
  # Create directories
  file(MAKE_DIRECTORY "${RUSTUP_HOME}")
  file(MAKE_DIRECTORY "${CARGO_HOME}")

  # Check if curl is available
  find_program(CURL_EXECUTABLE curl)
  if(NOT CURL_EXECUTABLE)
    message(WARNING "[Rust] curl not found, cannot auto-install Rust toolchain")
    set(RUST_TOOLCHAIN_READY FALSE PARENT_SCOPE)
    return()
  endif()

  # Download and run rustup installer
  set(RUSTUP_INIT_SCRIPT "${CMAKE_BINARY_DIR}/rustup-init.sh")
  
  message(STATUS "[Rust] Downloading rustup installer...")
  execute_process(
    COMMAND ${CURL_EXECUTABLE} --proto =https --tlsv1.2 -sSf https://sh.rustup.rs -o "${RUSTUP_INIT_SCRIPT}"
    RESULT_VARIABLE DOWNLOAD_RESULT
    ERROR_VARIABLE DOWNLOAD_ERROR
  )
  
  if(NOT DOWNLOAD_RESULT EQUAL 0)
    message(WARNING "[Rust] Failed to download rustup installer: ${DOWNLOAD_ERROR}")
    set(RUST_TOOLCHAIN_READY FALSE PARENT_SCOPE)
    return()
  endif()

  # Make script executable and run it
  message(STATUS "[Rust] Running rustup installer (this may take a few minutes)...")
  execute_process(
    COMMAND bash "${RUSTUP_INIT_SCRIPT}" --default-toolchain ${RUST_REQUIRED_CHANNEL} --profile minimal -y --no-modify-path
    RESULT_VARIABLE INSTALL_RESULT
    OUTPUT_VARIABLE INSTALL_OUTPUT
    ERROR_VARIABLE INSTALL_ERROR
  )

  if(NOT INSTALL_RESULT EQUAL 0)
    message(WARNING "[Rust] Failed to install Rust toolchain:")
    message(WARNING "  stdout: ${INSTALL_OUTPUT}")
    message(WARNING "  stderr: ${INSTALL_ERROR}")
    set(RUST_TOOLCHAIN_READY FALSE PARENT_SCOPE)
    return()
  endif()

  # Verify installation
  if(EXISTS "${LOCAL_CARGO}")
    execute_process(
      COMMAND "${LOCAL_CARGO}" --version
      OUTPUT_VARIABLE CARGO_VERSION
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    message(STATUS "[Rust] Successfully installed: ${CARGO_VERSION}")
    set(RUST_TOOLCHAIN_READY TRUE PARENT_SCOPE)
    set(CARGO_EXECUTABLE "${LOCAL_CARGO}" PARENT_SCOPE)
    set(RUSTC_EXECUTABLE "${LOCAL_RUSTC}" PARENT_SCOPE)
    set(RUSTUP_EXECUTABLE "${LOCAL_RUSTUP}" PARENT_SCOPE)
  else()
    message(WARNING "[Rust] Installation completed but cargo not found at ${LOCAL_CARGO}")
    set(RUST_TOOLCHAIN_READY FALSE PARENT_SCOPE)
  endif()

  # Cleanup
  file(REMOVE "${RUSTUP_INIT_SCRIPT}")
endfunction()
