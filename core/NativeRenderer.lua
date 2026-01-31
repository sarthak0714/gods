--[[
    Native Renderer - Lua FFI bridge to C++ 3D engine
    
    Provides Lua interface for loading 3D models and playing
    skeletal animations for Hades 2-style character rendering.
]]

local ffi = require("ffi")

-- C declarations for the native engine
ffi.cdef[[
    // Core Engine
    int gods_init(void);
    void gods_shutdown(void);
    const char* gods_get_version(void);
    int gods_is_initialized(void);
    
    // Rendering
    int gods_render_init(void* window_handle, int width, int height);
    void gods_render_begin_frame(void);
    void gods_render_frame(float dt);
    void gods_render_end_frame(void);
    void gods_render_resize(int width, int height);
    void gods_render_shutdown(void);
    
    // Camera
    void gods_camera_set_position(float x, float y, float z);
    void gods_camera_set_angles(float pitch, float yaw);
    void gods_camera_set_ortho_size(float size);
    
    // Model Loading
    unsigned int gods_model_load(const char* filepath);
    void gods_model_unload(unsigned int model_id);
    void gods_model_set_transform(unsigned int model_id, float x, float y, float z, float scale, float rotation);
    void gods_model_set_visible(unsigned int model_id, int visible);
    int gods_model_get_count(void);
    
    // Animation
    void gods_anim_set(unsigned int model_id, const char* anim_name, int loop);
    void gods_anim_blend(unsigned int model_id, const char* anim_name, float blend_time, int loop);
    void gods_anim_stop(unsigned int model_id);
    float gods_anim_get_progress(unsigned int model_id);
    int gods_anim_is_finished(unsigned int model_id);
    const char* gods_anim_get_current(unsigned int model_id);
]]

local NativeRenderer = {}

-- Load the DLL
local lib = nil
local initialized = false

--- Initialize the native renderer
-- @param windowHandle Optional: native window handle (HWND on Windows)
-- @return true on success
function NativeRenderer.init(windowHandle)
    if initialized then
        return true
    end
    
    -- Try to load the DLL
    local success, result = pcall(function()
        return ffi.load("gods_native")
    end)
    
    if not success then
        print("[NativeRenderer] Failed to load gods_native.dll: " .. tostring(result))
        print("[NativeRenderer] Make sure the DLL is in the game directory")
        return false
    end
    
    lib = result
    
    -- Initialize the engine
    if lib.gods_init() ~= 0 then
        print("[NativeRenderer] Failed to initialize native engine")
        return false
    end
    
    -- Get window handle from Love2D (Windows-specific)
    local width, height = love.graphics.getDimensions()
    
    if windowHandle then
        -- Use provided handle
        if lib.gods_render_init(windowHandle, width, height) ~= 0 then
            print("[NativeRenderer] Failed to initialize renderer")
            return false
        end
    else
        -- Try to get handle from SDL (requires love.window.getDesktopDimensions workaround)
        -- For now, skip render init - will be done in first frame
        print("[NativeRenderer] No window handle provided - 3D rendering disabled")
        print("[NativeRenderer] To enable, pass HWND from external source")
    end
    
    local version = ffi.string(lib.gods_get_version())
    print("[NativeRenderer] Initialized v" .. version)
    
    initialized = true
    return true
end

--- Shutdown the native renderer
function NativeRenderer.shutdown()
    if lib and initialized then
        lib.gods_shutdown()
        initialized = false
        print("[NativeRenderer] Shutdown complete")
    end
end

--- Check if renderer is initialized
function NativeRenderer.isInitialized()
    return initialized and lib ~= nil
end

--- Get engine version
function NativeRenderer.getVersion()
    if not lib then return "not loaded" end
    return ffi.string(lib.gods_get_version())
end

-- ============================================
-- Rendering Functions
-- ============================================

--- Render a frame
-- @param dt Delta time
function NativeRenderer.renderFrame(dt)
    if lib and initialized then
        lib.gods_render_frame(dt)
    end
end

--- Begin a render frame
function NativeRenderer.beginFrame()
    if lib then
        lib.gods_render_begin_frame()
    end
