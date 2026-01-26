local Mace = require("weapons.mace")
local Iso = require("core.iso")


local Player = {}
Player.__index = Player


function Player.new(x, y)
    local self = setmetatable({}, Player)

    self.aim = { x = 1, y = 0 }

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

function Player:updateAim(camera, tileW, tileH)
    local mx, my = love.mouse.getPosition()

    -- convert mouse screen → camera space
    local cx = mx - camera.x
    local cy = my - camera.y

    -- convert camera space → world (iso)
    local wx, wy = Iso.screenToWorld(cx, cy, tileW, tileH)

    local dx = wx - self.x
    local dy = wy - self.y

    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0.0001 then
        self.aim.x = dx / len
        self.aim.y = dy / len
    end
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

    local aim = self.aim
    local baseAngle = math.atan2(aim.y, aim.x)

    local angle = baseAngle
    local length = 100

    if anim.type == "sweep" then
        local sweepArc = math.pi * 0.8
        angle = baseAngle - sweepArc / 2 + t * sweepArc
    elseif anim.type == "slam" then
        length = 100 + t * 14
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


    ---- DEBUG
    -- DEBUG AIM LINE
    -- love.graphics.setColor(1, 0, 0)
    -- love.graphics.line(
    --     sx,
    --     sy,
    --     sx + self.aim.x * 40,
    --     sy + self.aim.y * 40
    -- )
    -- love.graphics.setColor(1, 1, 1)

    --- DEBUG

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
