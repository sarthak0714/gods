local Room = {}
Room.__index = Room

function Room.new(w, h)
    local self = setmetatable({}, Room)

    self.w = w
    self.h = h
    self.map = {}

    return self
end

function Room:generate()
    local cx, cy = self.w / 2, self.h / 2
    local baseRadius = math.min(self.w, self.h) * 0.35

    for y = 1, self.h do
        self.map[y] = {}
        for x = 1, self.w do
            local dx, dy = x - cx, y - cy
            local dist = math.sqrt(dx * dx + dy * dy)
            local noise = love.math.noise(x * 0.15, y * 0.15) * 4
            self.map[y][x] = dist < (baseRadius + noise)
        end
    end
end

function Room:isWalkable(tx, ty)
    local x = math.floor(tx) + 1
    local y = math.floor(ty) + 1
    return self.map[y] and self.map[y][x]
end

function Room:getRandomTile()
    for _ = 1, 1000 do
        local x = love.math.random(1, self.w)
        local y = love.math.random(1, self.h)
        if self.map[y][x] then
            return x - 0.5, y - 0.5
        end
    end
    return self.w / 2, self.h / 2
end

return Room
