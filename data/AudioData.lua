--[[
    Audio Data Definitions
    Static configuration for sound effects and music.
    Based on Hades 2 architecture patterns.
]]

local AudioData = {}

-- Sound effect definitions
AudioData.SFX = {
    -- Player sounds
    dash = {
        Path = "assets/sounds/dash.wav",
        Type = "static",
        Volume = 0.6,
        Pitch = 1.0,
    },
    
    -- Attack sounds
    attack_swipe = {
        Path = "assets/sounds/attack.wav",
        Type = "static",
        Volume = 0.7,
        Pitch = 0.3,  -- Slowed to match animation
    },
    
    attack_jump = {
        Path = "assets/sounds/attack.wav",
        Type = "static",
        Volume = 0.7,
        Pitch = 0.25,  -- Slowed to match animation
    },
    
    hit = {
        Path = "assets/sounds/attack.wav",
        Type = "static",
        Volume = 0.7,
        Pitch = 1.0,
    },
    
    -- Enemy sounds
    enemy_damage = {
        Path = "assets/sounds/enemy_damage.wav",
        Type = "static",
        Volume = 0.6,
        Pitch = 1.0,
    },
    
    -- Death/Victory
    death = {
        Path = "assets/sounds/death.wav",
        Type = "static",
        Volume = 0.8,
        Pitch = 1.0,
    },
    
    victory = {
        Path = "assets/sounds/win.wav",
        Type = "static",
        Volume = 1.0,
        Pitch = 1.0,
    },
}

-- Music definitions
AudioData.Music = {
    combat = {
        Path = "assets/sounds/combat_music.ogg",
        Type = "stream",
        Volume = 0.7,
        Loop = true,
    },
    
    victory = {
        Path = "assets/sounds/victory_music.ogg",
        Type = "stream",
        Volume = 0.8,
        Loop = false,
    },
}

-- Audio manager caps
AudioData.Settings = {
    MaxConcurrentSFX = 32,
    MaxConcurrentMusic = 2,
    FadeTime = 0.5,
    MasterVolume = 1.0,
}

return AudioData
