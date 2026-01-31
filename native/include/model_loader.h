/*
 * Model Loader - glTF 2.0 model loading using tinygltf
 * 
 * Loads 3D character models with skeletal rigs for animation.
 */

#ifndef GODS_MODEL_LOADER_H
#define GODS_MODEL_LOADER_H

#include <cstdint>
#include <string>
#include <vector>
#include <unordered_map>

namespace gods {

// Vertex data for skinned mesh
struct SkinnedVertex {
    float position[3];
    float normal[3];
    float texcoord[2];
    uint8_t joints[4];    // Bone indices
    float weights[4];     // Bone weights
};

// Mesh data
struct Mesh {
    std::vector<SkinnedVertex> vertices;
    std::vector<uint32_t> indices;
    uint16_t vertexBufferHandle = UINT16_MAX;
    uint16_t indexBufferHandle = UINT16_MAX;
};

// Bone/Joint data
struct Joint {
    std::string name;
    int32_t parentIndex = -1;
    float inverseBindMatrix[16];
    float localTransform[16];
};

// Skeleton data
struct Skeleton {
    std::vector<Joint> joints;
    std::unordered_map<std::string, size_t> jointNameToIndex;
};

// Animation keyframe
struct Keyframe {
    float time;
    float value[4]; // Can be translation(3), rotation(4), or scale(3)
};

// Animation channel (one property of one joint)
struct AnimationChannel {
    size_t jointIndex;
    enum class Property { Translation, Rotation, Scale } property;
    std::vector<Keyframe> keyframes;
};

// Animation clip
struct AnimationClip {
    std::string name;
    float duration;
    std::vector<AnimationChannel> channels;
};

// Complete model with mesh, skeleton, and animations
struct Model {
    uint32_t id = 0;
    std::string name;
    std::vector<Mesh> meshes;
    Skeleton skeleton;
    std::vector<AnimationClip> animations;
    std::unordered_map<std::string, size_t> animationNameToIndex;
    
    // Transform
    float positionX = 0.0f;
    float positionY = 0.0f;
    float positionZ = 0.0f;
    float rotation = 0.0f;  // Y-axis rotation in radians
    float scale = 1.0f;
    
    // Current animation state
    size_t currentAnimation = 0;
    float animationTime = 0.0f;
    bool animationLooping = true;
    
    // Computed bone matrices for skinning
    std::vector<float> boneMatrices; // 16 floats per bone
};

/**
 * Initialize the model loader.
 */
void model_loader_init();

/**
 * Shutdown and cleanup all loaded models.
 */
void model_loader_shutdown();

/**
 * Load a glTF model from file.
 * @param filepath Path to .gltf or .glb file
 * @return Model ID, or 0 on failure
 */
uint32_t model_load(const char* filepath);

/**
 * Unload a model.
 * @param modelId Model ID to unload
 */
void model_unload(uint32_t modelId);

/**
 * Get a model by ID.
 * @param modelId Model ID
 * @return Pointer to model, or nullptr if not found
 */
Model* model_get(uint32_t modelId);

/**
 * Set model transform.
 */
void model_set_transform(uint32_t modelId, float x, float y, float z, float scale, float rotation);

/**
 * Draw all visible models.
 * @param dt Delta time for animation updates
 */
void model_draw_all(float dt);

/**
 * Get number of loaded models.
 */
size_t model_get_count();

} // namespace gods

#endif // GODS_MODEL_LOADER_H
