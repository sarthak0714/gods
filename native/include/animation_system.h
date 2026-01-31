/*
 * Animation System - ozz-animation integration
 * 
 * Handles skeletal animation playback, blending, and bone matrix computation.
 */

#ifndef GODS_ANIMATION_SYSTEM_H
#define GODS_ANIMATION_SYSTEM_H

#include <cstdint>
#include <string>

namespace gods {

// Forward declarations
struct Model;

/**
 * Initialize the animation system.
 */
void animation_init();

/**
 * Shutdown the animation system.
 */
void animation_shutdown();

/**
 * Set the current animation for a model.
 * @param modelId Model ID
 * @param animName Animation name
 * @param loop Whether to loop the animation
 */
void animation_set(uint32_t modelId, const char* animName, bool loop = true);

/**
 * Blend to a new animation over time.
 * @param modelId Model ID
 * @param animName Target animation name
 * @param blendTime Time to blend in seconds
 * @param loop Whether to loop the target animation
 */
void animation_blend(uint32_t modelId, const char* animName, float blendTime, bool loop = true);

/**
 * Stop animation on a model.
 * @param modelId Model ID
 */
void animation_stop(uint32_t modelId);

/**
 * Update all active animations.
 * @param dt Delta time in seconds
 */
void animation_update(float dt);

/**
 * Get animation progress (0.0 to 1.0).
 * @param modelId Model ID
 * @return Progress, or -1.0 if no animation
 */
float animation_get_progress(uint32_t modelId);

/**
 * Get current animation name.
 * @param modelId Model ID
 * @return Animation name, or empty string
 */
const char* animation_get_current(uint32_t modelId);

/**
 * Check if animation has finished (for non-looping animations).
 * @param modelId Model ID
 * @return true if finished
 */
bool animation_is_finished(uint32_t modelId);

/**
 * Sample animation at specific time and compute bone matrices.
 * Called internally during update.
 */
void animation_sample(Model* model, float time);

/**
 * Compute final bone matrices for GPU skinning.
 * Combines inverse bind matrices with current pose.
 */
void animation_compute_bone_matrices(Model* model);

} // namespace gods

#endif // GODS_ANIMATION_SYSTEM_H
