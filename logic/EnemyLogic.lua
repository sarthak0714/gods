--[[
    Enemy Logic
    Game rules for enemy behavior, AI, damage.
    Based on Hades 2 architecture patterns.
]]

local Events = require("core.events")
local State = require("core.state")
local Inheritance = require("core.inheritance")
local EnemyData = require("data.EnemyData")

local EnemyLogic = {}

-- Resolve enemy data with inheritance
local resolvedData = nil

local function getResolvedData()
    if not resolvedData then
        resolvedData = Inheritance.resolveAll(EnemyData)
    end
    return resolvedData
end

--- Create new enemy
-- @param typeName Enemy type name (e.g., "Swarmer")
-- @param x Initial X position
-- @param y Initial Y position
-- @return Enemy logic table
function EnemyLogic.new(typeName, x, y)
    local data = getResolvedData()
    local enemyType = data[typeName] or data.BaseEnemy
    
    local enemy = {
        -- Type info
        typeName = typeName,
        
        -- Position
        x = x or 0,
        y = y or 0,
        
        -- Stats from data
        hp = enemyType.Health,
        maxHp = enemyType.Health,
        size = enemyType.Size,
        hitRange = enemyType.HitRange,
        
        -- AI data
        aiData = Inheritance.deepCopy(enemyType.DefaultAIData or {}),
        aiAggroRange = enemyType.AIAggroRange,
        
        -- Direction (facing player)
        facingX = 1,
        facingY = 0,
        
        -- State
        isHit = false,
        hitFlash = 0,
        dead = false,
        deathAnimComplete = false,
        
        -- Animation state (for presentation)
        animState = "idle",
        
        -- Flags
        required = enemyType.Required,
        
        -- Object ID
        ObjectId = nil,
        
        -- Store type data for presentation
        _data = enemyType,
    }
    
    -- Add to map state
    State.addEnemy(enemy)
    
    -- Fire event
    Events.notify("OnEnemySpawned", { enemy = enemy })
    
    return enemy
end

--- Update enemy logic
-- @param enemy Enemy table
-- @param dt Delta time
-- @param player Player table
function EnemyLogic.update(enemy, dt, player)
    if enemy.dead then
        return
    end
    
    -- Face the player
    if player then
        EnemyLogic.faceTarget(enemy, player.x, player.y)
    end
    
    -- Update hit flash
    if enemy.isHit then
        enemy.hitFlash = enemy.hitFlash - dt
        if enemy.hitFlash <= 0 then
            enemy.isHit = false
        end
    end
end

--- Face towards a target
function EnemyLogic.faceTarget(enemy, targetX, targetY)
    local dx = targetX - enemy.x
    local dy = targetY - enemy.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0.001 then
        enemy.facingX = dx / len
        enemy.facingY = dy / len
    end
end

--- Take damage
-- @param enemy Enemy table
-- @param amount Damage amount
-- @param source Damage source
function EnemyLogic.takeDamage(enemy, amount, source)
    if enemy.dead then return false end
    
    enemy.hp = enemy.hp - amount
    enemy.isHit = true
    enemy.hitFlash = 0.1
    
    State.recordDamageDealt(amount)
    
    Events.notify("OnDamage", {
        victim = enemy,
        attacker = source,
        amount = amount,
        isEnemy = true,
    })
    
    if enemy.hp <= 0 then
        EnemyLogic.die(enemy, source)
    else
        enemy.animState = "hit"
    end
    
    return true
end

--- Enemy death
function EnemyLogic.die(enemy, source)
    enemy.dead = true
    enemy.animState = "death"
    
    -- Record kill
    State.recordKill()
    
    -- Remove from state
    State.removeEnemy(enemy)
    
    -- Fire death event
    Events.notify("OnDeath", {
        unit = enemy,
        killer = source,
        isEnemy = true,
        position = { x = enemy.x, y = enemy.y },
    })
    
    -- Check room clear
    if State.MapState.RoomCleared then
        Events.notify("OnRoomCleared", {})
    end
end

--- Mark death animation complete
function EnemyLogic.markDeathComplete(enemy)
    enemy.deathAnimComplete = true
end

--- Check if enemy is in range of target
function EnemyLogic.isInRange(enemy, targetX, targetY, range)
    local dx = targetX - enemy.x
    local dy = targetY - enemy.y
    local dist = math.sqrt(dx * dx + dy * dy)
    return dist <= range
end

--- Get distance to target
function EnemyLogic.getDistanceTo(enemy, targetX, targetY)
    local dx = targetX - enemy.x
    local dy = targetY - enemy.y
    return math.sqrt(dx * dx + dy * dy)
end

return EnemyLogic
