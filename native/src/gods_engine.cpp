/*
 * Gods Engine - Main C++ Extension Implementation
 * 
 * Integrates bgfx rendering, glTF model loading, and skeletal animation
 * for Hades 2-style 3D character rendering.
 */

#include "gods_engine.h"
#include "renderer.h"
#include "model_loader.h"
#include "animation_system.h"
#include <cstdio>

// Engine state
static bool g_initialized = false;
static const char* g_version = "0.2.0";

// ============================================
// Core Engine API
// ============================================

GODS_API int gods_init(void) {
    if (g_initialized) {
        printf("[GodsEngine] Already initialized\n");
        return 0;
    }
    
    printf("[GodsEngine] Initializing native engine v%s\n", g_version);
    
    // Initialize subsystems
    gods::model_loader_init();
    gods::animation_init();
    
    g_initialized = true;
    printf("[GodsEngine] Native engine initialized\n");
    
    return 0;
}

GODS_API void gods_shutdown(void) {
    if (!g_initialized) {
        return;
    }
    
    printf("[GodsEngine] Shutting down native engine\n");
    
    // Shutdown subsystems in reverse order
    gods::animation_shutdown();
    gods::model_loader_shutdown();
    gods::renderer_shutdown();
    
    g_initialized = false;
    printf("[GodsEngine] Shutdown complete\n");
}

GODS_API const char* gods_get_version(void) {
    return g_version;
}

GODS_API int gods_is_initialized(void) {
    return g_initialized ? 1 : 0;
}

// ============================================
// Rendering API
// ============================================

GODS_API int gods_render_init(void* window_handle, int width, int height) {
    printf("[GodsEngine] Render init (window=%p, %dx%d)\n", 
           window_handle, width, height);
    
    if (!gods::renderer_init(window_handle, uint32_t(width), uint32_t(height))) {
        printf("[GodsEngine] Failed to initialize renderer\n");
        return -1;
    }
    
    // Set default camera (Hades 2 style)
    gods::Camera camera;
    camera.pitch = 55.0f;
    camera.yaw = 45.0f;
    camera.orthoSize = 10.0f;
    camera.posZ = 50.0f;
    gods::renderer_set_camera(camera);
    
    return 0;
}

GODS_API void gods_render_begin_frame(void) {
    gods::renderer_begin_frame();
}

GODS_API void gods_render_frame(float dt) {
    if (!gods::renderer_is_initialized()) return;
    
    gods::renderer_begin_frame();
    
    // Update animations
    gods::animation_update(dt);
    
    // Draw all models
    gods::model_draw_all(dt);
    
    gods::renderer_end_frame();
}

GODS_API void gods_render_end_frame(void) {
    gods::renderer_end_frame();
}

GODS_API void gods_render_resize(int width, int height) {
    gods::renderer_resize(uint32_t(width), uint32_t(height));
}

GODS_API void gods_render_shutdown(void) {
    gods::renderer_shutdown();
}

GODS_API void gods_camera_set_position(float x, float y, float z) {
    gods::Camera camera = gods::renderer_get_camera();
    camera.posX = x;
    camera.posY = y;
    camera.posZ = z;
    gods::renderer_set_camera(camera);
}

GODS_API void gods_camera_set_angles(float pitch, float yaw) {
    gods::Camera camera = gods::renderer_get_camera();
    camera.pitch = pitch;
    camera.yaw = yaw;
    gods::renderer_set_camera(camera);
}

GODS_API void gods_camera_set_ortho_size(float size) {
    gods::Camera camera = gods::renderer_get_camera();
    camera.orthoSize = size;
    gods::renderer_set_camera(camera);
}

// ============================================
// Model Loading API
// ============================================

GODS_API unsigned int gods_model_load(const char* filepath) {
    return gods::model_load(filepath);
}

GODS_API void gods_model_unload(unsigned int model_id) {
    gods::model_unload(model_id);
}

GODS_API void gods_model_set_transform(unsigned int model_id, 
                                        float x, float y, float z, 
                                        float scale, float rotation) {
    gods::model_set_transform(model_id, x, y, z, scale, rotation);
}

GODS_API void gods_model_set_visible(unsigned int model_id, int visible) {
    // TODO: Implement visibility toggle
    (void)model_id;
    (void)visible;
}

GODS_API int gods_model_get_count(void) {
    return int(gods::model_get_count());
}

// ============================================
// Animation API
// ============================================

GODS_API void gods_anim_set(unsigned int model_id, const char* anim_name, int loop) {
    gods::animation_set(model_id, anim_name, loop != 0);
}

GODS_API void gods_anim_blend(unsigned int model_id, const char* anim_name, 
                               float blend_time, int loop) {
    gods::animation_blend(model_id, anim_name, blend_time, loop != 0);
}

GODS_API void gods_anim_stop(unsigned int model_id) {
    gods::animation_stop(model_id);
}

GODS_API float gods_anim_get_progress(unsigned int model_id) {
    return gods::animation_get_progress(model_id);
}

GODS_API int gods_anim_is_finished(unsigned int model_id) {
    return gods::animation_is_finished(model_id) ? 1 : 0;
}

GODS_API const char* gods_anim_get_current(unsigned int model_id) {
    return gods::animation_get_current(model_id);
}
