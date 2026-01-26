local VictoryText = {}
VictoryText.__index = VictoryText

function VictoryText.new()
    local self = setmetatable({}, VictoryText)

    self.text = "FOE VANQUISHED"
    self.alpha = 0
    self.yOffset = 20
    self.show = false
    self.fadeSpeed = 1.2
    self.font = love.graphics.newFont(64)

    return self
end

function VictoryText:update(dt)
    if self.show then
        self.alpha = math.min(1, self.alpha + dt / self.fadeSpeed)
        self.yOffset = math.max(0, self.yOffset - 40 * dt)
    end
end

function VictoryText:draw()
    if not self.show then return end

    love.graphics.setFont(self.font)

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local tw = self.font:getWidth(self.text)
    local th = self.font:getHeight()

    local x = (sw - tw) / 2
    local y = (sh - th) / 2 - self.yOffset

    love.graphics.setColor(0, 0, 0, self.alpha * 0.6)
    love.graphics.print(self.text, x + 4, y + 4)

    love.graphics.setColor(1, 0.94, 0.07, self.alpha)
    love.graphics.print(self.text, x, y)

    love.graphics.setColor(1, 1, 1, 1)
end

return VictoryText
