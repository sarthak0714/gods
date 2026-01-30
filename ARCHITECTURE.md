# Hades 2 Game Design & Architecture Reference

> A comprehensive guide to understanding the core coding logic and design patterns used in Hades 2, for reference when creating similar roguelike action games.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Technology Stack](#technology-stack)
3. [3D Models & Animation Pipeline](#3d-models--animation-pipeline)
4. [Core Design Patterns](#core-design-patterns)
5. [Data-Driven Architecture](#data-driven-architecture)
6. [Threading & Coroutine System](#threading--coroutine-system)
7. [Event System](#event-system)
8. [Combat System](#combat-system)
9. [Enemy AI System](#enemy-ai-system)
10. [Rendering & Visual Layers](#rendering--visual-layers)
11. [Audio System](#audio-system)
12. [State Management](#state-management)
13. [Code Organization](#code-organization)
14. [How to Replicate This Style](#how-to-replicate-this-style)

---

## Architecture Overview

Hades 2 employs a **hybrid Lua/C++ architecture** that separates game logic from engine-level concerns:

```
┌────────────────────────────────────────────────────┐
│                   LUA LAYER                        │
│  (Game Logic, Data, AI, Combat, Presentation)      │
├────────────────────────────────────────────────────┤
│                  C++ ENGINE                        │
│  (Rendering, Physics, Audio, Input, Networking)    │
└────────────────────────────────────────────────────┘
```

### Key Characteristics

| Feature | Description |
|---------|-------------|
| **Event-Driven** | Systems communicate via events (`OnWeaponFired`, `OnDamage`, `OnDeath`) |
| **Threaded** | Custom coroutine-based threading for async operations |
| **Data-Driven** | Game content defined in data tables, not hardcoded |
| **Layered** | Strict separation of Data → Logic → Presentation |
| **Stateful** | Global state persists across map loads |

---

## Technology Stack

### C++ Engine (Core Systems)
- **Rendering**: DirectX 12 shaders, Granny 3D models (`.gpk`, `.gr2`)
- **Audio**: FMOD (`.bank`, `.fsb` files)
- **Physics**: Custom physics with forces, teleport, movement
- **Video**: Bink video (`.bik`)
- **Input**: SDL2 library

### Lua Scripting (Game Logic)
- **Version**: Lua 5.2 (`lua52.dll`)
- **476 script files** organize all game systems
- **Custom coroutine system** for async game logic
- **Event-driven architecture** for decoupled communication

---

## 3D Models & Animation Pipeline

### File Formats Used in Hades 2

> **Important Clarification**: The `.gpk` and `.gr2` files in Hades 2 are **NOT** Unreal Engine packages. They are **Granny 3D** format files from **RAD Game Tools** - a professional middleware SDK for 3D animation used in many AAA games.

| Format | Type | Description |
|--------|------|-------------|
| `.gr2` | Granny 3D File | Individual 3D models with skeletal data and animations |
| `.gpk` | Granny Package | Packaged collections of models, textures, and animations |
| `.sjson` | Structured JSON | Animation definitions that reference Granny files |
| `.pkg` | Asset Package | Compiled asset bundles loaded on-demand |

### Hades 2 Asset Loading Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      ASSET PIPELINE                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   GR2/                     Game/Animations/                 │
│   ├── Characters/          ├── Enemy.sjson      ──────┐     │
│   │   └── Swarmer.gpk      ├── Hero.sjson            │     │
│   └── Effects/             └── Effects.sjson          │     │
│       └── Explosions.gpk                              │     │
│                                                       │     │
│              ↓ loaded by                              │     │
│                                                       ▼     │
│   ┌─────────────────────────────────────────────────────┐   │
│   │           granny2_x64.dll (C++ Engine)             │   │
│   │   - Reads .gr2/.gpk binary files                   │   │
│   │   - Manages skeletal hierarchies                   │   │
│   │   - Handles animation blending/playback            │   │
│   │   - Exposes API to Lua via engine bindings         │   │
│   └─────────────────────────────────────────────────────┘   │
│                           │                                  │
│                           ▼                                  │
│   ┌─────────────────────────────────────────────────────┐   │
│   │                  Lua Layer                          │   │
│   │   SetAnimation(), CreateAnimation(), etc.          │   │
│   └─────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### C++ Engine: Granny SDK Integration

Hades 2 uses the Granny animation system via `granny2_x64.dll`:

```cpp
// C++ Engine - Granny SDK Integration
#include "granny.h"

class GrannyModelManager {
private:
    std::map<std::string, granny_file*> loadedFiles;
    
public:
    // Load a model/animation file
    granny_file* LoadGrannyFile(const char* filepath) {
        granny_file* file = GrannyReadEntireFile(filepath);
        if (file) {
            loadedFiles[filepath] = file;
        }
        return file;
    }
    
    // Extract model data
    granny_model* GetModel(granny_file* file, int index = 0) {
        granny_file_info* info = GrannyGetFileInfo(file);
        if (info && index < info->ModelCount) {
            return info->Models[index];
        }
        return nullptr;
    }
    
    // Extract skeleton for rigged characters
    granny_skeleton* GetSkeleton(granny_model* model) {
        return model->Skeleton;
    }
    
    // Extract animation data
    granny_animation* GetAnimation(granny_file* file, int index = 0) {
        granny_file_info* info = GrannyGetFileInfo(file);
        if (info && index < info->AnimationCount) {
            return info->Animations[index];
        }
        return nullptr;
    }
    
    // Play animation with blending
    void PlayAnimation(granny_model_instance* instance, 
                       granny_animation* anim,
                       float blendTime = 0.2f) {
        granny_control* control = GrannyPlayAnimation(
            0.0f,                    // Start time
            anim,                    // Animation to play
            GrannyGetModelFromModelInstance(instance),
            GrannyLoopOnce,          // Or GrannyLoopForever
            blendTime                // Blend duration
        );
    }
};
```

### Animation Definition System (.sjson)

Animations are defined in `.sjson` files (Lua-like structured JSON) located in `Game/Animations/`:

```lua
-- Game/Animations/EnemySwarmer.sjson
{
    Name = "SwarmerIdle"
    FilePath = "Enemies/Swarmer/Idle"
    GrannyModel = "Swarmer_Mesh"
    Loop = true
    Duration = 2.0
    NumFrames = 60
}

{
    Name = "SwarmerAttack"
    FilePath = "Enemies/Swarmer/Attack"
    GrannyModel = "Swarmer_Mesh"
    Loop = false
    Duration = 0.6
    NumFrames = 18
    -- Animation events (damage frame, sound cue, etc.)
    Events = {
        { Frame = 10, Event = "DamageWindow" },
        { Frame = 5, Sound = "/SFX/SwarmerSwing" },
    }
}

{
    Name = "SwarmerDeath"
    FilePath = "Enemies/Swarmer/Death"
    GrannyModel = "Swarmer_Mesh"
    Loop = false
    Duration = 1.0
}
```

### Lua Animation API (How Scripts Control Animations)

The C++ engine exposes animation functions to Lua:

```lua
-- SetAnimation: Play animation on an existing object
SetAnimation({
    Name = "SwarmerIdle",           -- Animation name from .sjson
    DestinationId = enemy.ObjectId, -- Target object ID
    SpeedMultiplier = 1.0,          -- Playback speed (optional)
})

-- CreateAnimation: Create a standalone effect/particle
local animId = CreateAnimation({
    Name = "ExplosionFx",           -- Effect animation name
    DestinationId = targetId,       -- Position target
    Group = "FX_Standing_Add",      -- Render group (layer)
    OffsetX = 0,                    -- X offset from target
    OffsetY = 0,                    -- Y offset from target  
    OffsetZ = 100,                  -- Z offset (height)
    Scale = 2.0,                    -- Size multiplier
    FlipHorizontal = false,         -- Mirror horizontally
    FlipVertical = false,           -- Mirror vertically
    Color = { R = 255, G = 200, B = 100, A = 255 }, -- Tint
})

-- StopAnimation: Stop a playing animation
StopAnimation({
    Name = "SwarmerIdle",
    DestinationId = enemy.ObjectId,
})

-- SetAnimationSpeed: Adjust playback speed
SetAnimationSpeed({
    DestinationId = enemy.ObjectId,
    Speed = 0.5,  -- Half speed
})
```

### How Hades 2 Links Data → Animation

In enemy/unit data files, animations are referenced by name:

```lua
-- EnemyData_Swarmer.lua
EnemyData.Swarmer = {
    InheritFrom = { "BaseVulnerableEnemy" },
    
    -- Animation references (names match .sjson definitions)
    IdleAnimation = "SwarmerIdle",
    AttackAnimation = "SwarmerAttack",
    DeathAnimation = "SwarmerDeath",
    HitAnimation = "SwarmerHit",
    
    -- Visual model reference
    Graphic = "Swarmer",  -- References the Granny model
    
    -- Animation timing for AI
    DefaultAIData = {
        PreAttackAnimation = "SwarmerAttackCharge",
        PreAttackDuration = 0.4,
        FireAnimation = "SwarmerAttack",
        PostAttackAnimation = "SwarmerIdle",
        PostAttackDuration = 0.2,
    },
}
```

### Presentation Layer: Animation + Effects

```lua
-- EnemyPresentation.lua
function EnemyDeathPresentation(enemy, args)
    -- Play death animation
    SetAnimation({
        Name = enemy.DeathAnimation,
        DestinationId = enemy.ObjectId,
    })
    
    -- Create death VFX
    CreateAnimation({
        Name = "EnemyDeathFx",
        DestinationId = enemy.ObjectId,
        Group = "FX_Standing_Add",
    })
    
    -- Play death sound
    PlaySound({
        Name = enemy.DeathSound or "/SFX/Enemy Sounds/EnemyDeath",
        Id = enemy.ObjectId,
    })
    
    -- Wait for animation to finish
    wait(enemy.DeathDuration or 1.0, "EnemyDeath")
    
    -- Destroy the object
    Destroy({ Id = enemy.ObjectId })
end
```

### Package Loading System

Assets are bundled into packages loaded on-demand:

```lua
-- Room setup loads required packages
function SetupRoom(room)
    -- Load packages for this room's content
    LoadPackages({
        Names = room.RequiredPackages or {},
    })
    
    wait(0.1)  -- Wait for async load
    
    -- Now spawn enemies (their assets are loaded)
    for _, enemyName in ipairs(room.EnemyTypes) do
        SpawnEnemy(enemyName)
    end
end

-- Unload when leaving
function CleanupRoom(room)
    UnloadPackages({
        Names = room.RequiredPackages or {},
    })
end
```

### C++ Engine Functions Exposed to Lua

The engine exposes these model/animation functions:

| Function | Description |
|----------|-------------|
| `SpawnObstacle()` | Create 3D object from Granny model |
| `SetAnimation()` | Play skeletal animation on object |
| `CreateAnimation()` | Create standalone animated effect |
| `StopAnimation()` | Stop playing animation |
| `SetAnimationSpeed()` | Adjust playback speed |
| `SetScale()` | Change object scale |
| `SetColor()` | Apply color tint |
| `SetAlpha()` | Set transparency |
| `Attach()` | Parent object to another |
| `Destroy()` | Remove object |
| `LoadPackages()` | Load asset packages |
| `UnloadPackages()` | Unload asset packages |

---


## Core Design Patterns

### 1. Three-Layer Separation

Every game system follows strict separation:

```
┌─────────────────────────────────────┐
│   Presentation Layer                │  (*Presentation.lua)
│   - Visual effects                  │  - Audio feedback
│   - UI updates                      │  - Animation triggers
└─────────────────────────────────────┘
           ↓ calls
┌─────────────────────────────────────┐
│   Logic Layer                       │  (*Logic.lua)
│   - Game rules                      │  - State management
│   - Calculations                    │  - Event handlers
└─────────────────────────────────────┘
           ↓ reads
┌─────────────────────────────────────┐
│   Data Layer                        │  (*Data.lua)
│   - Static definitions              │  - Configuration tables
│   - Properties                      │  - Inheritance chains
└─────────────────────────────────────┘
```

### 2. File Naming Convention

```lua
-- Pattern: [Feature][Type].lua
EnemyData.lua           -- Data definitions for enemies
EnemyLogic.lua          -- Game logic for enemy behavior  
EnemyPresentation.lua   -- Visual/audio effects for enemies
CombatLogic.lua         -- Combat system core logic
WeaponData_Axe.lua      -- Specific weapon data
```

### 3. Deep Table Inheritance

```lua
UnitSetData.Enemies = {
    -- Base class with shared properties
    BaseVulnerableEnemy = {
        Health = 100,
        Material = "Organic",
        DamageType = "Enemy",
        AIAggroRange = 600,
        DefaultAIData = {
            DeepInheritance = true,
            PreAttackAngleTowardTarget = true,
        },
    },
    
    -- Derived class inherits and overrides
    Swarmer = {
        InheritFrom = { "BaseVulnerableEnemy" },
        Health = 50,  -- Override parent
        AIAggroRange = 400,  -- Override parent
        -- Inherits everything else from BaseVulnerableEnemy
    },
    
    -- Elite variants with additional behaviors
    Elite = {
        IsElite = true,
        EliteAttributeOptions = EnemySets.GenericEliteAttributes,
        EliteAttributeData = {
            Blink = { ... },
            Frenzy = { ... },
            HeavyArmor = { ... },
        },
    },
}
```

---

## Data-Driven Architecture

### Enemy Data Example

```lua
-- EnemyData.lua
EnemyData.Swarmer = {
    InheritFrom = { "BaseVulnerableEnemy" },
    
    -- Core stats
    Health = 50,
    HealthBuffer = 100,  -- Armor
    Material = "Organic",
    
    -- AI configuration
    AIAggroRange = 400,
    AggroReactionTimeMin = 0.05,
    AggroReactionTimeMax = 0.2,
    
    -- Combat settings
    WeaponOptions = { "SwarmerMelee" },
    
    -- Visual settings
    DeathAnimation = "EnemyDeathFx",
    DeathSound = "/SFX/Enemy Sounds/EnemyDeathSFX",
    
    -- Loot configuration
    MoneyDropOnDeath = {
        Chance = 0.7,
        MinValue = 1,
        MaxValue = 1,
    },
}
```

### Weapon Data Example

```lua
-- WeaponData.lua
WeaponData.SwarmerMelee = {
    InheritFrom = { "BaseEnemyWeapon" },
    
    Damage = 15,
    CriticalHitChance = 0.0,
    Range = 150,
    
    AIData = {
        AttackDistance = 200,
        PreAttackDuration = 0.4,
        PostAttackDuration = 0.3,
    },
    
    Effects = {
        { Name = "SwarmerHit", DestinationId = "victim" },
    },
}
```

---

## Threading & Coroutine System

Hades 2 uses a **custom lightweight threading system** built on Lua coroutines for non-blocking async operations.

### Core Thread Functions

```lua
-- Main.lua - Core Threading API

-- Create a new thread
function thread(func, arg1, arg2, arg3, arg4, arg5)
    local co = getCoroutine()
    setupDebugHooks(co)
    resume(co, _threads, func, arg1, arg2, arg3, arg4, arg5)
end

-- Wait for duration (seconds)
function wait(duration, tag, persist)
    if duration == nil or duration <= 0 then return end
    coroutine.yield({ 
        wait = duration, 
        tag = tag or "Untagged", 
        Persist = persist 
    })
end

-- Wait until event fires
function waitUntil(event, tag, persist)
    if _events[event] ~= nil then
        _events[event] = nil
        return
    end
    coroutine.yield({ 
        wait = -1, 
        event = event, 
        tag = tag, 
        Persist = persist 
    })
end
```

### Thread Usage Examples

```lua
-- Delayed action
thread(function()
    wait(2.0, "EnemySpawnDelay")
    SpawnEnemy("Swarmer")
end)

-- Event-driven logic
thread(function()
    waitUntil("RoomCleared")
    OpenExitDoors()
    PlayVictoryMusic()
end)

-- Tagged threads for management
thread(function()
    wait(5.0, "BossPhaseTimer")
    TriggerBossPhase2()
end)

-- Kill all threads with tag
killTaggedThreads("BossPhaseTimer")
```

### Main Game Loop

```lua
-- Main update function called by C++ engine
function update(time, unmodifiedTime)
    _worldTime = time
    _worldTimeUnmodified = unmodifiedTime
    
    -- Process deferred presentation
    if FrameState.DeferredPresentation ~= nil then
        for functionName, args in pairs(FrameState.DeferredPresentation) do
            CallFunctionName(functionName, args)
        end
    end
    
    -- Resume ready threads
    for k, threadInfo in ipairs(_threads) do
        local checkTime = threadInfo.unmodifiedTime 
            and _worldTimeUnmodified or _worldTime
        
        if threadInfo.resumeTime < checkTime then
            resume(threadInfo.thread, _workingThreads)
        else
            table.insert(_workingThreads, threadInfo)
        end
    end
    
    -- Swap thread tables
    _threads, _workingThreads = _workingThreads, _threads
    TableClear(_workingThreads)
    
    -- Process draw calls
    draw(time, unmodifiedTime)
end
```

---

## Event System

### Event Registration Pattern

```lua
-- CombatLogic.lua - Event handlers registered at file load
OnWeaponFired{
    function(triggerArgs)
        local weapon = triggerArgs.name
        local owner = triggerArgs.OwnerTable
        ProcessWeaponFire(owner, weapon)
    end
}

OnDamage{
    function(triggerArgs)
        local victim = triggerArgs.TriggeredByTable
        local attacker = triggerArgs.AttackerTable
        local damage = triggerArgs.DamageAmount
        ProcessCombatDamage(victim, attacker, damage, triggerArgs)
    end
}

OnDeath{
    function(triggerArgs)
        local unit = triggerArgs.TriggeredByTable
        HandleUnitDeath(unit, triggerArgs)
    end
}
```

### Event Notification

```lua
-- Trigger event and resume waiting threads
function notify(event, wasTimeout)
    _eventTimeoutRecord[event] = wasTimeout
    local eventListeners = _eventListeners[event]
    if eventListeners ~= nil then
        _eventListeners[event] = nil
        for index, listener in pairs(eventListeners) do
            resume(listener.Thread, _workingThreads)
        end
    else
        -- Store for future waiters
        _events[event] = true
    end
end

-- Usage example
notify("EnemySpawned", false)
notify("RoomCleared", false)
```

### Common Events

| Event | Description | Trigger Source |
|-------|-------------|----------------|
| `OnAnyLoad` | Map/room loaded | C++ Engine |
| `OnWeaponFired` | Weapon attack started | C++ Engine |
| `OnDamage` | Damage dealt to target | C++ Engine |
| `OnDeath` | Unit died | C++ Engine |
| `OnProjectileHit` | Projectile hit target | C++ Engine |
| `OnDodge` | Player dodge executed | C++ Engine |
| `OnProjectileReflect` | Projectile reflected | C++ Engine |

---

## Combat System

### Damage Calculation Flow

```lua
-- CombatLogic.lua
function CalculateBaseDamage(attacker, victim, triggerArgs)
    local damage = triggerArgs.DamageAmount
    
    -- Apply outgoing damage modifiers
    if attacker ~= nil and attacker.OutgoingDamageModifiers ~= nil then
        for i, modifierData in ipairs(attacker.OutgoingDamageModifiers) do
            local validWeapon = modifierData.ValidWeaponsLookup == nil 
                or modifierData.ValidWeaponsLookup[triggerArgs.SourceWeapon]
            
            if validWeapon then
                if modifierData.Multiplier then
                    damage = damage * modifierData.Multiplier
                end
                if modifierData.Addition then
                    damage = damage + modifierData.Addition
                end
            end
        end
    end
    
    return damage
end
```

### Damage Modifiers System

```lua
-- Add modifier to unit
function AddOutgoingDamageModifier(unit, data)
    if unit == nil then return end
    unit.OutgoingDamageModifiers = unit.OutgoingDamageModifiers or {}
    
    -- Pre-compute lookup for valid weapons
    if data.ValidWeapons and not data.ValidWeaponsLookup then
        data.ValidWeaponsLookup = ToLookup(data.ValidWeapons)
    end
    
    table.insert(unit.OutgoingDamageModifiers, data)
end

-- Example usage
AddOutgoingDamageModifier(hero, {
    Name = "PowerBuff",
    ValidWeapons = { "Sword", "Bow" },
    Multiplier = 1.5,
})
```

---

## Enemy AI System

### AI Architecture

```lua
-- EnemyAILogic.lua
function AttackerAI(enemy)
    while enemy.Health > 0 do
        -- Get current target
        local target = GetClosestTarget(enemy)
        
        if target then
            -- Move into attack range
            if not IsInRange(enemy, target, enemy.AIData.AttackDistance) then
                MoveTowardsTarget(enemy, target)
            else
                -- Execute attack
                ExecuteAttack(enemy, target)
            end
        else
            -- Wander when no target
            AIWander(enemy)
        end
        
        wait(enemy.AIData.ThinkInterval or 0.1, "AI_"..enemy.ObjectId)
    end
end
```

### AI Data Configuration

```lua
DefaultAIData = {
    DeepInheritance = true,
    
    -- Movement
    MoveWithinRange = true,
    StopMoveWithinRange = true,
    
    -- Attack behavior
    PreAttackStop = false,
    PreAttackAngleTowardTarget = true,
    PostAttackStop = false,
    
    -- Distance settings
    AttackDistance = 150,
    AttackDistanceBuffer = 50,
    
    -- Timing
    PreAttackDuration = 0.4,
    PostAttackDuration = 0.3,
}
```

### Elite Enemy System

```lua
-- Elite attributes add special behaviors
EliteAttributeData = {
    Blink = {  -- Teleports periodically
        AIDataOverrides = {
            PreMoveTeleport = true,
            TeleportationIntervalMin = 5.5,
            TeleportationIntervalMax = 9.0,
        },
    },
    
    Frenzy = {  -- Increased speed
        DataOverrides = {
            EliteAdditionalSpeedMultiplier = 0.5,
        },
    },
    
    HeavyArmor = {  -- More health
        DataOverrides = {
            HealthMultiplier = 1.5,
        },
    },
}
```

---

## Rendering & Visual Layers

### Render Group Hierarchy (back to front)

```
Terrain_Gameplay (collision)
  ↓
FX_Terrain_Dark
  ↓
FX_Terrain_Liquid
  ↓
FX_Terrain
  ↓
Shadows
  ↓
Standing_Back
  ↓
Standing (characters)
  ↓
FX_Standing_Add (effects)
  ↓
FX_Displacement
  ↓
FX_Standing_Top
  ↓
Vignette (fullscreen)
  ↓
Combat_UI (HUD)
```

### Spawning Objects

```lua
-- Spawn obstacle (enemy, prop, etc.)
local obstacleId = SpawnObstacle({
    Name = "EnemySwarmer",      -- Data table name
    Group = "Standing",          -- Render group
    DestinationId = spawnPointId,
    OffsetX = 100,
    OffsetY = 200,
    Attach = true,
})

-- Setup with data
local obstacle = DeepCopyTable(ObstacleData["EnemySwarmer"])
obstacle.ObjectId = obstacleId
SetupObstacle(obstacle)
```

### Animation System

```lua
-- Set character animation
SetAnimation({
    Name = "EnemyIdle",
    DestinationId = enemy.ObjectId,
    SpeedMultiplier = 1.5,
})

-- Create standalone effect animation
CreateAnimation({
    Name = "ExplosionFx",
    DestinationId = targetId,
    Group = "FX_Standing_Add",
    OffsetZ = 100,
    Scale = 2.0,
})
```

---

## Audio System

### Playing Sounds

```lua
-- AudioLogic.lua
local soundId = PlaySound({
    Name = "/SFX/Enemy Sounds/EnemyDeath",
    Id = enemy.ObjectId,      -- 3D positioning
    ManagerCap = 32,          -- Max concurrent
})

-- Voice lines
local speechId = PlaySpeech({
    Name = "VoiceLineCue",
    Id = npc.ObjectId,
    UseSubtitles = true,
    SubtitleColor = Color.White,
})

-- Music control
MusicPlayer("CombatMusic", musicInfo, sourceId)
SetMusicSection(2)
PauseMusic()
ResumeMusic()
```

### Audio State

```lua
AudioState = {
    MusicId = nil,
    MusicName = nil,
    ActiveSpeechIds = {},
    AmbienceId = nil,
}
```

---

## State Management

### Global State Tables

```lua
-- Persistent across sessions
GameState = {
    MusicRecord = {},
    ScreensViewed = {},
    UnlockedItems = {},
}

-- Current playthrough
CurrentRun = {
    Hero = { ObjectId = 123, Health = 100 },
    CurrentRoom = { Name = "Combat01" },
    BiomeDepth = 1,
}

-- Current session only
SessionState = {
    MapLoads = 0,
}

-- Current map only
MapState = {
    ActiveObstacles = {},
    RoomRequiredObjects = {},
}
```

### State Initialization Pattern

```lua
function GameStateInit()
    GameState = GameState or {}
    GameState.MusicRecord = GameState.MusicRecord or {}
    -- Initialize other defaults
end

function MapStateInit()
    MapState = MapState or {}
    MapState.ActiveObstacles = {}
    -- Reset map-specific state
end
```

---

## Code Organization

### Directory Structure

```
Content/
├── Scripts/                    # 476 Lua scripts
│   ├── Main.lua               # Core loop, threading
│   ├── *Data.lua              # Data definitions
│   ├── *Logic.lua             # Game logic
│   └── *Presentation.lua      # Visual/audio
│
├── Game/
│   ├── Animations/            # Animation definitions (.sjson)
│   └── Text/                  # Localization
│
├── Maps/                       # Map definitions (.map_text)
├── Packages/                   # Asset packages (.pkg)
├── GR2/                        # 3D models (.gpk)
├── Audio/                      # FMOD audio (.bank, .fsb)
└── Shaders/                    # DirectX 12 shaders
```

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Local variables | camelCase | `currentRun`, `enemyData` |
| Global tables | PascalCase | `CurrentRun`, `EnemyData` |
| Constants | UPPER_SNAKE | `MAX_HEALTH`, `DEFAULT_SPEED` |
| Public functions | PascalCase | `SetupEnemy()`, `ProcessDamage()` |
| Private functions | camelCase | `calculateDamage()`, `updateHealth()` |
| Events | `On` prefix | `OnWeaponFired`, `OnDamage` |

---

## How to Replicate This Style

### 1. Set Up Lua/C++ Hybrid Architecture

```cpp
// C++ Engine Side
class LuaEngine {
    lua_State* L;
    
    void Initialize() {
        L = luaL_newstate();
        luaL_openlibs(L);
        RegisterEngineFunctions();
        LoadScripts();
    }
    
    void Update(float time) {
        lua_getglobal(L, "update");
        lua_pushnumber(L, time);
        lua_call(L, 1, 0);
    }
    
    void RegisterEngineFunctions() {
        // Expose C++ functions to Lua
        lua_register(L, "SpawnObstacle", &LuaSpawnObstacle);
        lua_register(L, "PlaySound", &LuaPlaySound);
        lua_register(L, "CreateAnimation", &LuaCreateAnimation);
    }
    
    void FireEvent(const char* event, LuaTable args) {
        lua_getglobal(L, "notify");
        lua_pushstring(L, event);
        PushTable(L, args);
        lua_call(L, 2, 0);
    }
};
```

### 2. Implement Threading System

```lua
-- Minimal threading implementation
_threads = {}

function thread(func, ...)
    local co = coroutine.create(func)
    local status, info = coroutine.resume(co, ...)
    if status and info then
        table.insert(_threads, { thread = co, resumeTime = _time + info.wait })
    end
end

function wait(duration)
    coroutine.yield({ wait = duration })
end

function update(time)
    _time = time
    local activeThreads = {}
    for _, threadInfo in ipairs(_threads) do
        if threadInfo.resumeTime <= time then
            local status, info = coroutine.resume(threadInfo.thread)
            if status and info then
                threadInfo.resumeTime = time + info.wait
                table.insert(activeThreads, threadInfo)
            end
        else
            table.insert(activeThreads, threadInfo)
        end
    end
    _threads = activeThreads
end
```

### 3. Create Data-Driven Content System

```lua
-- Define base data
UnitData = {}
UnitData.BaseUnit = {
    Health = 100,
    Speed = 200,
}

-- Define derived data with inheritance
UnitData.FastUnit = {
    InheritFrom = { "BaseUnit" },
    Speed = 400,  -- Override
}

-- Resolve inheritance at load time
function ResolveInheritance(data)
    if data.InheritFrom then
        for _, parentName in ipairs(data.InheritFrom) do
            local parent = UnitData[parentName]
            for key, value in pairs(parent) do
                if data[key] == nil then
                    data[key] = DeepCopy(value)
                end
            end
        end
    end
    return data
end
```

### 4. Implement Event System

```lua
_eventHandlers = {}

function On(eventName, handler)
    _eventHandlers[eventName] = _eventHandlers[eventName] or {}
    table.insert(_eventHandlers[eventName], handler)
end

function notify(eventName, args)
    local handlers = _eventHandlers[eventName]
    if handlers then
        for _, handler in ipairs(handlers) do
            handler(args)
        end
    end
end

-- Usage
On("EnemyDeath", function(args)
    DropLoot(args.enemy)
    UpdateKillCount()
end)
```

### 5. Separate Concerns

```lua
-- EnemyData.lua - ONLY data definitions
EnemyData.Goblin = {
    Health = 30,
    Damage = 10,
    DeathFunctionName = "GoblinDeathPresentation",
}

-- EnemyLogic.lua - ONLY game rules
function ProcessEnemyDeath(enemy)
    DropLoot(enemy)
    UpdateScore(enemy.ScoreValue)
    CallFunctionName(enemy.DeathFunctionName, enemy)
end

-- EnemyPresentation.lua - ONLY visuals/audio
function GoblinDeathPresentation(enemy)
    CreateAnimation({ Name = "GoblinDeathFx", DestinationId = enemy.ObjectId })
    PlaySound({ Name = "/SFX/GoblinDeath" })
    wait(0.5)
    Destroy({ Id = enemy.ObjectId })
end
```

---

## Quick Reference

### Essential Engine Functions

```lua
-- Rendering
SpawnObstacle({ Name, Group, DestinationId })
CreateAnimation({ Name, DestinationId, Group })
SetAnimation({ Name, DestinationId })
SetColor({ Id, Color })
SetScale({ Id, Fraction })
Destroy({ Ids })

-- Audio
PlaySound({ Name, Id })
PlaySpeech({ Name, Id })
StopSound({ Id })

-- Physics
ApplyForce({ Id, Force, Angle })
Teleport({ Id, DestinationId })
Move({ Id, DestinationId, Speed })

-- Camera
LockCamera({ TargetId })
PanCamera({ Ids })
AdjustZoom({ Fraction, LerpTime })

-- Map
LoadMap({ Name })
LoadPackages({ Names })
```

### Essential Lua Functions

```lua
-- Threading
thread(func, ...)
wait(duration, tag)
waitUntil(event, tag)
killTaggedThreads(tag)

-- Events
notify(event, wasTimeout)
notifyExistingWaiters(event)

-- Tables
DeepCopyTable(table)
ToLookup(array)  -- { "a", "b" } → { a = true, b = true }
CollapseTable(sparseTable)
TableClear(table)

-- Functions
CallFunctionName(name, arg1, arg2, ...)
```

---

## Summary

To create a similar roguelike action game:

1. **Use Lua + C++ hybrid** - Lua for game logic, C++ for engine
2. **Implement custom threading** - Coroutines for async operations
3. **Build event system** - Decouple systems via events
4. **Design data-driven** - Define content in tables, not code
5. **Separate concerns** - Data → Logic → Presentation
6. **Use deep inheritance** - Share properties via `InheritFrom`
7. **Manage state globally** - `GameState`, `CurrentRun`, `MapState`
8. **Layer rendering** - Use render groups for visual ordering

---

*This documentation is based on analysis of the Hades 2 codebase. Use as a reference for understanding game architecture patterns.*
