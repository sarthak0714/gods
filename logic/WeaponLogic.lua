--[[
    Weapon Logic
    Attack execution, cooldowns, target selection.
    Based on Hades 2 architecture patterns.
]]

local Events = require("core.events")
local Inheritance = require("core.inheritance")
local WeaponData = require("data.WeaponData")
local CombatLogic = require("logic.CombatLogic")

local WeaponLogic = {}

-- Resolve weapon data with inheritance
local resolvedData = nil

local function getResolvedData()
    if not resolvedData then
        resolvedData = Inheritance.resolveAll(WeaponData)
    end
    return resolvedData
end

--- Create new weapon instance
-- @param typeName Weapon type name (e.g., "Mace")
-- @param owner Owner unit
-- @return Weapon logic table
function WeaponLogic.new(typeName, owner)
    local data = getResolvedData()
    local weaponType = data[typeName] or data.BaseWeapon
    
    local weapon = {
        typeName = typeName,
        owner = owner,
        cooldown = 0,
        
        -- Animation state
        anim = {
            type = nil,
            timer = 0,
            duration = 0,
        },
        
        -- Pending damage queue
        pendingDamage = {},
        
        -- Store type data
        _data = weaponType,
    }
    
    -- Link to owner
    if owner then
        owner.weapon = weapon
    end
    
    return weapon
end

--- Update weapon
-- @param weapon Weapon table
-- @param dt Delta time
-- @param audioCallback Callback for sound (name, delay)
function WeaponLogic.update(weapon, dt, audioCallback)
    -- Update cooldown
    if weapon.cooldown > 0 then
        weapon.cooldown = weapon.cooldown - dt
    end
    
    -- Update animation
    if weapon.anim.timer > 0 then
        weapon.anim.timer = weapon.anim.timer - dt
        if weapon.anim.timer <= 0 then
            weapon.anim.type = nil
        end
    end
    
    -- Process pending damage
    WeaponLogic.processPendingDamage(weapon, dt, audioCallback)
end

--- Execute primary attack
-- @param weapon Weapon table
-- @param enemies List of potential targets
-- @return true if attack executed
function WeaponLogic.primary(weapon, enemies)
    if weapon.cooldown > 0 then return false end
    
    local data = weapon._data.Primary
    if not data then return false end
    
    weapon.cooldown = data.Cooldown
    weapon.anim.type = data.AnimationType
    weapon.anim.timer = data.AnimationDuration
    weapon.anim.duration = data.AnimationDuration
    
    local owner = weapon.owner
    local px, py = owner.x, owner.y
    local aim = owner.aim
    
    -- Find targets in range and angle
    for _, enemy in ipairs(enemies) do
        if not enemy.dead then
            local hit = CombatLogic.checkHit(
                px, py,
                aim.x, aim.y,
                enemy.x, enemy.y,
                data.Range,
                data.HitAngle
            )
            
            if hit then
                -- Queue damage for later in animation
                WeaponLogic.queueDamage(weapon, enemy, data.Damage, data.DamageFrame * data.AnimationDuration)
            end
        end
    end
    
    -- Fire weapon event
    Events.notify("OnWeaponFired", {
        owner = owner,
        weapon = weapon.typeName,
        attackType = "primary",
    })
    
    return true
end

--- Execute secondary attack
-- @param weapon Weapon table
-- @param enemies List of potential targets
-- @return true if attack executed
function WeaponLogic.secondary(weapon, enemies)
    if weapon.cooldown > 0 then return false end
    
    local data = weapon._data.Secondary
    if not data then return false end
    
    weapon.cooldown = data.Cooldown
    weapon.anim.type = data.AnimationType
    weapon.anim.timer = data.AnimationDuration
    weapon.anim.duration = data.AnimationDuration
    
    local owner = weapon.owner
    local px, py = owner.x, owner.y
    
    -- Find targets in range (AoE)
    for _, enemy in ipairs(enemies) do
        if not enemy.dead then
            local hit = CombatLogic.checkAOEHit(px, py, enemy.x, enemy.y, data.Range)
            
            if hit then
                WeaponLogic.queueDamage(weapon, enemy, data.Damage, data.DamageFrame * data.AnimationDuration)
            end
        end
    end
    
    Events.notify("OnWeaponFired", {
        owner = owner,
        weapon = weapon.typeName,
        attackType = "secondary",
    })
    
    return true
end

--- Queue damage to be applied later
function WeaponLogic.queueDamage(weapon, target, damage, delay)
    table.insert(weapon.pendingDamage, {
        target = target,
        damage = damage,
        timer = delay,
    })
end

--- Process pending damage queue
function WeaponLogic.processPendingDamage(weapon, dt, audioCallback)
    local EnemyLogic = require("logic.EnemyLogic")
    
    for i = #weapon.pendingDamage, 1, -1 do
        local pd = weapon.pendingDamage[i]
        pd.timer = pd.timer - dt
        
        if pd.timer <= 0 then
            local target = pd.target
            if not target.dead then
                -- Apply damage through target's logic
                EnemyLogic.takeDamage(target, pd.damage, weapon.owner)
            end
            table.remove(weapon.pendingDamage, i)
        end
    end
end

--- Get attack animation type for player animation
function WeaponLogic.getAnimationType(weapon)
    if not weapon.anim.type then
        return nil
    end
    
    if weapon.anim.type == "sweep" then
        return "attack_swipe"
    elseif weapon.anim.type == "slam" then
        return "attack_jump"
    end
    
    return nil
end

return WeaponLogic
