local TILE_W    = 150
local TILE_H    = 96

local ROOM_W    = 25
local ROOM_H    = 25

local roomMap   = {}
local sounds    = {}

local GRID_FILL = { 84 / 255, 225 / 255, 227 / 255, 0.12 } -- light, subtle
local GRID_LINE = { 84 / 255, 225 / 255, 227 / 255, 0.35 } -- darker border


local camera = {
    x = 960,
    y = 200,
    targetX = 960,
    targetY = 200,
    smoothness = 6
}

local victoryFont = love.graphics.newFont(64)

local victoryText = {
    text = "FOE VANQUISHED",
    alpha = 0,
    show = false,
    fadeSpeed = 1.2 -- seconds to fully appear
}

function getRandomWalkableTile()
    for i = 1, 1000 do
        local x = love.math.random(1, ROOM_W)
        local y = love.math.random(1, ROOM_H)
        if roomMap[y][x] then
            return x - 0.5, y - 0.5
        end
    end
    -- fallback to center
    return ROOM_W / 2, ROOM_H / 2
end

function generateRoom()
    roomMap = {}

    local cx = ROOM_W / 2
    local cy = ROOM_H / 2

    local baseRadius = math.min(ROOM_W, ROOM_H) * 0.35

    for y = 1, ROOM_H do
        roomMap[y] = {}
        for x = 1, ROOM_W do
            local dx = x - cx
            local dy = y - cy
            local dist = math.sqrt(dx * dx + dy * dy)

            local noise = love.math.noise(x * 0.15, y * 0.15) * 4

            roomMap[y][x] = dist < (baseRadius + noise)
        end
    end
end

local function isWalkable(tx, ty)
    local x = math.floor(tx) + 1
    local y = math.floor(ty) + 1
    return roomMap[y] and roomMap[y][x]
end



-- PLAYER
local player = {
    x = 4.5,
    y = 4.5,
    speed = 3,
    size = 15,
    draw = function(self)
        local sx, sy = iso(self.x, self.y)
        if self.invulnerable then
            love.graphics.setColor(1, 1, 1, 0.5)
        end
        love.graphics.circle(
            "fill",
            camera.x + sx,
            camera.y + sy,
            self.size
        )
        love.graphics.setColor(1, 1, 1, 1)
    end,
    -- dash
    isDashing = false,
    dashTime = 0,
    dashDuration = 0.15,
    dashSpeed = 10,
    dashDX = 0,
    dashDY = 0,
    inv = false

}
local enemy = {
    x = 6,
    y = 5,
    hp = 3,
    size = 20,

    isHit = false,
    hitFlashTime = 0,

    draw = function(self)
        local sx, sy = iso(self.x, self.y)

        if self.isHit then
            -- darker, dim red
            love.graphics.setColor(0.6, 0.0, 0.0, 0.5)
        else
            -- normal red
            love.graphics.setColor(1.0, 0.0, 0.0, 1.0)
        end

        love.graphics.circle(
            "fill",
            camera.x + sx,
            camera.y + sy,
            self.size
        )

        love.graphics.setColor(1, 1, 1, 1) -- reset
    end
}


local roomLocked = true

function updateRoomState()
    roomLocked = enemy.hp > 0

    if not roomLocked and not victoryText.show then
        victoryText.show = true
        victoryText.alpha = 0
        victoryText.yOffset = 20

        playSound(sounds.victory)
    end
end

function drawRoom()
    for y = 1, ROOM_H do
        for x = 1, ROOM_W do
            if roomMap[y][x] then
                local sx, sy = iso(x - 1, y - 1)

                local p1x, p1y = camera.x + sx, camera.y + sy
                local p2x, p2y = camera.x + sx + TILE_W / 2, camera.y + sy + TILE_H / 2
                local p3x, p3y = camera.x + sx, camera.y + sy + TILE_H
                local p4x, p4y = camera.x + sx - TILE_W / 2, camera.y + sy + TILE_H / 2

                -- 🔹 DEPTH FACTOR (0 at top → 1 at bottom)
                local depth = y / ROOM_H

                -- FILL (lighter at top, slightly darker at bottom)
                love.graphics.setColor(
                    84 / 255,
                    225 / 255,
                    227 / 255,
                    0.08 + depth * 0.10
                )

                love.graphics.polygon(
                    "fill",
                    p1x, p1y,
                    p2x, p2y,
                    p3x, p3y,
                    p4x, p4y
                )

                -- BORDER (constant color)
                love.graphics.setColor(84 / 255, 225 / 255, 227 / 255, 0.35)
                love.graphics.polygon(
                    "line",
                    p1x, p1y,
                    p2x, p2y,
                    p3x, p3y,
                    p4x, p4y
                )
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function iso(x, y)
    return (x - y) * TILE_W / 2, (x + y) * TILE_H / 2
end

-- ATTACK
function love.mousepressed(x, y, button)
    if button == 1 and enemy.hp > 0 then
        local dx = enemy.x - player.x
        local dy = enemy.y - player.y
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist < 1.2 then
            enemy.hp = enemy.hp - 1
            enemy.isHit = true
            enemy.hitFlashTime = 0.08
            playSound(sounds.hit)
            updateRoomState()
        end
    end
