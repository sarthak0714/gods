cmake_minimum_required(VERSION 3.20)
project(gods_native CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Output directories
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

# Source files
set(SOURCES
    src/gods_engine.cpp
)

# Build as shared library for FFI
add_library(${PROJECT_NAME} SHARED ${SOURCES})

# Include directories
target_include_directories(${PROJECT_NAME} PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

# Windows-specific settings
if(WIN32)
    target_compile_definitions(${PROJECT_NAME} PRIVATE
        GODS_BUILDING_DLL
        _CRT_SECURE_NO_WARNINGS
    )
endif()

# ============================================
# The Forge Integration (Future)
# ============================================
# Uncomment when ready to integrate The-Forge-Lite:
#
# include(FetchContent)
# FetchContent_Declare(
#     theforge
#     GIT_REPOSITORY https://github.com/AminAliari/The-Forge-Lite.git
#     GIT_TAG main
# )
# FetchContent_MakeAvailable(theforge)
# target_link_libraries(${PROJECT_NAME} PRIVATE TheForge)
# ============================================

# Copy DLL to game directory for easy loading
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        $<TARGET_FILE:${PROJECT_NAME}>
        ${CMAKE_CURRENT_SOURCE_DIR}/../$<TARGET_FILE_NAME:${PROJECT_NAME}>
    COMMENT "Copying ${PROJECT_NAME} to game directory"
)
