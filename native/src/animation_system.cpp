/*
 * Animation System - Skeletal animation implementation
 */

#include "animation_system.h"
#include "model_loader.h"
#include <cstdio>
#include <cmath>
#include <cstring>

namespace gods {

// Blend state for smooth transitions
struct BlendState {
    uint32_t modelId = 0;
    size_t fromAnimation = 0;
    size_t toAnimation = 0;
    float blendTime = 0.0f;
    float blendProgress = 0.0f;
    bool active = false;
};

static std::vector<BlendState> g_blendStates;

void animation_init() {
    printf("[Animation] Initializing...\n");
    g_blendStates.clear();
    printf("[Animation] Initialized\n");
}

void animation_shutdown() {
    printf("[Animation] Shutting down...\n");
    g_blendStates.clear();
    printf("[Animation] Shutdown complete\n");
}

void animation_set(uint32_t modelId, const char* animName, bool loop) {
    Model* model = model_get(modelId);
    if (!model) return;
    
    auto it = model->animationNameToIndex.find(animName);
    if (it == model->animationNameToIndex.end()) {
        printf("[Animation] Animation '%s' not found on model %u\n", animName, modelId);
        return;
    }
    
    model->currentAnimation = it->second;
    model->animationTime = 0.0f;
    model->animationLooping = loop;
    
    printf("[Animation] Set animation '%s' on model %u (loop=%d)\n", animName, modelId, loop);
}

void animation_blend(uint32_t modelId, const char* animName, float blendTime, bool loop) {
    Model* model = model_get(modelId);
    if (!model) return;
    
    auto it = model->animationNameToIndex.find(animName);
    if (it == model->animationNameToIndex.end()) {
        printf("[Animation] Animation '%s' not found for blend\n", animName);
        return;
    }
    
    // Create or update blend state
    BlendState* state = nullptr;
    for (auto& s : g_blendStates) {
        if (s.modelId == modelId) {
            state = &s;
            break;
        }
    }
    
    if (!state) {
        g_blendStates.push_back({});
        state = &g_blendStates.back();
    }
    
    state->modelId = modelId;
    state->fromAnimation = model->currentAnimation;
    state->toAnimation = it->second;
    state->blendTime = blendTime;
    state->blendProgress = 0.0f;
    state->active = true;
    
    model->animationLooping = loop;
}

void animation_stop(uint32_t modelId) {
    Model* model = model_get(modelId);
    if (!model) return;
    
    model->animationTime = 0.0f;
    
    // Remove any blend state
    for (auto it = g_blendStates.begin(); it != g_blendStates.end(); ) {
        if (it->modelId == modelId) {
            it = g_blendStates.erase(it);
        } else {
            ++it;
        }
    }
}

// Linear interpolation
static float lerp(float a, float b, float t) {
    return a + (b - a) * t;
}

// Quaternion spherical interpolation
static void slerp(const float* q1, const float* q2, float t, float* out) {
    float dot = q1[0]*q2[0] + q1[1]*q2[1] + q1[2]*q2[2] + q1[3]*q2[3];
    
    float q2n[4];
    if (dot < 0.0f) {
        dot = -dot;
        q2n[0] = -q2[0]; q2n[1] = -q2[1]; q2n[2] = -q2[2]; q2n[3] = -q2[3];
    } else {
        q2n[0] = q2[0]; q2n[1] = q2[1]; q2n[2] = q2[2]; q2n[3] = q2[3];
    }
    
    if (dot > 0.9995f) {
        // Linear interpolation for very close quaternions
        out[0] = lerp(q1[0], q2n[0], t);
        out[1] = lerp(q1[1], q2n[1], t);
        out[2] = lerp(q1[2], q2n[2], t);
        out[3] = lerp(q1[3], q2n[3], t);
    } else {
        float theta = std::acos(dot);
        float sinTheta = std::sin(theta);
        float w1 = std::sin((1.0f - t) * theta) / sinTheta;
        float w2 = std::sin(t * theta) / sinTheta;
        
        out[0] = q1[0] * w1 + q2n[0] * w2;
        out[1] = q1[1] * w1 + q2n[1] * w2;
        out[2] = q1[2] * w1 + q2n[2] * w2;
        out[3] = q1[3] * w1 + q2n[3] * w2;
    }
    
    // Normalize
    float len = std::sqrt(out[0]*out[0] + out[1]*out[1] + out[2]*out[2] + out[3]*out[3]);
    if (len > 0.0f) {
        out[0] /= len; out[1] /= len; out[2] /= len; out[3] /= len;
    }
}

// Sample animation at time and compute local transforms
void animation_sample(Model* model, float time) {
    if (model->animations.empty()) return;
    if (model->currentAnimation >= model->animations.size()) return;
    
    const AnimationClip& clip = model->animations[model->currentAnimation];
    
    // For each channel, find keyframes and interpolate
    for (const auto& channel : clip.channels) {
        if (channel.keyframes.empty()) continue;
        if (channel.jointIndex >= model->skeleton.joints.size()) continue;
        
        // Find surrounding keyframes
        size_t k0 = 0, k1 = 0;
        for (size_t i = 0; i < channel.keyframes.size() - 1; ++i) {
            if (time >= channel.keyframes[i].time && time < channel.keyframes[i + 1].time) {
                k0 = i;
                k1 = i + 1;
                break;
            }
        }
        
        if (k1 == 0) {
            // Use last keyframe
            k0 = k1 = channel.keyframes.size() - 1;
        }
        
        // Interpolation factor
        float t = 0.0f;
        if (k0 != k1) {
            float t0 = channel.keyframes[k0].time;
            float t1 = channel.keyframes[k1].time;
            t = (time - t0) / (t1 - t0);
        }
        
        const float* v0 = channel.keyframes[k0].value;
        const float* v1 = channel.keyframes[k1].value;
        
        Joint& joint = model->skeleton.joints[channel.jointIndex];
        
        switch (channel.property) {
            case AnimationChannel::Property::Translation:
                // Store in local transform (translation in columns 12,13,14)
                joint.localTransform[12] = lerp(v0[0], v1[0], t);
                joint.localTransform[13] = lerp(v0[1], v1[1], t);
                joint.localTransform[14] = lerp(v0[2], v1[2], t);
                break;
                
            case AnimationChannel::Property::Rotation: {
                // Quaternion slerp, then convert to rotation matrix
                float q[4];
                slerp(v0, v1, t, q);
                
                // Convert quaternion to rotation matrix (3x3 portion)
                float x = q[0], y = q[1], z = q[2], w = q[3];
                float xx = x*x, yy = y*y, zz = z*z;
                float xy = x*y, xz = x*z, yz = y*z;
                float wx = w*x, wy = w*y, wz = w*z;
                
                joint.localTransform[0] = 1.0f - 2.0f*(yy + zz);
                joint.localTransform[1] = 2.0f*(xy + wz);
                joint.localTransform[2] = 2.0f*(xz - wy);
                
                joint.localTransform[4] = 2.0f*(xy - wz);
                joint.localTransform[5] = 1.0f - 2.0f*(xx + zz);
                joint.localTransform[6] = 2.0f*(yz + wx);
                
                joint.localTransform[8] = 2.0f*(xz + wy);
                joint.localTransform[9] = 2.0f*(yz - wx);
                joint.localTransform[10] = 1.0f - 2.0f*(xx + yy);
                break;
            }
                
            case AnimationChannel::Property::Scale:
                // Scale in diagonal
                joint.localTransform[0] *= lerp(v0[0], v1[0], t);
                joint.localTransform[5] *= lerp(v0[1], v1[1], t);
                joint.localTransform[10] *= lerp(v0[2], v1[2], t);
                break;
        }
    }
}

// Matrix multiplication (4x4)
static void mat4_multiply(const float* a, const float* b, float* out) {
    for (int i = 0; i < 4; ++i) {
        for (int j = 0; j < 4; ++j) {
            out[i * 4 + j] = 0.0f;
            for (int k = 0; k < 4; ++k) {
                out[i * 4 + j] += a[i * 4 + k] * b[k * 4 + j];
            }
        }
    }
}

void animation_compute_bone_matrices(Model* model) {
    if (model->skeleton.joints.empty()) return;
    
    std::vector<float> globalTransforms(model->skeleton.joints.size() * 16);
    
    // Compute global transforms (parent-to-child hierarchy)
    for (size_t i = 0; i < model->skeleton.joints.size(); ++i) {
        const Joint& joint = model->skeleton.joints[i];
        float* global = &globalTransforms[i * 16];
        
        if (joint.parentIndex < 0) {
            // Root joint - local = global
            std::memcpy(global, joint.localTransform, 16 * sizeof(float));
        } else {
            // Multiply parent global by local
            const float* parentGlobal = &globalTransforms[joint.parentIndex * 16];
            mat4_multiply(parentGlobal, joint.localTransform, global);
        }
    }
    
    // Compute final bone matrices (global * inverseBindMatrix)
    for (size_t i = 0; i < model->skeleton.joints.size(); ++i) {
        const Joint& joint = model->skeleton.joints[i];
        const float* global = &globalTransforms[i * 16];
        float* bone = &model->boneMatrices[i * 16];
        
        mat4_multiply(global, joint.inverseBindMatrix, bone);
    }
}

void animation_update(float dt) {
    // Update blend states
    for (auto& state : g_blendStates) {
        if (!state.active) continue;
        
        Model* model = model_get(state.modelId);
        if (!model) {
            state.active = false;
            continue;
        }
        
        state.blendProgress += dt / state.blendTime;
        
        if (state.blendProgress >= 1.0f) {
            // Blend complete
            model->currentAnimation = state.toAnimation;
            model->animationTime = 0.0f;
            state.active = false;
        }
    }
    
    // Clean up inactive blend states
    g_blendStates.erase(
        std::remove_if(g_blendStates.begin(), g_blendStates.end(),
            [](const BlendState& s) { return !s.active; }),
        g_blendStates.end()
    );
}

float animation_get_progress(uint32_t modelId) {
    Model* model = model_get(modelId);
    if (!model || model->animations.empty()) return -1.0f;
    if (model->currentAnimation >= model->animations.size()) return -1.0f;
    
    const AnimationClip& clip = model->animations[model->currentAnimation];
    if (clip.duration <= 0.0f) return 0.0f;
    
    return model->animationTime / clip.duration;
}

const char* animation_get_current(uint32_t modelId) {
    Model* model = model_get(modelId);
    if (!model || model->animations.empty()) return "";
    if (model->currentAnimation >= model->animations.size()) return "";
    
    return model->animations[model->currentAnimation].name.c_str();
}

bool animation_is_finished(uint32_t modelId) {
    Model* model = model_get(modelId);
    if (!model || model->animations.empty()) return true;
    if (model->currentAnimation >= model->animations.size()) return true;
    
    if (model->animationLooping) return false;
    
    const AnimationClip& clip = model->animations[model->currentAnimation];
    return model->animationTime >= clip.duration;
}

} // namespace gods
