--[[
    Player Presentation
    Visual rendering, sprites, animations for player.
    Based on Hades 2 architecture patterns.
]]

local PlayerData = require("data.PlayerData")
local WeaponLogic = require("logic.WeaponLogic")

local PlayerPresentation = {}

-- Sprite cache
local loadedSprites = nil
local loadedSpritesheets = nil

--- Load all player sprites
function PlayerPresentation.loadSprites()
    if loadedSprites then
        return loadedSprites, loadedSpritesheets
    end
    
    loadedSprites = {}
    loadedSpritesheets = {}
    
    local data = PlayerData.Base
    local resolution = data.SpriteResolution
    local pathPattern = data.SpritePathPattern
    
    local animTypes = { "Idle", "Walk", "Run", "Attack_Swipe", "Attack_Jump" }
    
    for _, animType in ipairs(animTypes) do
        loadedSprites[animType] = {}
        loadedSpritesheets[animType] = {}
        
        local layout = data.AnimationGrids[animType] or { cols = 4, rows = 4 }
        local framesPerRow = layout.cols
        local framesPerCol = layout.rows
        
        for _, angle in ipairs(PlayerData.SPRITE_ANGLES) do
            local suffix = PlayerData.ANGLE_TO_SUFFIX[angle]
            local path = string.format(pathPattern, resolution, animType, animType, suffix)
            
            local success, spritesheet = pcall(love.graphics.newImage, path)
            if success then
                spritesheet:setFilter("nearest", "nearest")
                loadedSpritesheets[animType][angle] = spritesheet
                
                local sheetW = spritesheet:getWidth()
                local sheetH = spritesheet:getHeight()
                local frameW = sheetW / framesPerRow
                local frameH = sheetH / framesPerCol
                
                loadedSprites[animType][angle] = {}
                for row = 0, framesPerCol - 1 do
                    for col = 0, framesPerRow - 1 do
                        local frameIndex = row * framesPerRow + col + 1
                        local quad = love.graphics.newQuad(
                            col * frameW, row * frameH,
                            frameW, frameH,
                            sheetW, sheetH
                        )
                        loadedSprites[animType][angle][frameIndex] = quad
                    end
                end
            end
        end
    end
    
    return loadedSprites, loadedSpritesheets
end

--- Get direction angle from movement vector
function PlayerPresentation.getDirectionAngle(dx, dy)
    local angle = math.deg(math.atan2(dy, dx))
    angle = angle + 135
    if angle < 0 then angle = angle + 360 end
    if angle >= 360 then angle = angle - 360 end
    return angle
end

--- Get closest sprite angle
function PlayerPresentation.getClosestSpriteAngle(targetAngle)
    local closestAngle = PlayerData.SPRITE_ANGLES[1]
    local minDiff = math.abs(targetAngle - closestAngle)
    
    for _, angle in ipairs(PlayerData.SPRITE_ANGLES) do
        local diff = math.abs(targetAngle - angle)
        if diff > 180 then diff = 360 - diff end
        if diff < minDiff then
            minDiff = diff
            closestAngle = angle
        end
    end
    
    return closestAngle
end

--- Create player presentation state
function PlayerPresentation.new()
    PlayerPresentation.loadSprites()
    
    return {
        anim = {
            name = "idle",
            frame = 1,
            timer = 0,
            playing = true,
        },
        lastSpriteAngle = nil,
        spriteScale = PlayerData.Base.SpriteScale,
    }
end

--- Update animation state
-- @param pres Presentation state
-- @param player Player logic table
-- @param dt Delta time
function PlayerPresentation.update(pres, player, dt)
    local data = PlayerData.Base
    
    -- Determine animation from state
    local weaponAnim = WeaponLogic.getAnimationType(player.weapon)
    if weaponAnim then
        PlayerPresentation.setAnim(pres, weaponAnim)
    elseif player.isDashing then
        PlayerPresentation.setAnim(pres, "run")
    elseif player.animState == "walk" then
        PlayerPresentation.setAnim(pres, "walk")
    else
        PlayerPresentation.setAnim(pres, "idle")
    end
    
    -- Update animation frame
    local animData = data.Animations[pres.anim.name]
    if animData and pres.anim.playing then
        pres.anim.timer = pres.anim.timer + dt
        while pres.anim.timer >= animData.speed do
            pres.anim.timer = pres.anim.timer - animData.speed
            pres.anim.frame = pres.anim.frame + 1
            
            if pres.anim.frame > animData.frames then
                if animData.loop then
                    pres.anim.frame = 1
                else
                    pres.anim.frame = animData.frames
                    pres.anim.playing = false
                    if animData.returnTo then
                        PlayerPresentation.setAnim(pres, animData.returnTo)
                    end
                end
            end
        end
    end
end

--- Set animation
function PlayerPresentation.setAnim(pres, name)
    if pres.anim.name ~= name then
        pres.anim.name = name
        pres.anim.frame = 1
        pres.anim.timer = 0
        pres.anim.playing = true
    end
end

--- Draw player
-- @param pres Presentation state
-- @param player Player logic table
-- @param screenX Screen position X
-- @param screenY Screen position Y
function PlayerPresentation.draw(pres, player, screenX, screenY)
    if not loadedSpritesheets then
        PlayerPresentation.loadSprites()
    end
    
    local data = PlayerData.Base
    local animData = data.Animations[pres.anim.name]
    if not animData then return end
    
    local spriteSet = animData.spriteSet
    
    -- Get direction
    local dirX, dirY = player.facing.x, player.facing.y
    if pres.anim.name == "attack_swipe" or pres.anim.name == "attack_jump" then
        dirX, dirY = player.aim.x, player.aim.y
    end
    
    local dirLen = math.sqrt(dirX * dirX + dirY * dirY)
    if dirLen > 0.001 then
        dirX, dirY = dirX / dirLen, dirY / dirLen
    else
        dirX, dirY = 1, 0
    end
    
    local targetAngle = PlayerPresentation.getDirectionAngle(dirX, dirY)
    local spriteAngle = PlayerPresentation.getClosestSpriteAngle(targetAngle)
    
    local spritesheet = loadedSpritesheets[spriteSet] and loadedSpritesheets[spriteSet][spriteAngle]
    local quad = loadedSprites[spriteSet] and loadedSprites[spriteSet][spriteAngle]
    
    if quad then
        local frameIndex = math.max(1, math.min(pres.anim.frame, animData.frames))
        quad = quad[frameIndex]
    end
    
    -- Fallback to Idle
    if not spritesheet then
        spritesheet = loadedSpritesheets["Idle"] and loadedSpritesheets["Idle"][spriteAngle]
        quad = loadedSprites["Idle"] and loadedSprites["Idle"][spriteAngle] and loadedSprites["Idle"][spriteAngle][1]
    end
    
    if spritesheet and quad then
        local _, _, frameW, frameH = quad:getViewport()
        love.graphics.draw(
            spritesheet, quad,
            screenX, screenY,
            0, pres.spriteScale, pres.spriteScale,
            frameW / 2, frameH / 2
        )
    else
        -- Fallback circle
        love.graphics.setColor(1, 0, 0)
        love.graphics.circle("fill", screenX, screenY, 10)
        love.graphics.setColor(1, 1, 1)
    end
end

return PlayerPresentation
