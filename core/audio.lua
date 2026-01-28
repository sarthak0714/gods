local Audio = {
    playing = {},
    delayed = {}  -- Queue for delayed sounds
}
function Audio.load()
    local sounds = {
        dash    = love.audio.newSource("assets/sounds/dash.wav", "static"),
        hit     = love.audio.newSource("assets/sounds/attack.wav", "static"),
        attack_swipe = love.audio.newSource("assets/sounds/attack.wav", "static"),
        attack_jump = love.audio.newSource("assets/sounds/attack.wav", "static"),
        enemy_damage = love.audio.newSource("assets/sounds/enemy_damage.wav", "static"),
        death   = love.audio.newSource("assets/sounds/death.wav", "static"),
        victory = love.audio.newSource("assets/sounds/win.wav", "static")
    }

    sounds.dash:setVolume(0.6)
    sounds.hit:setVolume(0.7)
    
    -- Slow down attack sounds to match animation duration (lower pitch = slower/longer)
    sounds.attack_swipe:setVolume(0.7)
    sounds.attack_swipe:setPitch(0.3)  -- ~3x longer duration
    
    sounds.attack_jump:setVolume(0.7)
    sounds.attack_jump:setPitch(0.25)  -- ~4x longer duration
    
    sounds.death:setVolume(0.8)
    sounds.victory:setVolume(1.0)

    return sounds
end

function Audio.play(src)
    local s = src:clone()
    s:play()
    table.insert(Audio.playing, s)
end

-- Play a sound after a delay (in seconds)
function Audio.playDelayed(src, delay)
    table.insert(Audio.delayed, {
        source = src,
        timer = delay
    })
end

function Audio.update(dt)
    -- Update delayed sounds
    for i = #Audio.delayed, 1, -1 do
        local d = Audio.delayed[i]
        d.timer = d.timer - dt
        if d.timer <= 0 then
            Audio.play(d.source)
            table.remove(Audio.delayed, i)
        end
    end
    
    -- Clean up finished sounds
    for i = #Audio.playing, 1, -1 do
        if not Audio.playing[i]:isPlaying() then
            table.remove(Audio.playing, i)
        end
    end
end

return Audio
