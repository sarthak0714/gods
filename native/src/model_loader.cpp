/*
 * Model Loader - glTF model loading implementation
 */

#include "model_loader.h"

#define TINYGLTF_IMPLEMENTATION
#define TINYGLTF_NO_EXTERNAL_IMAGE
#define TINYGLTF_NO_STB_IMAGE
#define TINYGLTF_NO_STB_IMAGE_WRITE
#include "tiny_gltf.h"

#include <bgfx/bgfx.h>
#include <cstdio>
#include <unordered_map>

namespace gods {

// Global model storage
static std::unordered_map<uint32_t, Model> g_models;
static uint32_t g_nextModelId = 1;
static tinygltf::TinyGLTF g_loader;

// Vertex layout for skinned meshes
static bgfx::VertexLayout g_skinnedVertexLayout;
static bool g_layoutInitialized = false;

void model_loader_init() {
    printf("[ModelLoader] Initializing...\n");
    
    if (!g_layoutInitialized) {
        g_skinnedVertexLayout
            .begin()
            .add(bgfx::Attrib::Position, 3, bgfx::AttribType::Float)
            .add(bgfx::Attrib::Normal, 3, bgfx::AttribType::Float)
            .add(bgfx::Attrib::TexCoord0, 2, bgfx::AttribType::Float)
            .add(bgfx::Attrib::Indices, 4, bgfx::AttribType::Uint8, true)
            .add(bgfx::Attrib::Weight, 4, bgfx::AttribType::Float)
            .end();
        g_layoutInitialized = true;
    }
    
    printf("[ModelLoader] Initialized\n");
}

void model_loader_shutdown() {
    printf("[ModelLoader] Shutting down...\n");
    
    // Cleanup all models
    for (auto& pair : g_models) {
        for (auto& mesh : pair.second.meshes) {
            if (mesh.vertexBufferHandle != UINT16_MAX) {
                bgfx::destroy(bgfx::VertexBufferHandle{mesh.vertexBufferHandle});
            }
            if (mesh.indexBufferHandle != UINT16_MAX) {
                bgfx::destroy(bgfx::IndexBufferHandle{mesh.indexBufferHandle});
            }
        }
    }
    g_models.clear();
    g_nextModelId = 1;
    
    printf("[ModelLoader] Shutdown complete\n");
}

// Helper to extract accessor data
template<typename T>
static std::vector<T> extractAccessorData(const tinygltf::Model& model, int accessorIndex) {
    if (accessorIndex < 0) return {};
    
    const auto& accessor = model.accessors[accessorIndex];
    const auto& bufferView = model.bufferViews[accessor.bufferView];
    const auto& buffer = model.buffers[bufferView.buffer];
    
    const uint8_t* dataPtr = buffer.data.data() + bufferView.byteOffset + accessor.byteOffset;
    size_t count = accessor.count;
    
    std::vector<T> result(count);
    
    size_t stride = bufferView.byteStride ? bufferView.byteStride : sizeof(T);
    for (size_t i = 0; i < count; ++i) {
        result[i] = *reinterpret_cast<const T*>(dataPtr + i * stride);
    }
    
    return result;
}

uint32_t model_load(const char* filepath) {
    printf("[ModelLoader] Loading: %s\n", filepath);
    
    tinygltf::Model gltfModel;
    std::string err, warn;
    
    bool success = false;
    std::string path(filepath);
    
    if (path.find(".glb") != std::string::npos) {
        success = g_loader.LoadBinaryFromFile(&gltfModel, &err, &warn, filepath);
    } else {
        success = g_loader.LoadASCIIFromFile(&gltfModel, &err, &warn, filepath);
    }
    
    if (!warn.empty()) {
        printf("[ModelLoader] Warning: %s\n", warn.c_str());
    }
    
    if (!success) {
        printf("[ModelLoader] Error: %s\n", err.c_str());
        return 0;
    }
    
    Model model;
    model.id = g_nextModelId++;
    model.name = filepath;
    
    // Process meshes
    for (const auto& gltfMesh : gltfModel.meshes) {
        for (const auto& primitive : gltfMesh.primitives) {
            Mesh mesh;
            
            // Get position data
            auto posIt = primitive.attributes.find("POSITION");
            if (posIt == primitive.attributes.end()) continue;
            
            const auto& posAccessor = gltfModel.accessors[posIt->second];
            size_t vertexCount = posAccessor.count;
            mesh.vertices.resize(vertexCount);
            
            // Extract positions
            {
                const auto& bufferView = gltfModel.bufferViews[posAccessor.bufferView];
                const auto& buffer = gltfModel.buffers[bufferView.buffer];
                const float* data = reinterpret_cast<const float*>(
                    buffer.data.data() + bufferView.byteOffset + posAccessor.byteOffset);
                
                for (size_t i = 0; i < vertexCount; ++i) {
                    mesh.vertices[i].position[0] = data[i * 3 + 0];
                    mesh.vertices[i].position[1] = data[i * 3 + 1];
                    mesh.vertices[i].position[2] = data[i * 3 + 2];
                }
            }
            
            // Extract normals
            auto normIt = primitive.attributes.find("NORMAL");
            if (normIt != primitive.attributes.end()) {
                const auto& accessor = gltfModel.accessors[normIt->second];
                const auto& bufferView = gltfModel.bufferViews[accessor.bufferView];
                const auto& buffer = gltfModel.buffers[bufferView.buffer];
                const float* data = reinterpret_cast<const float*>(
                    buffer.data.data() + bufferView.byteOffset + accessor.byteOffset);
                
                for (size_t i = 0; i < vertexCount; ++i) {
                    mesh.vertices[i].normal[0] = data[i * 3 + 0];
                    mesh.vertices[i].normal[1] = data[i * 3 + 1];
                    mesh.vertices[i].normal[2] = data[i * 3 + 2];
                }
            }
            
            // Extract texcoords
            auto texIt = primitive.attributes.find("TEXCOORD_0");
            if (texIt != primitive.attributes.end()) {
                const auto& accessor = gltfModel.accessors[texIt->second];
                const auto& bufferView = gltfModel.bufferViews[accessor.bufferView];
                const auto& buffer = gltfModel.buffers[bufferView.buffer];
                const float* data = reinterpret_cast<const float*>(
                    buffer.data.data() + bufferView.byteOffset + accessor.byteOffset);
                
                for (size_t i = 0; i < vertexCount; ++i) {
                    mesh.vertices[i].texcoord[0] = data[i * 2 + 0];
                    mesh.vertices[i].texcoord[1] = data[i * 2 + 1];
                }
            }
            
            // Extract joint indices (JOINTS_0)
            auto jointsIt = primitive.attributes.find("JOINTS_0");
            if (jointsIt != primitive.attributes.end()) {
                const auto& accessor = gltfModel.accessors[jointsIt->second];
                const auto& bufferView = gltfModel.bufferViews[accessor.bufferView];
                const auto& buffer = gltfModel.buffers[bufferView.buffer];
                const uint8_t* data = buffer.data.data() + bufferView.byteOffset + accessor.byteOffset;
                
                for (size_t i = 0; i < vertexCount; ++i) {
                    mesh.vertices[i].joints[0] = data[i * 4 + 0];
                    mesh.vertices[i].joints[1] = data[i * 4 + 1];
                    mesh.vertices[i].joints[2] = data[i * 4 + 2];
                    mesh.vertices[i].joints[3] = data[i * 4 + 3];
                }
            } else {
                // Default: all vertices bound to root bone
                for (size_t i = 0; i < vertexCount; ++i) {
                    mesh.vertices[i].joints[0] = 0;
                    mesh.vertices[i].joints[1] = 0;
                    mesh.vertices[i].joints[2] = 0;
                    mesh.vertices[i].joints[3] = 0;
                }
            }
            
            // Extract weights (WEIGHTS_0)
            auto weightsIt = primitive.attributes.find("WEIGHTS_0");
            if (weightsIt != primitive.attributes.end()) {
                const auto& accessor = gltfModel.accessors[weightsIt->second];
                const auto& bufferView = gltfModel.bufferViews[accessor.bufferView];
                const auto& buffer = gltfModel.buffers[bufferView.buffer];
                const float* data = reinterpret_cast<const float*>(
                    buffer.data.data() + bufferView.byteOffset + accessor.byteOffset);
                
                for (size_t i = 0; i < vertexCount; ++i) {
                    mesh.vertices[i].weights[0] = data[i * 4 + 0];
                    mesh.vertices[i].weights[1] = data[i * 4 + 1];
                    mesh.vertices[i].weights[2] = data[i * 4 + 2];
                    mesh.vertices[i].weights[3] = data[i * 4 + 3];
                }
            } else {
                // Default: full weight on first bone
                for (size_t i = 0; i < vertexCount; ++i) {
                    mesh.vertices[i].weights[0] = 1.0f;
                    mesh.vertices[i].weights[1] = 0.0f;
                    mesh.vertices[i].weights[2] = 0.0f;
                    mesh.vertices[i].weights[3] = 0.0f;
                }
            }
            
            // Extract indices
            if (primitive.indices >= 0) {
                const auto& accessor = gltfModel.accessors[primitive.indices];
                const auto& bufferView = gltfModel.bufferViews[accessor.bufferView];
                const auto& buffer = gltfModel.buffers[bufferView.buffer];
                const uint8_t* data = buffer.data.data() + bufferView.byteOffset + accessor.byteOffset;
                
                mesh.indices.resize(accessor.count);
                
                if (accessor.componentType == TINYGLTF_COMPONENT_TYPE_UNSIGNED_SHORT) {
                    const uint16_t* indices = reinterpret_cast<const uint16_t*>(data);
                    for (size_t i = 0; i < accessor.count; ++i) {
                        mesh.indices[i] = indices[i];
                    }
                } else if (accessor.componentType == TINYGLTF_COMPONENT_TYPE_UNSIGNED_INT) {
                    const uint32_t* indices = reinterpret_cast<const uint32_t*>(data);
                    for (size_t i = 0; i < accessor.count; ++i) {
                        mesh.indices[i] = indices[i];
                    }
                }
            }
            
            // Create GPU buffers
            const bgfx::Memory* vbMem = bgfx::copy(
                mesh.vertices.data(), 
                uint32_t(mesh.vertices.size() * sizeof(SkinnedVertex))
            );
            bgfx::VertexBufferHandle vbh = bgfx::createVertexBuffer(vbMem, g_skinnedVertexLayout);
            mesh.vertexBufferHandle = vbh.idx;
            
            if (!mesh.indices.empty()) {
                const bgfx::Memory* ibMem = bgfx::copy(
                    mesh.indices.data(),
                    uint32_t(mesh.indices.size() * sizeof(uint32_t))
                );
                bgfx::IndexBufferHandle ibh = bgfx::createIndexBuffer(ibMem, BGFX_BUFFER_INDEX32);
                mesh.indexBufferHandle = ibh.idx;
            }
            
            model.meshes.push_back(std::move(mesh));
        }
    }
    
    // Process skeleton (skins)
    if (!gltfModel.skins.empty()) {
        const auto& skin = gltfModel.skins[0];
        
        for (int jointNode : skin.joints) {
            const auto& node = gltfModel.nodes[jointNode];
            Joint joint;
            joint.name = node.name;
            
            // Find parent
            for (size_t i = 0; i < skin.joints.size(); ++i) {
                const auto& parentNode = gltfModel.nodes[skin.joints[i]];
                for (int child : parentNode.children) {
                    if (child == jointNode) {
                        joint.parentIndex = int32_t(i);
                        break;
                    }
                }
            }
            
            model.skeleton.joints.push_back(joint);
            model.skeleton.jointNameToIndex[joint.name] = model.skeleton.joints.size() - 1;
        }
        
        // Extract inverse bind matrices
        if (skin.inverseBindMatrices >= 0) {
            const auto& accessor = gltfModel.accessors[skin.inverseBindMatrices];
            const auto& bufferView = gltfModel.bufferViews[accessor.bufferView];
            const auto& buffer = gltfModel.buffers[bufferView.buffer];
            const float* data = reinterpret_cast<const float*>(
                buffer.data.data() + bufferView.byteOffset + accessor.byteOffset);
            
            for (size_t i = 0; i < model.skeleton.joints.size(); ++i) {
                std::memcpy(model.skeleton.joints[i].inverseBindMatrix, 
                           data + i * 16, 16 * sizeof(float));
            }
        }
        
        // Initialize bone matrices
        model.boneMatrices.resize(model.skeleton.joints.size() * 16, 0.0f);
        // Set to identity initially
        for (size_t i = 0; i < model.skeleton.joints.size(); ++i) {
            size_t offset = i * 16;
            model.boneMatrices[offset + 0] = 1.0f;
            model.boneMatrices[offset + 5] = 1.0f;
            model.boneMatrices[offset + 10] = 1.0f;
            model.boneMatrices[offset + 15] = 1.0f;
        }
    }
    
    // Process animations
    for (const auto& gltfAnim : gltfModel.animations) {
        AnimationClip clip;
        clip.name = gltfAnim.name;
        clip.duration = 0.0f;
        
        for (const auto& channel : gltfAnim.channels) {
            const auto& sampler = gltfAnim.samplers[channel.sampler];
            
            AnimationChannel animChannel;
            
            // Find joint index
            int targetNode = channel.target_node;
            for (size_t i = 0; i < model.skeleton.joints.size(); ++i) {
                // Simple matching - in real impl, map node indices properly
                if (i == size_t(targetNode) || model.skeleton.joints[i].name == gltfModel.nodes[targetNode].name) {
                    animChannel.jointIndex = i;
                    break;
                }
            }
            
            // Determine property
            if (channel.target_path == "translation") {
                animChannel.property = AnimationChannel::Property::Translation;
            } else if (channel.target_path == "rotation") {
                animChannel.property = AnimationChannel::Property::Rotation;
            } else if (channel.target_path == "scale") {
                animChannel.property = AnimationChannel::Property::Scale;
            }
            
            // Extract keyframes
            const auto& inputAccessor = gltfModel.accessors[sampler.input];
            const auto& outputAccessor = gltfModel.accessors[sampler.output];
            
            const auto& inputBV = gltfModel.bufferViews[inputAccessor.bufferView];
            const auto& inputBuf = gltfModel.buffers[inputBV.buffer];
            const float* times = reinterpret_cast<const float*>(
                inputBuf.data.data() + inputBV.byteOffset + inputAccessor.byteOffset);
            
            const auto& outputBV = gltfModel.bufferViews[outputAccessor.bufferView];
            const auto& outputBuf = gltfModel.buffers[outputBV.buffer];
            const float* values = reinterpret_cast<const float*>(
                outputBuf.data.data() + outputBV.byteOffset + outputAccessor.byteOffset);
            
            size_t valueComponents = (animChannel.property == AnimationChannel::Property::Rotation) ? 4 : 3;
            
            for (size_t i = 0; i < inputAccessor.count; ++i) {
                Keyframe kf;
                kf.time = times[i];
                for (size_t j = 0; j < valueComponents; ++j) {
                    kf.value[j] = values[i * valueComponents + j];
                }
                animChannel.keyframes.push_back(kf);
                
                if (kf.time > clip.duration) {
                    clip.duration = kf.time;
                }
            }
            
            clip.channels.push_back(std::move(animChannel));
        }
        
        model.animations.push_back(std::move(clip));
        model.animationNameToIndex[clip.name] = model.animations.size() - 1;
    }
    
    printf("[ModelLoader] Loaded model '%s': %zu meshes, %zu joints, %zu animations\n",
           filepath, model.meshes.size(), model.skeleton.joints.size(), model.animations.size());
    
    g_models[model.id] = std::move(model);
    return model.id;
}

void model_unload(uint32_t modelId) {
    auto it = g_models.find(modelId);
    if (it == g_models.end()) return;
    
    for (auto& mesh : it->second.meshes) {
        if (mesh.vertexBufferHandle != UINT16_MAX) {
            bgfx::destroy(bgfx::VertexBufferHandle{mesh.vertexBufferHandle});
        }
        if (mesh.indexBufferHandle != UINT16_MAX) {
            bgfx::destroy(bgfx::IndexBufferHandle{mesh.indexBufferHandle});
        }
    }
    
    g_models.erase(it);
    printf("[ModelLoader] Unloaded model %u\n", modelId);
}

Model* model_get(uint32_t modelId) {
    auto it = g_models.find(modelId);
    return (it != g_models.end()) ? &it->second : nullptr;
}

void model_set_transform(uint32_t modelId, float x, float y, float z, float scale, float rotation) {
    Model* model = model_get(modelId);
    if (!model) return;
    
    model->positionX = x;
    model->positionY = y;
    model->positionZ = z;
    model->scale = scale;
    model->rotation = rotation;
}

void model_draw_all(float dt) {
    // TODO: Implement actual drawing with shaders
    // For now, this is a placeholder
    for (auto& pair : g_models) {
        Model& model = pair.second;
        
        // Update animation
        if (!model.animations.empty() && model.currentAnimation < model.animations.size()) {
            const auto& clip = model.animations[model.currentAnimation];
            model.animationTime += dt;
            
            if (model.animationLooping && model.animationTime > clip.duration) {
                model.animationTime = fmod(model.animationTime, clip.duration);
            }
        }
        
        // Draw each mesh
        // TODO: Set transform uniforms, bind buffers, submit draw calls
    }
}

size_t model_get_count() {
    return g_models.size();
}

} // namespace gods
