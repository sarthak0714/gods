--[[
    Player Data Definitions
    Static configuration for player properties.
    Based on Hades 2 architecture patterns.
]]

local PlayerData = {}

-- 16 directions with 22.5 degree steps
PlayerData.SPRITE_ANGLES = {
    0, 22.5, 45, 67.5, 90, 112.5, 135, 157.5,
    180, 202.5, 225, 247.5, 270, 292.5, 315, 337.5
}

-- Angle to sprite file suffix mapping
PlayerData.ANGLE_TO_SUFFIX = {
    [0] = "000",
    [22.5] = "022",
    [45] = "045",
    [67.5] = "067",
    [90] = "090",
    [112.5] = "112",
    [135] = "135",
    [157.5] = "157",
    [180] = "180",
    [202.5] = "202",
    [225] = "225",
    [247.5] = "247",
    [270] = "270",
    [292.5] = "292",
    [315] = "315",
    [337.5] = "337"
}

-- Base player definition
PlayerData.Base = {
    -- Core stats
    Health = 100,
    MaxHealth = 100,
    Speed = 3,
    Size = 15,
    
    -- Dash settings
    DashDuration = 0.15,
    DashSpeed = 10,
    DashInvulnerable = true,
    
    -- Visual settings
    SpriteScale = 1.2,
    SpriteResolution = "x256p_Spritesheets",
    
    -- Animation grid layouts (columns x rows)
    AnimationGrids = {
        Idle = { cols = 4, rows = 4 },           -- 4x4 = 16 frames
        Walk = { cols = 5, rows = 4 },           -- 5x4 = 20 frames
        Run = { cols = 4, rows = 4 },            -- 4x4 = 16 frames (dash)
        Attack_Swipe = { cols = 5, rows = 4 },   -- 5x4 = 20 frames
        Attack_Jump = { cols = 6, rows = 4 },    -- 6x4 = 24 frames
    },
    
    -- Animation timing (frames, speed, loop)
    Animations = {
        idle = {
            frames = 16,
            speed = 0.2,   -- 0.2s per frame = 3.2s cycle
            loop = true,
            spriteSet = "Idle",
        },
        walk = {
            frames = 20,
            speed = 0.08,  -- 1.6s cycle
            loop = true,
            spriteSet = "Walk",
        },
        run = {
            frames = 16,
            speed = 0.06,  -- 0.96s cycle
            loop = true,
            spriteSet = "Run",
        },
        attack_swipe = {
            frames = 20,
            speed = 0.1,   -- 2s total
            loop = false,
            spriteSet = "Attack_Swipe",
            returnTo = "idle",
        },
        attack_jump = {
            frames = 24,
            speed = 0.1,   -- 2.4s total
            loop = false,
            spriteSet = "Attack_Jump",
            returnTo = "idle",
        },
    },
    
    -- Sprite path pattern
    SpritePathPattern = "assets/sprites/player/%s/%s/%s_Body_%s.png",
    
    -- Default weapon
    DefaultWeapon = "Mace",
    
    -- Audio cues
    DashSound = "dash",
    DeathSound = "death",
}

return PlayerData
