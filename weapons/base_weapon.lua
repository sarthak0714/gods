local Weapon = {}
Weapon.__index = Weapon

function Weapon:new(owner)
    local w = setmetatable({}, self)
    w.owner = owner
    w.cooldown = 0
    w.anim = {
        type = nil,
        timer = 0,
        duration = 0
    }
    return w
end

function Weapon:update(dt, sounds, Audio)
    if self.cooldown > 0 then
        self.cooldown = self.cooldown - dt
    end

    if self.anim.timer > 0 then
        self.anim.timer = self.anim.timer - dt
        if self.anim.timer <= 0 then
            self.anim.type = nil
        end
    end

    -- Process pending damage if the weapon has it
    if self.processPendingDamage then
        self:processPendingDamage(dt, sounds, Audio)
    end
end

return Weapon
