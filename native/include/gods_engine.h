/*
 * Gods Engine - Native C++ Extension
 * 
 * This header defines the public API for the native engine extension.
 * Currently a placeholder for future The Forge rendering integration.
 * 
 * Based on Hades 2 architecture patterns.
 */

#ifndef GODS_ENGINE_H
#define GODS_ENGINE_H

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
 * @return Version string (e.g., "0.1.0")
 */
GODS_API const char* gods_get_version(void);

/**
 * Check if engine is initialized.
 * @return 1 if initialized, 0 otherwise
 */
GODS_API int gods_is_initialized(void);

// ============================================
// Rendering API (Future - The Forge)
// ============================================

/**
 * Initialize rendering subsystem.
 * @param window_handle Platform window handle
 * @param width Window width
 * @param height Window height
 * @return 0 on success
 */
GODS_API int gods_render_init(void* window_handle, int width, int height);

/**
 * Begin a render frame.
 */
GODS_API void gods_render_begin_frame(void);

/**
 * End the current render frame.
 */
GODS_API void gods_render_end_frame(void);

/**
 * Shutdown rendering subsystem.
 */
GODS_API void gods_render_shutdown(void);

// ============================================
// Model Loading API (Future - Granny SDK)
// ============================================

/**
 * Load a 3D model from file.
 * @param filepath Path to model file
 * @return Model handle, or 0 on failure
 */
GODS_API unsigned int gods_model_load(const char* filepath);

/**
 * Unload a model.
 * @param model_id Model handle
 */
GODS_API void gods_model_unload(unsigned int model_id);

/**
 * Draw a model.
 * @param model_id Model handle
 * @param x World X position
 * @param y World Y position
 * @param z World Z position
 * @param scale Scale factor
 */
GODS_API void gods_model_draw(unsigned int model_id, float x, float y, float z, float scale);

// ============================================
// Animation API (Future)
// ============================================

/**
 * Play animation on a model.
 * @param model_id Model handle
 * @param anim_name Animation name
 * @param loop Whether to loop
 */
GODS_API void gods_anim_play(unsigned int model_id, const char* anim_name, int loop);

/**
 * Stop animation on a model.
 * @param model_id Model handle
 */
GODS_API void gods_anim_stop(unsigned int model_id);

/**
 * Update animations (call each frame).
 * @param dt Delta time in seconds
 */
GODS_API void gods_anim_update(float dt);

#ifdef __cplusplus
}
#endif

#endif // GODS_ENGINE_H
