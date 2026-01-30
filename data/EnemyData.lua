--[[
    Enemy Data Definitions
    Static configuration for enemy types.
    Based on Hades 2 architecture patterns.
]]

local EnemyData = {}

-- Shared sprite configuration
EnemyData.SPRITE_ANGLES = {
    0, 22.5, 45, 67.5, 90, 112.5, 135, 157.5,
    180, 202.5, 225, 247.5, 270, 292.5, 315, 337.5
}

EnemyData.ANGLE_TO_SUFFIX = {
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

-- Base enemy (all enemies inherit from this)
EnemyData.BaseEnemy = {
    -- Core stats
    Health = 3,
    Size = 20,
    HitRange = 1.5,
    
    -- AI configuration
    AIAggroRange = 400,
    AggroReactionTimeMin = 0.05,
    AggroReactionTimeMax = 0.2,
    
    -- Visual settings
    SpriteScale = 1.5,
    SpriteResolution = "x256p_Spritesheets",
    
    -- Animation grid layouts
    AnimationGrids = {
        Idle = { cols = 5, rows = 4 },   -- 5x4 = 20 frames
        Hit = { cols = 4, rows = 4 },    -- 4x4 = 16 frames
        Death = { cols = 6, rows = 5 },  -- 6x5 = 30 frames
    },
    
    -- Animation timing
    Animations = {
        idle = {
            frames = 20,
            speed = 0.15,
            loop = true,
            spriteSet = "Idle",
        },
        hit = {
            frames = 16,
            speed = 0.05,  -- 0.8s total
            loop = false,
            spriteSet = "Hit",
            returnTo = "idle",
        },
        death = {
            frames = 30,
            speed = 0.08,  -- 2.4s total
            loop = false,
            spriteSet = "Death",
        },
    },
    
    -- Sprite path pattern
    SpritePathPattern = "assets/sprites/enemy/%s/%s/%s_Body_%s.png",
    
    -- Audio
    HitSound = "enemy_damage",
    DeathSound = "death",
    
    -- Loot
    MoneyDropOnDeath = {
        Chance = 0.7,
        MinValue = 1,
        MaxValue = 1,
    },
    
    -- Flags
    Required = true,  -- Must be killed to clear room
}

-- Swarmer enemy type
EnemyData.Swarmer = {
    InheritFrom = { "BaseEnemy" },
    
    -- Override stats
    Health = 5,
    HitRange = 1.2,
    
    -- AI behavior
    DefaultAIData = {
        DeepInheritance = true,
        MoveWithinRange = true,
        PreAttackAngleTowardTarget = true,
        AttackDistance = 200,
        PreAttackDuration = 0.4,
        PostAttackDuration = 0.3,
    },
    
    -- Weapon
    WeaponOptions = { "SwarmerMelee" },
}

-- Elite variants
EnemyData.EliteAttributes = {
    Blink = {
        AIDataOverrides = {
            PreMoveTeleport = true,
            TeleportationIntervalMin = 5.5,
            TeleportationIntervalMax = 9.0,
        },
    },
    
    Frenzy = {
        DataOverrides = {
            EliteAdditionalSpeedMultiplier = 0.5,
        },
    },
    
    HeavyArmor = {
        DataOverrides = {
            HealthMultiplier = 1.5,
        },
    },
}

return EnemyData
