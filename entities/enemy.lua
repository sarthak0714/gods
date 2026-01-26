local Enemy = {}
Enemy.__index = Enemy

function Enemy.new(x, y)
    local self = setmetatable({}, Enemy)

    self.x = x
    self.y = y
    self.hp = 3
    self.size = 20

    self.isHit = false
    self.hitFlash = 0
    self.dead = false

    return self
end

function Enemy:takeDamage(dmg)
    if self.dead then return end

    self.hp = self.hp - dmg
    self.isHit = true
    self.hitFlash = 0.1

    if self.hp <= 0 then
        self.dead = true
    end
end

function Enemy:update(dt)
    if self.isHit then
        self.hitFlash = self.hitFlash - dt
        if self.hitFlash <= 0 then
            self.isHit = false
        end
    end
end

function Enemy:draw(iso, camera)
    if self.dead then return end

    local sx, sy = iso(self.x, self.y)

    if self.isHit then
        love.graphics.setColor(0.6, 0, 0, 0.5)
    else
        love.graphics.setColor(1, 0, 0, 1)
    end

    love.graphics.circle("fill", camera.x + sx, camera.y + sy, self.size)
    love.graphics.setColor(1, 1, 1, 1)
end

return Enemy
