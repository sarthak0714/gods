--[[
    Weapon Data Definitions
    Static configuration for weapon types.
    Based on Hades 2 architecture patterns.
]]

local WeaponData = {}

-- Base weapon (all weapons inherit from this)
WeaponData.BaseWeapon = {
    -- Core stats
    Damage = 1,
    CriticalChance = 0.0,
    CriticalMultiplier = 1.5,
    
    -- Behavior
    DefaultCooldown = 1.0,
    
    -- Animation
    AnimationType = "sweep",
    AnimationDuration = 1.0,
    
    -- Damage timing (% through animation)
    DamageFrame = 0.7,
}

-- Base enemy weapon
WeaponData.BaseEnemyWeapon = {
    InheritFrom = { "BaseWeapon" },
    
    Damage = 10,
    Range = 150,
    
    AIData = {
        AttackDistance = 200,
        PreAttackDuration = 0.4,
        PostAttackDuration = 0.3,
    },
}

-- Player Mace weapon
WeaponData.Mace = {
    InheritFrom = { "BaseWeapon" },
    
    -- Primary attack (sweep)
    Primary = {
        Damage = 1,
        Range = 1.5,
        Cooldown = 2.0,
        AnimationType = "sweep",
        AnimationDuration = 2.0,
        DamageFrame = 0.7,
        HitAngle = 0.4,  -- Dot product threshold for hit cone
        Sound = "attack_swipe",
        SoundDelay = 1.0,  -- 50% of 2.0s animation
    },
    
    -- Secondary attack (slam)
    Secondary = {
        Damage = 1,
        Range = 2.0,
        Cooldown = 2.4,
        AnimationType = "slam",
        AnimationDuration = 2.4,
        DamageFrame = 0.7,
        AreaOfEffect = true,  -- Hits all enemies in range
        Sound = "attack_jump",
        SoundDelay = 1.2,  -- 50% of 2.4s animation
    },
    
    -- Visual settings
    HandleLength = 100,
    HandleColor = { 0.45, 0.3, 0.2 },
    HeadColor = { 0.7, 0.7, 0.7 },
    HeadSize = { width = 8, height = 12 },
}

-- Enemy Swarmer melee
WeaponData.SwarmerMelee = {
    InheritFrom = { "BaseEnemyWeapon" },
    
    Damage = 15,
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

return WeaponData