end

-- DASH
function love.keypressed(key)
    if key == "space" and not player.isDashing then
        local dx, dy = 0, 0

        if love.keyboard.isDown("w") then dy = -1 end
        if love.keyboard.isDown("s") then dy = 1 end
        if love.keyboard.isDown("a") then dx = -1 end
        if love.keyboard.isDown("d") then dx = 1 end

        local len = math.sqrt(dx * dx + dy * dy)
        if len == 0 then return end

        dx, dy = dx / len, dy / len

        player.isDashing = true
        player.invulnerable = true
        player.dashTime = player.dashDuration
        player.dashDX = dx
        player.dashDY = dy
        playSound(sounds.dash)
    end
end

function love.update(dt)
    local dx, dy = 0, 0

    if victoryText.show and victoryText.timer then
        victoryText.timer = victoryText.timer - dt
        if victoryText.timer <= 0 then
            playSound(sounds.victory)
            victoryText.timer = nil
        end
    end


    if enemy.isHit then
        enemy.hitFlashTime = enemy.hitFlashTime - dt
        if enemy.hitFlashTime <= 0 then
            enemy.isHit = false
        end
    end

    if player.isDashing then
        local step = 0.05 -- tile precision
        local remaining = player.dashSpeed * dt

        while remaining > 0 do
            local stepSize = math.min(step, remaining)

            local nextX = player.x + player.dashDX * stepSize
            local nextY = player.y + player.dashDY * stepSize

            if isWalkable(nextX, player.y) then
                player.x = nextX
            else
                break
            end

            if isWalkable(player.x, nextY) then
                player.y = nextY
            else
                break
            end

            remaining = remaining - stepSize
        end

        player.dashTime = player.dashTime - dt
        if player.dashTime <= 0 then
            player.isDashing = false
            player.invulnerable = false
        end
        return
    end



    if love.keyboard.isDown("w") then dy = dy - 1 end
    if love.keyboard.isDown("s") then dy = dy + 1 end
    if love.keyboard.isDown("a") then dx = dx - 1 end
    if love.keyboard.isDown("d") then dx = dx + 1 end

    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then
        dx, dy = dx / len, dy / len
    end

    local moveX = dx * player.speed * dt
    local moveY = dy * player.speed * dt

    local margin = 0.15

    local tryX = player.x + moveX
    local tryY = player.y + moveY

    if isWalkable(tryX + (dx > 0 and margin or -margin), player.y) then
        player.x = tryX
    end

    if isWalkable(player.x, tryY + (dy > 0 and margin or -margin)) then
        player.y = tryY
    end

    local px, py = iso(player.x, player.y)

    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    camera.targetX = screenW / 2 - px
    camera.targetY = screenH / 2 - py + TILE_H / 2

    camera.x = camera.x + (camera.targetX - camera.x) * camera.smoothness * dt
    camera.y = camera.y + (camera.targetY - camera.y) * camera.smoothness * dt


    if victoryText.show then
        victoryText.alpha = math.min(1, victoryText.alpha + dt / victoryText.fadeSpeed)
        victoryText.yOffset = math.max(0, victoryText.yOffset - 40 * dt)
    end
end

function love.load()
    generateRoom()

    sounds.dash      = love.audio.newSource("sounds/dash.wav", "static")
    sounds.hit       = love.audio.newSource("sounds/attack.wav", "static")
    sounds.enemy_die = love.audio.newSource("sounds/death.wav", "static")
    sounds.victory   = love.audio.newSource("sounds/win.wav", "static")

    sounds.dash:setVolume(0.6)
    sounds.hit:setVolume(0.7)
    sounds.enemy_die:setVolume(0.8)
    sounds.victory:setVolume(1.0)

    player.x, player.y = getRandomWalkableTile()
    enemy.x, enemy.y   = getRandomWalkableTile()
end

function playSound(src)
    local s = src:clone()
    s:play()
end

function love.draw()
    drawRoom()

    local drawables = { player }

    if enemy.hp > 0 then
        table.insert(drawables, enemy)
    end

    table.sort(drawables, function(a, b)
        return a.y < b.y
    end)

    for _, e in ipairs(drawables) do
        e:draw()
    end


    if victoryText.show then
        love.graphics.setFont(victoryFont)

        local screenW = love.graphics.getWidth()
        local screenH = love.graphics.getHeight()

        local text = victoryText.text
        local textW = victoryFont:getWidth(text)
        local textH = victoryFont:getHeight()

        local x = (screenW - textW) / 2
        local y = (screenH - textH) / 2 - victoryText.yOffset

        -- SHADOW (draw first)
        love.graphics.setColor(0, 0, 0, victoryText.alpha * 0.6)
        love.graphics.print(text, x + 4, y + 4)

        -- MAIN TEXT (gold)
        love.graphics.setColor(1.0, 0.94, 0.07, victoryText.alpha)
        love.graphics.print(text, x, y)

        love.graphics.setColor(1, 1, 1, 1)
    end
end
