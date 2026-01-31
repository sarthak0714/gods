# CMake policy for MSVC runtime library selection must be set before project()
cmake_minimum_required(VERSION 3.20)
cmake_policy(SET CMP0091 NEW)

project(gods_native CXX)

# bgfx requires C++20
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Use dynamic runtime library (MultiThreadedDLL) for all targets
# This applies to all targets including FetchContent dependencies
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")

# Output directories
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

# ============================================
# External Dependencies via FetchContent
# ============================================
include(FetchContent)

# GLM - OpenGL Mathematics (header-only)
FetchContent_Declare(
    glm
    GIT_REPOSITORY https://github.com/g-truc/glm.git
    GIT_TAG 1.0.1
    GIT_SHALLOW TRUE
)

# bgfx.cmake - CMake wrapper for bgfx (easier integration)
FetchContent_Declare(
    bgfx_cmake
    GIT_REPOSITORY https://github.com/bkaradzic/bgfx.cmake.git
    GIT_TAG master
    GIT_SHALLOW TRUE
)

# tinygltf - Header-only glTF 2.0 loader
FetchContent_Declare(
    tinygltf
    GIT_REPOSITORY https://github.com/syoyo/tinygltf.git
    GIT_TAG v2.8.21
    GIT_SHALLOW TRUE
)

# ozz-animation - Skeletal animation library
FetchContent_Declare(
    ozz_animation
    GIT_REPOSITORY https://github.com/guillaumeblanc/ozz-animation.git
    GIT_TAG 0.14.3
    GIT_SHALLOW TRUE
)

# Make dependencies available
message(STATUS "Fetching GLM...")
FetchContent_MakeAvailable(glm)

message(STATUS "Fetching bgfx.cmake (includes bx, bimg, bgfx)...")
set(BGFX_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(BGFX_BUILD_TOOLS OFF CACHE BOOL "" FORCE)
set(BGFX_INSTALL OFF CACHE BOOL "" FORCE)
set(BX_AMALGAMATED OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(bgfx_cmake)

message(STATUS "Fetching tinygltf...")
set(TINYGLTF_BUILD_LOADER_EXAMPLE OFF CACHE BOOL "" FORCE)
set(TINYGLTF_INSTALL OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(tinygltf)

message(STATUS "Fetching ozz-animation...")
set(ozz_build_samples OFF CACHE BOOL "" FORCE)
set(ozz_build_howtos OFF CACHE BOOL "" FORCE)
set(ozz_build_tests OFF CACHE BOOL "" FORCE)
set(ozz_build_tools OFF CACHE BOOL "" FORCE)
# Use DLL runtime to match our shared library
set(ozz_build_msvc_rt_dll ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(ozz_animation)

# ============================================
# Gods Native Engine Library
# ============================================

set(SOURCES
    src/gods_engine.cpp
    src/renderer.cpp
    src/model_loader.cpp
    src/animation_system.cpp
)

set(HEADERS
    include/gods_engine.h
    include/renderer.h
    include/model_loader.h
    include/animation_system.h
)

# Build as shared library for FFI
add_library(${PROJECT_NAME} SHARED ${SOURCES} ${HEADERS})

# Include directories
target_include_directories(${PROJECT_NAME} PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_include_directories(${PROJECT_NAME} PRIVATE
    ${tinygltf_SOURCE_DIR}
    ${bgfx_cmake_SOURCE_DIR}/bgfx/include
    ${bgfx_cmake_SOURCE_DIR}/bx/include
    ${bgfx_cmake_SOURCE_DIR}/bimg/include
)

# Platform-specific bx compat includes
if(WIN32)
    target_include_directories(${PROJECT_NAME} PRIVATE
        ${bgfx_cmake_SOURCE_DIR}/bx/include/compat/msvc
    )
endif()

# Link dependencies
target_link_libraries(${PROJECT_NAME} PRIVATE
    bgfx
    bx
    bimg
    glm::glm
    ozz_animation
    ozz_base
    ozz_geometry
)

# Windows-specific settings
if(WIN32)
    target_compile_definitions(${PROJECT_NAME} PRIVATE
        GODS_BUILDING_DLL
        _CRT_SECURE_NO_WARNINGS
    )
    # Link Windows libraries needed by bgfx
    target_link_libraries(${PROJECT_NAME} PRIVATE
        d3d12
        dxgi
        d3dcompiler
    )
endif()

# Copy DLL to game directory for easy loading
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        $<TARGET_FILE:${PROJECT_NAME}>
        ${CMAKE_CURRENT_SOURCE_DIR}/../$<TARGET_FILE_NAME:${PROJECT_NAME}>
    COMMENT "Copying ${PROJECT_NAME} to game directory"
)
