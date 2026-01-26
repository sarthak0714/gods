local Audio = {
    playing = {}
}
function Audio.load()
    local sounds = {
        dash    = love.audio.newSource("assets/sounds/dash.wav", "static"),
        hit     = love.audio.newSource("assets/sounds/attack.wav", "static"),
        death   = love.audio.newSource("assets/sounds/death.wav", "static"),
        victory = love.audio.newSource("assets/sounds/win.wav", "static")
    }

    sounds.dash:setVolume(0.6)
    sounds.hit:setVolume(0.7)
    sounds.death:setVolume(0.8)
    sounds.victory:setVolume(1.0)

    return sounds
end

function Audio.play(src)
    local s = src:clone()
    s:play()
    table.insert(Audio.playing, s)
end

function Audio.update()
    for i = #Audio.playing, 1, -1 do
        if not Audio.playing[i]:isPlaying() then
            table.remove(Audio.playing, i)
        end
    end
end

return Audio
