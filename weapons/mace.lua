local Weapon = require("weapons.base_weapon")

local Mace = setmetatable({}, Weapon)
Mace.__index = Mace

function Mace:new(owner)
    local w       = Weapon.new(self, owner)

    w.sweepRange  = 3
    w.sweepDamage = 20
    w.slamRadius  = 4
    w.slamDamage  = 40

    return w
end

function Mace:primary(enemies)
    if self.cooldown > 0 then return end
    self.cooldown = 0.4

    self.anim.type = "sweep"
    self.anim.timer = 0.15
    self.anim.duration = 0.15

    local px, py = self.owner.x, self.owner.y
    local aim = self.owner.aim

    for _, enemy in ipairs(enemies) do
        if enemy.dead then goto continue end

        local dx = enemy.x - px
        local dy = enemy.y - py
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist <= self.sweepRange then
            local dot = dx * aim.x + dy * aim.y
            if dot > 0.4 then
                enemy:takeDamage(self.sweepDamage)
            end
        end

        ::continue::
    end
end

function Mace:secondary(enemies)
    if self.cooldown > 0 then return end
    self.cooldown = 1.0

    self.anim.type = "slam"
    self.anim.timer = 0.25
    self.anim.duration = 0.25

    local px, py = self.owner.x, self.owner.y

    for _, enemy in ipairs(enemies) do
        if enemy.dead then goto continue end

        local dx = enemy.x - px
        local dy = enemy.y - py
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist <= self.slamRadius then
            enemy:takeDamage(self.slamDamage)
        end

        ::continue::
    end
end

return Mace
