--[[
    Combat Logic
    Damage calculation, modifiers, hit detection.
    Based on Hades 2 architecture patterns.
]]

local Events = require("core.events")

local CombatLogic = {}

--- Calculate base damage with modifiers
-- @param attacker Attacking unit
-- @param victim Target unit
-- @param baseDamage Base damage amount
-- @param weaponName Weapon used
-- @return Final damage amount
function CombatLogic.calculateDamage(attacker, victim, baseDamage, weaponName)
    local damage = baseDamage
    
    -- Apply outgoing damage modifiers
    if attacker and attacker.OutgoingDamageModifiers then
        for _, modifier in ipairs(attacker.OutgoingDamageModifiers) do
            local validWeapon = modifier.ValidWeaponsLookup == nil
                or modifier.ValidWeaponsLookup[weaponName]
            
            if validWeapon then
                if modifier.Multiplier then
                    damage = damage * modifier.Multiplier
                end
                if modifier.Addition then
                    damage = damage + modifier.Addition
                end
            end
        end
    end
    
    -- Apply incoming damage modifiers (victim defense)
    if victim and victim.IncomingDamageModifiers then
        for _, modifier in ipairs(victim.IncomingDamageModifiers) do
            if modifier.Multiplier then
                damage = damage * modifier.Multiplier
            end
            if modifier.Reduction then
                damage = damage - modifier.Reduction
            end
        end
    end
    
    -- Apply critical hit
    if attacker and attacker.critChance then
        if math.random() < attacker.critChance then
            local critMult = attacker.critMultiplier or 1.5
            damage = damage * critMult
            -- Could fire OnCriticalHit event here
        end
    end
    
    -- Minimum damage
    damage = math.max(1, math.floor(damage))
    
    return damage
end

--- Add outgoing damage modifier to unit
-- @param unit Unit to modify
-- @param modifierData Modifier data table
function CombatLogic.addOutgoingDamageModifier(unit, modifierData)
    if not unit then return end
    
    unit.OutgoingDamageModifiers = unit.OutgoingDamageModifiers or {}
    
    -- Pre-compute lookup for valid weapons
    if modifierData.ValidWeapons and not modifierData.ValidWeaponsLookup then
        modifierData.ValidWeaponsLookup = {}
        for _, weapon in ipairs(modifierData.ValidWeapons) do
            modifierData.ValidWeaponsLookup[weapon] = true
        end
    end
    
    table.insert(unit.OutgoingDamageModifiers, modifierData)
end

--- Remove damage modifier by name
function CombatLogic.removeDamageModifier(unit, modifierName)
    if not unit or not unit.OutgoingDamageModifiers then return end
    
    for i = #unit.OutgoingDamageModifiers, 1, -1 do
        if unit.OutgoingDamageModifiers[i].Name == modifierName then
            table.remove(unit.OutgoingDamageModifiers, i)
            return true
        end
    end
    return false
end

--- Check if attack hits (angle-based cone)
-- @param attackerX Attacker position X
-- @param attackerY Attacker position Y
-- @param aimX Aim direction X
-- @param aimY Aim direction Y
-- @param targetX Target position X
-- @param targetY Target position Y
-- @param range Maximum range
-- @param angleThreshold Dot product threshold (0.4 = ~66° cone)
-- @return true if hit
function CombatLogic.checkHit(attackerX, attackerY, aimX, aimY, targetX, targetY, range, angleThreshold)
    -- Calculate distance
    local dx = targetX - attackerX
    local dy = targetY - attackerY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist > range then
        return false
    end
    
    -- Normalize direction to target
    if dist > 0 then
        dx, dy = dx / dist, dy / dist
    end
    
    -- Check angle (dot product)
    local dot = dx * aimX + dy * aimY
    
    return dot >= (angleThreshold or 0)
end

--- Check if attack hits (area of effect)
-- @param centerX Center position X
-- @param centerY Center position Y
-- @param targetX Target position X
-- @param targetY Target position Y
-- @param radius Effect radius
-- @return true if hit
function CombatLogic.checkAOEHit(centerX, centerY, targetX, targetY, radius)
    local dx = targetX - centerX
    local dy = targetY - centerY
    local dist = math.sqrt(dx * dx + dy * dy)
    return dist <= radius
end

--- Process weapon fire event
function CombatLogic.onWeaponFired(triggerArgs)
    Events.notify("OnWeaponFired", triggerArgs)
end

return CombatLogic
