--[[
    FFI Bindings for Native Engine
    LuaJIT FFI declarations to interface with the C++ native library.
    
    Usage:
        local Native = require("native.bindings.ffi_bindings")
        if Native.available then
            Native.init()
        end
]]

local FFIBindings = {
    available = false,
    lib = nil,
}

-- Check if FFI is available (LuaJIT only)
local hasFFI, ffi = pcall(require, "ffi")

if hasFFI then
    -- FFI declarations matching gods_engine.h
    ffi.cdef[[
        // Core API
        int gods_init(void);
        void gods_shutdown(void);
        const char* gods_get_version(void);
        int gods_is_initialized(void);
        
        // Rendering API (Future)
        int gods_render_init(void* window_handle, int width, int height);
        void gods_render_begin_frame(void);
        void gods_render_end_frame(void);
        void gods_render_shutdown(void);
        
        // Model API (Future)
        unsigned int gods_model_load(const char* filepath);
        void gods_model_unload(unsigned int model_id);
        void gods_model_draw(unsigned int model_id, float x, float y, float z, float scale);
        
        // Animation API (Future)
        void gods_anim_play(unsigned int model_id, const char* anim_name, int loop);
        void gods_anim_stop(unsigned int model_id);
        void gods_anim_update(float dt);
    ]]
    
    -- Try to load the native library
    local libLoaded, lib = pcall(function()
        -- Try different library names based on platform
        local names = {
            "gods_native",
            "./gods_native",
            "./libgods_native",
        }
        
        for _, name in ipairs(names) do
            local ok, result = pcall(ffi.load, name)
            if ok then
                return result
            end
        end
        
        return nil
    end)
    
    if libLoaded and lib then
        FFIBindings.available = true
        FFIBindings.lib = lib
        print("[FFI] Native library loaded successfully")
    else
        print("[FFI] Native library not found (running in Lua-only mode)")
    end
else
    print("[FFI] LuaJIT FFI not available (running in Lua-only mode)")
end

-- ============================================
-- Wrapper Functions
-- ============================================

--- Initialize native engine
function FFIBindings.init()
    if not FFIBindings.available then return false end
    return FFIBindings.lib.gods_init() == 0
end

--- Shutdown native engine
function FFIBindings.shutdown()
    if not FFIBindings.available then return end
    FFIBindings.lib.gods_shutdown()
end

--- Get version string
function FFIBindings.getVersion()
    if not FFIBindings.available then return "N/A" end
    return ffi.string(FFIBindings.lib.gods_get_version())
end

--- Check if initialized
function FFIBindings.isInitialized()
    if not FFIBindings.available then return false end
    return FFIBindings.lib.gods_is_initialized() == 1
end

-- ============================================
-- Rendering Wrappers (Future)
-- ============================================

function FFIBindings.renderInit(windowHandle, width, height)
    if not FFIBindings.available then return false end
    return FFIBindings.lib.gods_render_init(windowHandle, width, height) == 0
end

function FFIBindings.renderBeginFrame()
    if not FFIBindings.available then return end
    FFIBindings.lib.gods_render_begin_frame()
end

function FFIBindings.renderEndFrame()
    if not FFIBindings.available then return end
    FFIBindings.lib.gods_render_end_frame()
end

function FFIBindings.renderShutdown()
    if not FFIBindings.available then return end
    FFIBindings.lib.gods_render_shutdown()
end

-- ============================================
-- Model Wrappers (Future)
-- ============================================

function FFIBindings.modelLoad(filepath)
    if not FFIBindings.available then return 0 end
    return FFIBindings.lib.gods_model_load(filepath)
end

function FFIBindings.modelUnload(modelId)
    if not FFIBindings.available then return end
    FFIBindings.lib.gods_model_unload(modelId)
end

function FFIBindings.modelDraw(modelId, x, y, z, scale)
    if not FFIBindings.available then return end
    FFIBindings.lib.gods_model_draw(modelId, x, y, z, scale or 1.0)
end

-- ============================================
-- Animation Wrappers (Future)
-- ============================================

function FFIBindings.animPlay(modelId, animName, loop)
    if not FFIBindings.available then return end
    FFIBindings.lib.gods_anim_play(modelId, animName, loop and 1 or 0)
end

function FFIBindings.animStop(modelId)
    if not FFIBindings.available then return end
    FFIBindings.lib.gods_anim_stop(modelId)
end

function FFIBindings.animUpdate(dt)
    if not FFIBindings.available then return end
    FFIBindings.lib.gods_anim_update(dt)
end

return FFIBindings
