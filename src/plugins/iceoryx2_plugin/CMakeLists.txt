# Copyright (c) 2023, AgiBot Inc.
# All rights reserved.

cmake_minimum_required(VERSION 3.22)

project(aimrt_iceoryx2_plugin)

# ============================================================================
# Iceoryx2 dependency - provided by top-level GetIceoryx2.cmake
# ============================================================================

# Check if iceoryx2 target is available (should be provided by parent CMake)
if(NOT TARGET iceoryx2-cxx::static-lib-cxx)
  message(FATAL_ERROR "iceoryx2-cxx::static-lib-cxx target not found. " "This plugin must be built from the top-level AimRT CMakeLists.txt " "with AIMRT_BUILD_ICEORYX2_PLUGIN=ON")
endif()

# ============================================================================
# Plugin object library (shared by .so and tests)
# ============================================================================

add_library(${PROJECT_NAME}_obj OBJECT iceoryx2_plugin.cc iceoryx2_channel_backend.cc global.cc)

target_include_directories(
  ${PROJECT_NAME}_obj
  PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/.. # For iceoryx2_plugin/xxx.h includes
         ${CMAKE_CURRENT_SOURCE_DIR}/../.. # For src/ includes (runtime/core, etc.)
)

target_link_libraries(
  ${PROJECT_NAME}_obj
  PUBLIC aimrt::runtime::core
         yaml-cpp
         iceoryx2-cxx::static-lib-cxx)

# ============================================================================
# Plugin shared library
# ============================================================================

add_library(${PROJECT_NAME} SHARED iceoryx2_plugin_main.cc $<TARGET_OBJECTS:${PROJECT_NAME}_obj>)

target_link_libraries(
  ${PROJECT_NAME}
  PRIVATE ${PROJECT_NAME}_obj)

set_target_properties(${PROJECT_NAME} PROPERTIES OUTPUT_NAME "aimrt_iceoryx2_plugin")

# ============================================================================
# Unit tests
# ============================================================================

if(AIMRT_BUILD_TESTS)
  add_executable(aimrt_iceoryx2_plugin_test test/iceoryx2_plugin_test.cc)

  target_link_libraries(aimrt_iceoryx2_plugin_test PRIVATE ${PROJECT_NAME}_obj GTest::gtest_main)

  add_test(NAME aimrt_iceoryx2_plugin_test COMMAND aimrt_iceoryx2_plugin_test)
endif()
