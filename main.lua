local Iso              = require("core.iso")
local Camera           = require("core.camera")
local Audio            = require("core.audio")
local Room             = require("world.room")
local Player           = require("entities.player")
local Enemy            = require("entities.enemy")
local VictoryText      = require("ui.victory_text")

local TILE_W, TILE_H   = 150, 96

local GRID_FILL        = { 84 / 255, 225 / 255, 227 / 255 }
local GRID_LINE        = { 84 / 255, 225 / 255, 227 / 255 }

local victoryTriggered = false

-- =========================
-- ROOM DRAW
-- =========================
local function drawRoom()
    for y = 1, room.h do
        for x = 1, room.w do
            if room.map[y][x] then
                local sx, sy = Iso.project(x - 1, y - 1, TILE_W, TILE_H)

                local p1x, p1y = camera.x + sx, camera.y + sy
                local p2x, p2y = camera.x + sx + TILE_W / 2, camera.y + sy + TILE_H / 2
                local p3x, p3y = camera.x + sx, camera.y + sy + TILE_H
                local p4x, p4y = camera.x + sx - TILE_W / 2, camera.y + sy + TILE_H / 2

                local depth = y / room.h

                love.graphics.setColor(
                    GRID_FILL[1],
                    GRID_FILL[2],
                    GRID_FILL[3],
                    0.08 + depth * 0.10
                )
                love.graphics.polygon("fill", p1x, p1y, p2x, p2y, p3x, p3y, p4x, p4y)

                love.graphics.setColor(GRID_LINE[1], GRID_LINE[2], GRID_LINE[3], 0.35)
                love.graphics.polygon("line", p1x, p1y, p2x, p2y, p3x, p3y, p4x, p4y)
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- =========================
-- LOAD
-- =========================
function love.load()
    sounds = Audio.load()

    room = Room.new(25, 25)
    room:generate()

    player  = Player.new(room:getRandomTile())
    enemy   = Enemy.new(room:getRandomTile())

    camera  = Camera.new(960, 200)
    victory = VictoryText.new()
end

-- =========================
-- UPDATE
-- =========================
function love.update(dt)
    enemy:update(dt, player)
    victory:update(dt)

    -- PLAYER (movement + dash + weapon update)
    player:update(dt, room, sounds, Audio)

    -- WEAPON INPUT (sounds delayed to 50% of animation duration)
    if love.mouse.isDown(1) then
        if player:usePrimary({ enemy }) then
            Audio.playDelayed(sounds.attack_swipe, 1.0)  -- 50% of 2.0s animation
        end
    end

    if love.mouse.isDown(2) then
        if player:useSecondary({ enemy }) then
            Audio.playDelayed(sounds.attack_jump, 1.2)  -- 50% of 2.4s animation
        end
    end

    -- CAMERA FOLLOW
    camera:update(
        player.x,
        player.y,
        function(x, y) return Iso.project(x, y, TILE_W, TILE_H) end,
        TILE_H,
        dt
    )

    player:updateAim(camera, TILE_W, TILE_H)


    Audio.update(dt)
end

-- =========================
-- DASH INPUT
-- =========================
function love.keypressed(key)
    if key == "space" and not player.isDashing then
        -- Isometric screen-space directions for dash
        local dx, dy = 0, 0
        if love.keyboard.isDown("w") then dx = dx - 1; dy = dy - 1 end  -- top corner
        if love.keyboard.isDown("s") then dx = dx + 1; dy = dy + 1 end  -- bottom corner
        if love.keyboard.isDown("a") then dx = dx - 1; dy = dy + 1 end  -- left corner
        if love.keyboard.isDown("d") then dx = dx + 1; dy = dy - 1 end  -- right corner

        local len = math.sqrt(dx * dx + dy * dy)
        if len == 0 then return end

        dx, dy = dx / len, dy / len
        player:startDash(dx, dy)

        Audio.play(sounds.dash)
    end
end

-- =========================
-- DRAW
-- =========================
function love.draw()
    drawRoom()

    local drawables = { player, enemy }
    table.sort(drawables, function(a, b)
        return a.y < b.y
    end)

    for _, e in ipairs(drawables) do
        e:draw(function(x, y)
            return Iso.project(x, y, TILE_W, TILE_H)
        end, camera)
    end

    victory:draw()
end
