local TILE_W = 128
local TILE_H = 64

local ROOM_W = 12
local ROOM_H = 12

local camera = {
    x = 960,
    y = 200,
}

local victoryFont = love.graphics.newFont(64)

local victoryText = {
    text = "FOE VANQUISHED",
    alpha = 0,
    show = false,
    fadeSpeed = 1.2 -- seconds to fully appear
}


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
    end
end

function drawRoom()
    love.graphics.setColor(1, 0.82, 0.89, 0.25)
    for y = 0, ROOM_H - 1 do
        for x = 0, ROOM_W - 1 do
            local sx, sy = iso(x, y)

            love.graphics.polygon(
                "line",
                camera.x + sx,
                camera.y + sy,
                camera.x + sx + TILE_W / 2,
                camera.y + sy + TILE_H / 2,
                camera.x + sx,
                camera.y + sy + TILE_H,
                camera.x + sx - TILE_W / 2,
                camera.y + sy + TILE_H / 2
            )
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
    end
end

function love.update(dt)
    local dx, dy = 0, 0

    if enemy.isHit then
        enemy.hitFlashTime = enemy.hitFlashTime - dt
        if enemy.hitFlashTime <= 0 then
            enemy.isHit = false
        end
    end

    if player.isDashing then
        player.x = player.x + player.dashDX * player.dashSpeed * dt
        player.y = player.y + player.dashDY * player.dashSpeed * dt

        player.dashTime = player.dashTime - dt

        if player.dashTime <= 0 then
            player.isDashing = false
            player.invulnerable = false
        end

        return -- skip normal movement while dashing
    end

    if love.keyboard.isDown("w") then dy = dy - 1 end
    if love.keyboard.isDown("s") then dy = dy + 1 end
    if love.keyboard.isDown("a") then dx = dx - 1 end
    if love.keyboard.isDown("d") then dx = dx + 1 end

    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then
        dx, dy = dx / len, dy / len
    end

    player.x = player.x + dx * player.speed * dt
    player.y = player.y + dy * player.speed * dt

    -- TILE-BASED BOUNDS (REAL ROOM)
    player.x = math.max(0.2, math.min(ROOM_W - 0.2, player.x))
    player.y = math.max(0.2, math.min(ROOM_H - 0.2, player.y))

    if victoryText.show then
        victoryText.alpha = math.min(1, victoryText.alpha + dt / victoryText.fadeSpeed)
        victoryText.yOffset = math.max(0, victoryText.yOffset - 40 * dt)
    end
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
