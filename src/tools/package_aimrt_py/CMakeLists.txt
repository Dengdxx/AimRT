# Copyright (c) 2023, AgiBot Inc.
# All rights reserved.

get_target_property(py_files aimrt::runtime::python_runtime PY_FILES)
file(GLOB_RECURSE gencode_file CONFIGURE_DEPENDS ${PROJECT_SOURCE_DIR}/src/tools/protoc_plugin_py_gen_aimrt_py_rpc/*.py)
file(GLOB_RECURSE ros2_gencode_file CONFIGURE_DEPENDS ${PROJECT_SOURCE_DIR}/src/tools/ros2_py_gen_aimrt_py_rpc/*.py)
list(APPEND py_files ${gencode_file} ${ros2_gencode_file})

get_target_property(pyi_files aimrt::runtime::python_runtime PYI_FILES)
list(APPEND pyi_files ${gencode_file} ${ros2_gencode_file})

set(AIMRT_PY_PKG_DIR ${CMAKE_BINARY_DIR}/aimrt_py_pkg)

add_custom_target(
  copy_python_runtime
  COMMAND ${CMAKE_COMMAND} -E make_directory ${AIMRT_PY_PKG_DIR}/aimrt_py/
  COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:aimrt::runtime::python_runtime> ${AIMRT_PY_PKG_DIR}/aimrt_py/
  COMMAND ${CMAKE_COMMAND} -E copy_if_different ${py_files} ${AIMRT_PY_PKG_DIR}/aimrt_py/
  COMMAND ${CMAKE_COMMAND} -E copy_if_different ${pyi_files} ${AIMRT_PY_PKG_DIR}/aimrt_py/
  COMMENT "Copying python runtime files"
  DEPENDS aimrt::runtime::python_runtime)

if(AIMRT_BUILD_WITH_ROS2)
  add_custom_target(
    copy_ros2_python_runtime
    COMMAND ${CMAKE_COMMAND} -E make_directory ${AIMRT_PY_PKG_DIR}/aimrt_py/
    COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:aimrt::runtime::python_runtime_ros2> ${AIMRT_PY_PKG_DIR}/aimrt_py/
    COMMENT "Copying python runtime ros2 files"
    DEPENDS aimrt::runtime::python_runtime_ros2)
endif()

add_custom_target(
  copy_ros2_plugin_proto_files
  COMMAND ${CMAKE_COMMAND} -E make_directory ${AIMRT_PY_PKG_DIR}/aimrt_py/
  COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_INSTALL_PREFIX}/lib/ ${AIMRT_PY_PKG_DIR}/aimrt_py/lib/
  COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_INSTALL_PREFIX}/local/ ${AIMRT_PY_PKG_DIR}/aimrt_py/local/
  COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_INSTALL_PREFIX}/share/ ${AIMRT_PY_PKG_DIR}/aimrt_py/share/
  COMMENT "Copying ROS2 files"
  DEPENDS aimrt::plugins::ros2_plugin)

add_custom_target(
  create_python_pkg
  COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_CURRENT_SOURCE_DIR}/pyproject.toml ${CMAKE_CURRENT_SOURCE_DIR}/setup.py ${CMAKE_CURRENT_SOURCE_DIR}/MANIFEST.in
          ${AIMRT_PY_PKG_DIR}
  COMMAND ${CMAKE_COMMAND} -E copy_if_different ${PROJECT_SOURCE_DIR}/VERSION ${PROJECT_SOURCE_DIR}/README.md ${PROJECT_SOURCE_DIR}/LICENSE ${AIMRT_PY_PKG_DIR}
  COMMAND ${Python3_EXECUTABLE} -m build --wheel --no-isolation -v
  COMMENT "Creating python package"
  DEPENDS copy_python_runtime
  WORKING_DIRECTORY ${AIMRT_PY_PKG_DIR})

if(AIMRT_BUILD_WITH_ROS2)
  add_dependencies(create_python_pkg copy_ros2_python_runtime)
endif()

if(AIMRT_BUILD_WITH_ROS2 AND AIMRT_BUILD_ROS2_PLUGIN)
  add_dependencies(create_python_pkg copy_ros2_plugin_proto_files)
endif()

include(PluginDetectTool)

function(copy_plugin_if_enabled PLUGIN_NAME)
  string(TOUPPER ${PLUGIN_NAME} PLUGIN_BUILD_FLAG)
  set(PLUGIN_BUILD_FLAG "AIMRT_BUILD_${PLUGIN_BUILD_FLAG}")

  # Check both the build flag AND that the target actually exists
  # This handles cases where the flag was set but the target couldn't be built
  # (e.g., Rust toolchain unavailable for iceoryx2_plugin)
  if(${PLUGIN_BUILD_FLAG} AND TARGET aimrt::plugins::${PLUGIN_NAME})
    add_custom_target(
      copy_${PLUGIN_NAME}
      COMMAND ${CMAKE_COMMAND} -E make_directory ${AIMRT_PY_PKG_DIR}/aimrt_py/
      COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:aimrt::plugins::${PLUGIN_NAME}> ${AIMRT_PY_PKG_DIR}/aimrt_py/
      DEPENDS aimrt::plugins::${PLUGIN_NAME})
    add_dependencies(create_python_pkg copy_${PLUGIN_NAME})
  endif()
endfunction()

function(aimrt_register_python_pkg_plugins)
  # This file is processed before src/plugins is added, so plugin targets may
  # not exist yet. Defer plugin collection/copy target registration until the
  # end of the src/ directory so TARGET checks are meaningful.
  set(AIMRT_PY_PKG_DIR ${CMAKE_BINARY_DIR}/aimrt_py_pkg)

  get_subdirectories(${PROJECT_SOURCE_DIR}/src/plugins PLUGIN_LIST)
  message(STATUS "Detected plugins: ${PLUGIN_LIST}")

  foreach(PLUGIN_NAME ${PLUGIN_LIST})
    copy_plugin_if_enabled(${PLUGIN_NAME})
  endforeach()
endfunction()

cmake_language(DEFER DIRECTORY ${PROJECT_SOURCE_DIR}/src CALL aimrt_register_python_pkg_plugins)
