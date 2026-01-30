--[[
    Gods - Main Entry Point
    Uses Hades 2-style Data-Logic-Presentation architecture.
]]

-- Core Systems
local Iso = require("core.iso")
local Camera = require("core.camera")
local Events = require("core.events")
local State = require("core.state")

-- Logic Layer
local PlayerLogic = require("logic.PlayerLogic")
local EnemyLogic = require("logic.EnemyLogic")
local WeaponLogic = require("logic.WeaponLogic")

-- Presentation Layer
local PlayerPresentation = require("presentation.PlayerPresentation")
local EnemyPresentation = require("presentation.EnemyPresentation")
local AudioPresentation = require("presentation.AudioPresentation")

-- World
local Room = require("world.room")

-- UI
local VictoryText = require("ui.victory_text")

-- Native (optional C++ extension)
local Native = require("native.bindings.ffi_bindings")

-- Constants
local TILE_W, TILE_H = 150, 96
local GRID_FILL = { 84 / 255, 225 / 255, 227 / 255 }
local GRID_LINE = { 84 / 255, 225 / 255, 227 / 255 }

-- Game objects
local room, camera, victory
local player, playerPres
local enemy, enemyPres

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
    -- Initialize state
    State.initAll()
    
    -- Initialize audio (registers event handlers)
    AudioPresentation.init()
    
    -- Initialize native engine if available
    if Native.available then
        Native.init()
        print("Native engine: " .. Native.getVersion())
    end
    
    -- Create room
    room = Room.new(25, 25)
    room:generate()
    
    -- Create player (Logic + Presentation)
    local px, py = room:getRandomTile()
    player = PlayerLogic.new(px, py)
    playerPres = PlayerPresentation.new()
    
    -- Create weapon for player
    player.weapon = WeaponLogic.new("Mace", player)
    
    -- Create enemy (Logic + Presentation)
    local ex, ey = room:getRandomTile()
    enemy = EnemyLogic.new("Swarmer", ex, ey)
    enemyPres = EnemyPresentation.new()
    
    -- Camera and UI
    camera = Camera.new(960, 200)
    victory = VictoryText.new()
end

-- =========================
-- UPDATE
-- =========================
function love.update(dt)
    -- Update enemy logic
    EnemyLogic.update(enemy, dt, player)
    EnemyPresentation.update(enemyPres, enemy, dt)
    
    -- Update victory UI
    victory:update(dt)
    
    -- Update weapon
    WeaponLogic.update(player.weapon, dt)
    
    -- Determine player animation state from weapon
    if WeaponLogic.getAnimationType(player.weapon) then
        player.animState = WeaponLogic.getAnimationType(player.weapon)
    end
    
    -- Update player logic (movement, dash)
    if not WeaponLogic.getAnimationType(player.weapon) then
        PlayerLogic.update(player, dt, room)
    end
    
    -- Update player presentation
    PlayerPresentation.update(playerPres, player, dt)
    
    -- Weapon input
    if love.mouse.isDown(1) then
        WeaponLogic.primary(player.weapon, { enemy })
    end
    
    if love.mouse.isDown(2) then
        WeaponLogic.secondary(player.weapon, { enemy })
    end
    
    -- Camera follow
    camera:update(
        player.x,
        player.y,
        function(x, y) return Iso.project(x, y, TILE_W, TILE_H) end,
        TILE_H,
        dt
    )
    
    -- Update aim from mouse
    local mx, my = love.mouse.getPosition()
    local cx = mx - camera.x
    local cy = my - camera.y
    local wx, wy = Iso.screenToWorld(cx, cy, TILE_W, TILE_H)
    PlayerLogic.updateAim(player, wx, wy)
    
    -- Update audio
    AudioPresentation.update(dt)
end

-- =========================
-- DASH INPUT
-- =========================
function love.keypressed(key)
    if key == "space" and not player.isDashing then
        local dx, dy = 0, 0
        if love.keyboard.isDown("w") then dx = dx - 1; dy = dy - 1 end
        if love.keyboard.isDown("s") then dx = dx + 1; dy = dy + 1 end
        if love.keyboard.isDown("a") then dx = dx - 1; dy = dy + 1 end
        if love.keyboard.isDown("d") then dx = dx + 1; dy = dy - 1 end

        local len = math.sqrt(dx * dx + dy * dy)
        if len == 0 then return end

        dx, dy = dx / len, dy / len
        PlayerLogic.startDash(player, dx, dy)
    end
end

-- =========================
-- DRAW
-- =========================
function love.draw()
    drawRoom()

    -- Sort drawables by Y for proper depth
    local drawables = {
        { logic = player, pres = playerPres, isPlayer = true },
        { logic = enemy, pres = enemyPres, isPlayer = false },
    }
    table.sort(drawables, function(a, b)
        return a.logic.y < b.logic.y
    end)

    for _, d in ipairs(drawables) do
        local sx, sy = Iso.project(d.logic.x, d.logic.y, TILE_W, TILE_H)
        sx = sx + camera.x
        sy = sy + camera.y
        
        if d.isPlayer then
            PlayerPresentation.draw(d.pres, d.logic, sx, sy)
        else
            EnemyPresentation.draw(d.pres, d.logic, sx, sy)
        end
    end

    victory:draw()
end
