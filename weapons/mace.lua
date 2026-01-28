local Weapon = require("weapons.base_weapon")

local Mace = setmetatable({}, Weapon)
Mace.__index = Mace

function Mace:new(owner)
    local w       = Weapon.new(self, owner)

    w.sweepRange  = 1.5  -- reduced from 3 for closer combat
    w.sweepDamage = 1    -- reduced from 20
    w.slamRadius  = 2    -- reduced from 4 for closer combat
    w.slamDamage  = 1    -- reduced from 40

    -- Pending damage queue (damage applied at end of animation)
    w.pendingDamage = {}

    return w
end

-- Queue damage to be applied at end of animation
function Mace:queueDamage(enemy, damage, delay)
    table.insert(self.pendingDamage, {
        enemy = enemy,
        damage = damage,
        timer = delay
    })
end

-- Process pending damage (call from update)
function Mace:processPendingDamage(dt, sounds, Audio)
    for i = #self.pendingDamage, 1, -1 do
        local pd = self.pendingDamage[i]
        pd.timer = pd.timer - dt
        if pd.timer <= 0 then
            local enemy = pd.enemy
            if not enemy.dead then
                local wasAlive = enemy.hp > pd.damage
                enemy:takeDamage(pd.damage)
                
                -- Play appropriate sound
                if enemy.dead then
                    -- Death: only play death sound
                    Audio.play(sounds.death)
                else
                    -- Hit: play enemy damage sound
                    Audio.play(sounds.enemy_damage)
                end
            end
            table.remove(self.pendingDamage, i)
        end
    end
end

function Mace:primary(enemies)
    if self.cooldown > 0 then return false end
    self.cooldown = 2.0  -- Match animation duration

    self.anim.type = "sweep"
    self.anim.timer = 2.0      -- 20 frames × 0.1s = 2s
    self.anim.duration = 2.0

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
                -- Queue damage for end of animation
                self:queueDamage(enemy, self.sweepDamage, self.anim.duration)
            end
        end

        ::continue::
    end
    return true
end

function Mace:secondary(enemies)
    if self.cooldown > 0 then return false end
    self.cooldown = 2.4  -- Match animation duration

    self.anim.type = "slam"
    self.anim.timer = 2.4      -- 24 frames × 0.1s = 2.4s
    self.anim.duration = 2.4

    local px, py = self.owner.x, self.owner.y

    for _, enemy in ipairs(enemies) do
        if enemy.dead then goto continue end

        local dx = enemy.x - px
        local dy = enemy.y - py
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist <= self.slamRadius then
            -- Queue damage for end of animation
            self:queueDamage(enemy, self.slamDamage, self.anim.duration)
        end

        ::continue::
    end
    return true
end

return Mace
