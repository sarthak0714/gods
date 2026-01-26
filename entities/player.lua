local Mace = require("weapons.mace")

local Player = {}
Player.__index = Player


function Player.new(x, y)
    local self = setmetatable({}, Player)

    self.x = x
    self.y = y
    self.speed = 3
    self.size = 15

    -- direction
    self.facing = { x = 1, y = 0 }

    -- dash
    self.isDashing = false
    self.dashTime = 0
    self.dashDuration = 0.15
    self.dashSpeed = 10
    self.dashDX = 0
    self.dashDY = 0
    self.invulnerable = false

    -- weapon
    self.weapon = Mace:new(self)

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
    self.weapon:update(dt)

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

    if len > 0 then
        dx, dy = dx / len, dy / len
        self.facing.x = dx
        self.facing.y = dy
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

function Player:drawWeapon(sx, sy)
    local anim = self.weapon.anim
    if not anim or not anim.type then return end

    local t = 1 - (anim.timer / anim.duration)

    local angle = 0
    local length = 26

    if anim.type == "sweep" then
        angle = -math.pi / 2 + t * math.pi
    elseif anim.type == "slam" then
        angle = math.pi / 2
        length = 26 + t * 14
    end

    love.graphics.push()
    love.graphics.translate(sx, sy)
    love.graphics.rotate(angle)

    -- handle
    love.graphics.setColor(0.45, 0.3, 0.2)
    love.graphics.rectangle("fill", 0, -2, length, 4)

    -- head
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.rectangle("fill", length - 4, -6, 8, 12)

    love.graphics.pop()
end

function Player:draw(iso, camera)
    local sx, sy = iso(self.x, self.y)
    sx, sy = camera.x + sx, camera.y + sy

    -- body
    love.graphics.setColor(1, 1, 1, self.invulnerable and 0.5 or 1)
    love.graphics.circle("fill", sx, sy, self.size)

    -- weapon
    self:drawWeapon(sx, sy)

    love.graphics.setColor(1, 1, 1, 1)
end

function Player:usePrimary(enemies)
    self.weapon:primary(enemies)
end

function Player:useSecondary(enemies)
    self.weapon:secondary(enemies)
end

return Player