end

--- End a render frame
function NativeRenderer.endFrame()
    if lib then
        lib.gods_render_end_frame()
    end
end

--- Resize the render viewport
function NativeRenderer.resize(width, height)
    if lib then
        lib.gods_render_resize(width, height)
    end
end

-- ============================================
-- Camera Functions
-- ============================================

--- Set camera position
function NativeRenderer.setCameraPosition(x, y, z)
    if lib then
        lib.gods_camera_set_position(x, y, z)
    end
end

--- Set camera angles (Hades 2 default: pitch=55, yaw=45)
function NativeRenderer.setCameraAngles(pitch, yaw)
    if lib then
        lib.gods_camera_set_angles(pitch, yaw)
    end
end

--- Set orthographic projection size
function NativeRenderer.setOrthoSize(size)
    if lib then
        lib.gods_camera_set_ortho_size(size)
    end
end

-- ============================================
-- Model Functions
-- ============================================

--- Load a 3D model from glTF file
-- @param filepath Path to .gltf or .glb file
-- @return Model ID, or nil on failure
function NativeRenderer.loadModel(filepath)
    if not lib then return nil end
    
    local modelId = lib.gods_model_load(filepath)
    if modelId == 0 then
        print("[NativeRenderer] Failed to load model: " .. filepath)
        return nil
    end
    
    print("[NativeRenderer] Loaded model: " .. filepath .. " (id=" .. modelId .. ")")
    return modelId
end

--- Unload a model
function NativeRenderer.unloadModel(modelId)
    if lib and modelId then
        lib.gods_model_unload(modelId)
    end
end

--- Set model transform
-- @param modelId Model ID
-- @param x World X position
-- @param y World Y position
-- @param z World Z position (height)
-- @param scale Uniform scale (default 1.0)
-- @param rotation Y-axis rotation in radians (default 0)
function NativeRenderer.setModelTransform(modelId, x, y, z, scale, rotation)
    if lib and modelId then
        lib.gods_model_set_transform(modelId, x, y, z, scale or 1.0, rotation or 0.0)
    end
end

--- Set model visibility
function NativeRenderer.setModelVisible(modelId, visible)
    if lib and modelId then
        lib.gods_model_set_visible(modelId, visible and 1 or 0)
    end
end

--- Get number of loaded models
function NativeRenderer.getModelCount()
    if not lib then return 0 end
    return lib.gods_model_get_count()
end

-- ============================================
-- Animation Functions
-- ============================================

--- Set animation on a model
-- @param modelId Model ID
-- @param animName Animation name
-- @param loop Whether to loop (default true)
function NativeRenderer.setAnimation(modelId, animName, loop)
    if lib and modelId and animName then
        local loopInt = (loop == nil or loop) and 1 or 0
        lib.gods_anim_set(modelId, animName, loopInt)
    end
end

--- Blend to a new animation
-- @param modelId Model ID
-- @param animName Target animation name
-- @param blendTime Blend duration in seconds (default 0.2)
-- @param loop Whether to loop (default true)
function NativeRenderer.blendAnimation(modelId, animName, blendTime, loop)
    if lib and modelId and animName then
        local loopInt = (loop == nil or loop) and 1 or 0
        lib.gods_anim_blend(modelId, animName, blendTime or 0.2, loopInt)
    end
end

--- Stop animation on a model
function NativeRenderer.stopAnimation(modelId)
    if lib and modelId then
        lib.gods_anim_stop(modelId)
    end
end

--- Get animation progress (0.0 to 1.0)
function NativeRenderer.getAnimationProgress(modelId)
    if not lib or not modelId then return 0 end
    return lib.gods_anim_get_progress(modelId)
end

--- Check if animation has finished (for non-looping animations)
function NativeRenderer.isAnimationFinished(modelId)
    if not lib or not modelId then return true end
    return lib.gods_anim_is_finished(modelId) == 1
end

--- Get current animation name
function NativeRenderer.getCurrentAnimation(modelId)
    if not lib or not modelId then return "" end
    return ffi.string(lib.gods_anim_get_current(modelId))
end

return NativeRenderer
