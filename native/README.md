# Native C++ Extension

This directory contains the C++ native extension for the Gods engine.

## Prerequisites

1. **CMake** (3.20 or higher)
   - Download from: https://cmake.org/download/
   - Or install via winget: `winget install Kitware.CMake`

2. **Visual Studio 2022** with C++ workload
   - Download from: https://visualstudio.microsoft.com/downloads/
   - Select "Desktop development with C++" workload

## Building

```powershell
cd native
cmake -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
```

The DLL will be automatically copied to the game root directory.

## Structure

```
native/
├── CMakeLists.txt          # Build configuration
├── include/
│   └── gods_engine.h       # Public C API header
├── src/
│   └── gods_engine.cpp     # Implementation (stub)
└── bindings/
    └── ffi_bindings.lua    # LuaJIT FFI bindings
```

## Current Status

This is a **placeholder** implementation. All functions are stubs that do nothing.

Future work:
- Integrate The Forge rendering framework
- Add Granny SDK for model loading
- Implement actual rendering pipeline

## Usage from Lua

```lua
-- The game will automatically try to load the native library
local Native = require("native.bindings.ffi_bindings")

if Native.available then
    print("Native engine version: " .. Native.getVersion())
    Native.init()
else
    print("Running in Lua-only mode")
end
```
