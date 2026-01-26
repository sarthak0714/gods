local Player = {}
Player.__index = Player

function Player.new(x, y)
    local self = setmetatable({}, Player)

    self.x = x
    self.y = y
    self.speed = 3
    self.size = 15

    -- dash
    self.isDashing = false
    self.dashTime = 0
    self.dashDuration = 0.15
    self.dashSpeed = 10
    self.dashDX = 0
    self.dashDY = 0
    self.invulnerable = false

    return self
end

-- INPUT (called from main)
function Player:startDash(dx, dy)
    self.isDashing = true
    self.dashTime = self.dashDuration
    self.dashDX = dx
    self.dashDY = dy
    self.invulnerable = true
end

function Player:update(dt, room)
    -- DASH LOGIC
    if self.isDashing then
        local step = 0.05
        local remaining = self.dashSpeed * dt

        while remaining > 0 do
            local s = math.min(step, remaining)

            local nx = self.x + self.dashDX * s
            local ny = self.y + self.dashDY * s

            if room:isWalkable(nx, self.y) then
                self.x = nx
            else
                break
            end

            if room:isWalkable(self.x, ny) then
                self.y = ny
            else
                break
            end

            remaining = remaining - s
        end

        self.dashTime = self.dashTime - dt
        if self.dashTime <= 0 then
            self.isDashing = false
            self.invulnerable = false
        end

        return -- skip normal movement
    end

    -- NORMAL MOVEMENT
    local dx, dy = 0, 0
    if love.keyboard.isDown("w") then dy = dy - 1 end
    if love.keyboard.isDown("s") then dy = dy + 1 end
    if love.keyboard.isDown("a") then dx = dx - 1 end
    if love.keyboard.isDown("d") then dx = dx + 1 end

    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then
        dx, dy = dx / len, dy / len
    end

    local speed = self.speed * dt
    local tryX = self.x + dx * speed
    local tryY = self.y + dy * speed

    if room:isWalkable(tryX, self.y) then
        self.x = tryX
    end
    if room:isWalkable(self.x, tryY) then
        self.y = tryY
    end
end

function Player:draw(iso, camera)
    local sx, sy = iso(self.x, self.y)
    love.graphics.setColor(1, 1, 1, self.invulnerable and 0.5 or 1)
    love.graphics.circle("fill", camera.x + sx, camera.y + sy, self.size)
    love.graphics.setColor(1, 1, 1, 1)
end

function Player:attack(enemy)
    if enemy.dead then return false end

    local dx = enemy.x - self.x
    local dy = enemy.y - self.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < 1.2 then
        enemy:takeDamage(1)
        return true
    end

    return false
end

return Player
