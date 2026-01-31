/*
 * Renderer - bgfx-based 3D rendering implementation
 */

#include "renderer.h"
#include <bgfx/bgfx.h>
#include <bgfx/platform.h>
#include <bx/math.h>
#include <cstdio>
#include <cstring>

namespace gods {

// Global renderer state
static RendererState g_renderer;

// View IDs
static const bgfx::ViewId kMainView = 0;

bool renderer_init(void* nativeWindowHandle, uint32_t width, uint32_t height) {
    if (g_renderer.initialized) {
        printf("[Renderer] Already initialized\n");
        return true;
    }
    
    printf("[Renderer] Initializing bgfx (%ux%u)...\n", width, height);
    
    // Setup platform data
    bgfx::PlatformData pd;
    std::memset(&pd, 0, sizeof(pd));
    pd.nwh = nativeWindowHandle;
    bgfx::setPlatformData(pd);
    
    // Initialize bgfx
    bgfx::Init init;
    init.type = bgfx::RendererType::Count; // Auto-select best renderer
    init.resolution.width = width;
    init.resolution.height = height;
    init.resolution.reset = BGFX_RESET_VSYNC;
    
    if (!bgfx::init(init)) {
        printf("[Renderer] Failed to initialize bgfx\n");
        return false;
    }
    
    // Get actual renderer type
    const char* rendererName = bgfx::getRendererName(bgfx::getRendererType());
    printf("[Renderer] Using renderer: %s\n", rendererName);
    
    // Set view clear
    bgfx::setViewClear(kMainView,
        BGFX_CLEAR_COLOR | BGFX_CLEAR_DEPTH,
        0x000000ff, // Clear to black (transparent for compositing)
        1.0f,
        0
    );
    
    // Set view rect
    bgfx::setViewRect(kMainView, 0, 0, uint16_t(width), uint16_t(height));
    
    g_renderer.width = width;
    g_renderer.height = height;
    g_renderer.initialized = true;
    
    printf("[Renderer] Initialized successfully\n");
    return true;
}

void renderer_shutdown() {
    if (!g_renderer.initialized) {
        return;
    }
    
    printf("[Renderer] Shutting down...\n");
    
    // Cleanup framebuffer if created
    if (g_renderer.framebufferHandle != UINT16_MAX) {
        bgfx::destroy(bgfx::FrameBufferHandle{g_renderer.framebufferHandle});
    }
    
    bgfx::shutdown();
    
    g_renderer.initialized = false;
    printf("[Renderer] Shutdown complete\n");
}

void renderer_begin_frame() {
    if (!g_renderer.initialized) return;
    
    // Touch the view to ensure it's active even if nothing is rendered
    bgfx::touch(kMainView);
}

void renderer_end_frame() {
    if (!g_renderer.initialized) return;
    
    // Advance to next frame
    bgfx::frame();
}

void renderer_resize(uint32_t width, uint32_t height) {
    if (!g_renderer.initialized) return;
    
    g_renderer.width = width;
    g_renderer.height = height;
    
    bgfx::reset(width, height, BGFX_RESET_VSYNC);
    bgfx::setViewRect(kMainView, 0, 0, uint16_t(width), uint16_t(height));
    
    printf("[Renderer] Resized to %ux%u\n", width, height);
}

void renderer_set_camera(const Camera& camera) {
    g_renderer.camera = camera;
    
    if (!g_renderer.initialized) return;
    
    // Compute view matrix
    float eye[3] = { camera.posX, camera.posY, camera.posZ };
    float at[3] = { camera.posX, camera.posY, 0.0f }; // Look at center
    float up[3] = { 0.0f, 1.0f, 0.0f };
    
    // Apply rotation
    float pitchRad = bx::toRad(camera.pitch);
    float yawRad = bx::toRad(camera.yaw);
    
    // Calculate look direction from angles
    float cosP = bx::cos(pitchRad);
    float sinP = bx::sin(pitchRad);
    float cosY = bx::cos(yawRad);
    float sinY = bx::sin(yawRad);
    
    float dir[3] = {
        cosP * sinY,
        -sinP,
        cosP * cosY
    };
    
    at[0] = eye[0] + dir[0] * 10.0f;
    at[1] = eye[1] + dir[1] * 10.0f;
    at[2] = eye[2] + dir[2] * 10.0f;
    
    float view[16];
    bx::mtxLookAt(view, bx::Vec3(eye[0], eye[1], eye[2]), 
                        bx::Vec3(at[0], at[1], at[2]),
                        bx::Vec3(up[0], up[1], up[2]));
    
    // Compute orthographic projection matrix
    float aspect = float(g_renderer.width) / float(g_renderer.height);
    float orthoWidth = camera.orthoSize * aspect;
    float orthoHeight = camera.orthoSize;
    
    float proj[16];
    bx::mtxOrtho(proj, 
        -orthoWidth, orthoWidth,
        -orthoHeight, orthoHeight,
        camera.nearPlane, camera.farPlane,
        0.0f,
        bgfx::getCaps()->homogeneousDepth
    );
    
    bgfx::setViewTransform(kMainView, view, proj);
}

const Camera& renderer_get_camera() {
    return g_renderer.camera;
}

bool renderer_is_initialized() {
    return g_renderer.initialized;
}

bool renderer_get_framebuffer_data(void** outData, uint32_t* outWidth, uint32_t* outHeight) {
    // TODO: Implement render-to-texture and readback for Love2D compositing
    // For now, return nullptr - we'll render directly to window
    *outData = nullptr;
    *outWidth = g_renderer.width;
    *outHeight = g_renderer.height;
    return false;
}

} // namespace gods
