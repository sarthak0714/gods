--[[
    Player Logic
    Game rules for player behavior, movement, state.
    Based on Hades 2 architecture patterns.
]]

local Events = require("core.events")
local State = require("core.state")
local PlayerData = require("data.PlayerData")

local PlayerLogic = {}

--- Create new player logic instance
-- @param x Initial X position
-- @param y Initial Y position
-- @return Player logic table
function PlayerLogic.new(x, y)
    local data = PlayerData.Base
    
    local player = {
        -- Position
        x = x or 0,
        y = y or 0,
        
        -- Stats from data
        health = data.Health,
        maxHealth = data.MaxHealth,
        speed = data.Speed,
        size = data.Size,
        
        -- Direction
        facing = { x = 1, y = 0 },
        aim = { x = 1, y = 0 },
        facingDir = 1,
        
        -- Dash state
        isDashing = false,
        dashTime = 0,
        dashDuration = data.DashDuration,
        dashSpeed = data.DashSpeed,
        dashDX = 0,
        dashDY = 0,
        invulnerable = false,
        
        -- Animation state (for Logic to track)
        animState = "idle",
        
        -- Weapon reference (set by WeaponLogic)
        weapon = nil,
        
        -- Object ID for engine integration
        ObjectId = nil,
    }
    
    -- Store in global state
    State.CurrentRun.Hero = player
    
    return player
end

--- Start dash
-- @param player Player table
-- @param dx Dash direction X
-- @param dy Dash direction Y
function PlayerLogic.startDash(player, dx, dy)
    if player.isDashing then return false end
    
    player.isDashing = true
    player.dashTime = player.dashDuration
    player.dashDX = dx
    player.dashDY = dy
    player.invulnerable = true
    
    -- Update facing
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then
        player.facing.x = dx / len
        player.facing.y = dy / len
    end
    
    -- Fire event
    Events.notify("OnPlayerDash", {
        player = player,
        directionX = dx,
        directionY = dy,
    })
    
    return true
end

--- Update player logic
-- @param player Player table
-- @param dt Delta time
-- @param room Room for collision
-- @return Movement direction for presentation
function PlayerLogic.update(player, dt, room)
    -- Dash update
    if player.isDashing then
        return PlayerLogic.updateDash(player, dt, room)
    end
    
    -- Normal movement
    return PlayerLogic.updateMovement(player, dt, room)
end

--- Update dash state
function PlayerLogic.updateDash(player, dt, room)
    local step = 0.05
    local remaining = player.dashSpeed * dt
    
    while remaining > 0 do
        local s = math.min(step, remaining)
        
        local nx = player.x + player.dashDX * s
        local ny = player.y + player.dashDY * s
        
        if room:isWalkable(nx, player.y) then
            player.x = nx
        else
            break
        end
        
        if room:isWalkable(player.x, ny) then
            player.y = ny
        else
            break
        end
        
        remaining = remaining - s
    end
    
    player.dashTime = player.dashTime - dt
    if player.dashTime <= 0 then
        player.isDashing = false
        player.invulnerable = false
    end
    
    player.animState = "run"
    return { x = player.dashDX, y = player.dashDY, dashing = true }
end

--- Update normal movement
function PlayerLogic.updateMovement(player, dt, room)
    -- Get input (WASD in isometric)
    local dx, dy = 0, 0
    if love.keyboard.isDown("w") then dx = dx - 1; dy = dy - 1 end
    if love.keyboard.isDown("s") then dx = dx + 1; dy = dy + 1 end
    if love.keyboard.isDown("a") then dx = dx - 1; dy = dy + 1 end
    if love.keyboard.isDown("d") then dx = dx + 1; dy = dy - 1 end
    
    local len = math.sqrt(dx * dx + dy * dy)
    local hasMovement = len > 0
    
    if hasMovement then
        dx, dy = dx / len, dy / len
        player.facing.x = dx
        player.facing.y = dy
        
        -- Apply movement
        local speed = player.speed * dt
        local tryX = player.x + dx * speed
        local tryY = player.y + dy * speed
        
        if room:isWalkable(tryX, player.y) then
            player.x = tryX
        end
        if room:isWalkable(player.x, tryY) then
            player.y = tryY
        end
        
        player.animState = "walk"
        
        -- Fire move event
        Events.notify("OnPlayerMove", {
            player = player,
            x = player.x,
            y = player.y,
        })
    else
        player.animState = "idle"
    end
    
    return { x = dx, y = dy, moving = hasMovement }
end

--- Update aim direction from mouse
function PlayerLogic.updateAim(player, mouseWorldX, mouseWorldY)
    local dx = mouseWorldX - player.x
    local dy = mouseWorldY - player.y
    
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0.0001 then
        player.aim.x = dx / len
        player.aim.y = dy / len
    end
    player.facingDir = player.aim.x >= 0 and 1 or -1
end

--- Take damage
-- @param player Player table
-- @param amount Damage amount
-- @param source Damage source
function PlayerLogic.takeDamage(player, amount, source)
    if player.invulnerable then return false end
    
    player.health = player.health - amount
    State.recordDamageTaken(amount)
    
    Events.notify("OnDamage", {
        victim = player,
        attacker = source,
        amount = amount,
        isPlayer = true,
    })
    
    if player.health <= 0 then
        PlayerLogic.die(player, source)
    end
    
    return true
end

--- Player death
function PlayerLogic.die(player, source)
    Events.notify("OnDeath", {
        unit = player,
        killer = source,
        isPlayer = true,
    })
    
    State.GameState.TotalDeaths = State.GameState.TotalDeaths + 1
end

--- Check if player is attacking
function PlayerLogic.isAttacking(player)
    return player.weapon and player.weapon.anim and player.weapon.anim.type ~= nil
end

return PlayerLogic
