local Camera = {}
Camera.__index = Camera

function Camera.new(x, y)
    local self = setmetatable({}, Camera)

    self.x = x
    self.y = y
    self.targetX = x
    self.targetY = y
    self.smoothness = 6

    return self
end

function Camera:update(px, py, iso, tileH, dt)
    local sx, sy = iso(px, py)
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

    self.targetX = sw / 2 - sx
    self.targetY = sh / 2 - sy + tileH / 2

    self.x = self.x + (self.targetX - self.x) * self.smoothness * dt
    self.y = self.y + (self.targetY - self.y) * self.smoothness * dt
end

return Camera
