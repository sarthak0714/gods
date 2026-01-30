--[[
    Audio Presentation
    Sound playback, responds to game events.
    Based on Hades 2 architecture patterns.
]]

local Events = require("core.events")
local AudioData = require("data.AudioData")

local AudioPresentation = {}

-- Loaded sound sources
local loadedSounds = {}
local playing = {}
local delayed = {}

--- Initialize audio system
function AudioPresentation.init()
    loadedSounds = {}
    playing = {}
    delayed = {}
    
    -- Load all SFX
    for name, config in pairs(AudioData.SFX) do
        local success, source = pcall(love.audio.newSource, config.Path, config.Type)
        if success then
            source:setVolume(config.Volume or 1.0)
            if config.Pitch then
                source:setPitch(config.Pitch)
            end
            loadedSounds[name] = source
        else
            print("[Audio] Warning: Could not load sound: " .. config.Path)
        end
    end
    
    -- Register event handlers
    AudioPresentation.registerEventHandlers()
    
    return loadedSounds
end

--- Register event handlers for audio
function AudioPresentation.registerEventHandlers()
    -- Player dash
    Events.on("OnPlayerDash", function(args)
        AudioPresentation.play("dash")
    end)
    
    -- Weapon fired
    Events.on("OnWeaponFired", function(args)
        local attackType = args.attackType
        if attackType == "primary" then
            AudioPresentation.playDelayed("attack_swipe", 1.0)
        elseif attackType == "secondary" then
            AudioPresentation.playDelayed("attack_jump", 1.2)
        end
    end)
    
    -- Damage
    Events.on("OnDamage", function(args)
        if args.isEnemy and not args.victim.dead then
            AudioPresentation.play("enemy_damage")
        end
    end)
    
    -- Death
    Events.on("OnDeath", function(args)
        AudioPresentation.play("death")
    end)
    
    -- Room cleared
    Events.on("OnRoomCleared", function(args)
        AudioPresentation.play("victory")
    end)
end

--- Play sound immediately
function AudioPresentation.play(name)
    local source = loadedSounds[name]
    if not source then return nil end
    
    local clone = source:clone()
    clone:play()
    table.insert(playing, clone)
    return clone
end

--- Play sound after delay
function AudioPresentation.playDelayed(name, delay)
    local source = loadedSounds[name]
    if not source then return end
    
    table.insert(delayed, {
        source = source,
        timer = delay,
    })
end

--- Update audio system
function AudioPresentation.update(dt)
    -- Process delayed sounds
    for i = #delayed, 1, -1 do
        local d = delayed[i]
        d.timer = d.timer - dt
        if d.timer <= 0 then
            local clone = d.source:clone()
            clone:play()
            table.insert(playing, clone)
            table.remove(delayed, i)
        end
    end
    
    -- Clean up finished sounds
    for i = #playing, 1, -1 do
        if not playing[i]:isPlaying() then
            table.remove(playing, i)
        end
    end
end

--- Stop all sounds
function AudioPresentation.stopAll()
    for _, source in ipairs(playing) do
        source:stop()
    end
    playing = {}
    delayed = {}
end

--- Get sound source for external use
function AudioPresentation.getSound(name)
    return loadedSounds[name]
end

--- Set master volume
function AudioPresentation.setMasterVolume(volume)
    love.audio.setVolume(volume)
end

return AudioPresentation
