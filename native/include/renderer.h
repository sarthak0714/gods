/*
 * Renderer - bgfx-based 3D rendering system
 * 
 * Handles initialization, camera setup, and render-to-texture
 * for compositing 3D characters with 2D backgrounds in Love2D.
 */

#ifndef GODS_RENDERER_H
#define GODS_RENDERER_H

#include <cstdint>

namespace gods {

// Camera configuration for Hades 2-style orthographic view
struct Camera {
    float pitch = 55.0f;     // X rotation (looking down)
    float yaw = 45.0f;       // Y rotation (isometric angle)  
    float orthoSize = 10.0f; // Orthographic projection half-size
    float nearPlane = 0.1f;
    float farPlane = 1000.0f;
    float posX = 0.0f;
    float posY = 0.0f;
    float posZ = 50.0f;      // Height above scene
};

// Renderer state
struct RendererState {
    bool initialized = false;
    uint32_t width = 1280;
    uint32_t height = 720;
    Camera camera;
    
    // Framebuffer for render-to-texture
    uint16_t framebufferHandle = UINT16_MAX;
    uint16_t colorTextureHandle = UINT16_MAX;
    uint16_t depthTextureHandle = UINT16_MAX;
};

/**
 * Initialize the bgfx renderer with a native window handle.
 * @param nativeWindowHandle Platform-specific window handle (HWND on Windows)
 * @param width Window width
 * @param height Window height
 * @return true on success
 */
bool renderer_init(void* nativeWindowHandle, uint32_t width, uint32_t height);

/**
 * Shutdown the renderer and release resources.
 */
void renderer_shutdown();

/**
 * Begin a new frame.
 */
void renderer_begin_frame();

/**
 * End the current frame and present.
 */
void renderer_end_frame();

/**
 * Update renderer viewport size.
 */
void renderer_resize(uint32_t width, uint32_t height);

/**
 * Set camera parameters.
 */
void renderer_set_camera(const Camera& camera);

/**
 * Get the current camera.
 */
const Camera& renderer_get_camera();

/**
 * Check if renderer is initialized.
 */
bool renderer_is_initialized();

/**
 * Get framebuffer texture data for Love2D compositing.
 * @param outData Pointer to receive pixel data
 * @param outWidth Output width
 * @param outHeight Output height
 * @return true if successful
 */
bool renderer_get_framebuffer_data(void** outData, uint32_t* outWidth, uint32_t* outHeight);

} // namespace gods

#endif // GODS_RENDERER_H
