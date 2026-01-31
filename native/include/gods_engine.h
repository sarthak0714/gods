/*
 * Gods Engine - Native C++ Extension
 * 
 * Public API for the native 3D rendering engine.
 * Provides bgfx-based rendering for 3D character models
 * with skeletal animation, composited with Love2D 2D backgrounds.
 */

#ifndef GODS_ENGINE_H
#define GODS_ENGINE_H

#include <cstdint>

// Platform-specific export macros
#ifdef _WIN32
    #ifdef GODS_BUILDING_DLL
        #define GODS_API __declspec(dllexport)
    #else
        #define GODS_API __declspec(dllimport)
    #endif
#else
    #define GODS_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// ============================================
// Core Engine API
// ============================================

/**
 * Initialize the native engine.
 * @return 0 on success, non-zero on failure
 */
GODS_API int gods_init(void);

/**
 * Shutdown the native engine and cleanup resources.
 */
GODS_API void gods_shutdown(void);

/**
 * Get engine version string.
 * @return Version string (e.g., "0.2.0")
 */
GODS_API const char* gods_get_version(void);

/**
 * Check if engine is initialized.
 * @return 1 if initialized, 0 otherwise
 */
GODS_API int gods_is_initialized(void);

// ============================================
// Rendering API (bgfx-based)
// ============================================

/**
 * Initialize rendering with a native window handle.
 * On Windows, pass HWND. On other platforms, pass appropriate handle.
 * @param window_handle Platform window handle
 * @param width Window width
 * @param height Window height
 * @return 0 on success
 */
GODS_API int gods_render_init(void* window_handle, int width, int height);

/**
 * Begin a render frame.
 * Call before drawing any models.
 */
GODS_API void gods_render_begin_frame(void);

/**
 * Render all models and end the frame.
 * @param dt Delta time for animation updates
 */
GODS_API void gods_render_frame(float dt);

/**
 * End the current render frame.
 */
GODS_API void gods_render_end_frame(void);

/**
 * Resize the render viewport.
 */
GODS_API void gods_render_resize(int width, int height);

/**
 * Shutdown rendering subsystem.
 */
GODS_API void gods_render_shutdown(void);

/**
 * Set camera position for the orthographic view.
 */
GODS_API void gods_camera_set_position(float x, float y, float z);

/**
 * Set camera angles (pitch and yaw).
 */
GODS_API void gods_camera_set_angles(float pitch, float yaw);

/**
 * Set orthographic projection size.
 */
GODS_API void gods_camera_set_ortho_size(float size);

// ============================================
// Model Loading API (glTF)
// ============================================

/**
 * Load a 3D model from a glTF file.
 * @param filepath Path to .gltf or .glb file
 * @return Model handle, or 0 on failure
 */
GODS_API unsigned int gods_model_load(const char* filepath);

/**
 * Unload a model.
 * @param model_id Model handle
 */
GODS_API void gods_model_unload(unsigned int model_id);

/**
 * Set model transform (position, scale, rotation).
 * @param model_id Model handle
 * @param x World X position
 * @param y World Y position  
 * @param z World Z position (height)
 * @param scale Uniform scale factor
 * @param rotation Y-axis rotation in radians
 */
GODS_API void gods_model_set_transform(unsigned int model_id, 
                                        float x, float y, float z, 
                                        float scale, float rotation);

/**
 * Set model visibility.
 */
GODS_API void gods_model_set_visible(unsigned int model_id, int visible);

/**
 * Get model count.
 */
GODS_API int gods_model_get_count(void);

// ============================================
// Animation API
// ============================================

/**
 * Set animation on a model.
 * @param model_id Model handle
 * @param anim_name Animation name
 * @param loop Whether to loop (1 = loop, 0 = play once)
 */
GODS_API void gods_anim_set(unsigned int model_id, const char* anim_name, int loop);

/**
 * Blend to a new animation over time.
 * @param model_id Model handle
 * @param anim_name Target animation name
 * @param blend_time Blend duration in seconds
 * @param loop Whether to loop
 */
GODS_API void gods_anim_blend(unsigned int model_id, const char* anim_name, 
                               float blend_time, int loop);

/**
 * Stop animation on a model.
 * @param model_id Model handle
 */
GODS_API void gods_anim_stop(unsigned int model_id);

/**
 * Get animation progress (0.0 to 1.0).
 * @param model_id Model handle
 * @return Progress, or -1.0 if no animation
 */
GODS_API float gods_anim_get_progress(unsigned int model_id);

/**
 * Check if current animation has finished.
 * @param model_id Model handle
 * @return 1 if finished, 0 otherwise
 */
GODS_API int gods_anim_is_finished(unsigned int model_id);

/**
 * Get current animation name.
 * @param model_id Model handle
 * @return Animation name, or empty string
 */
GODS_API const char* gods_anim_get_current(unsigned int model_id);

#ifdef __cplusplus
}
#endif

#endif // GODS_ENGINE_H
