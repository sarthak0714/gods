--[[
    Enemy Presentation
    Visual rendering, sprites, animations for enemies.
    Based on Hades 2 architecture patterns.
]]

local EnemyData = require("data.EnemyData")

local EnemyPresentation = {}

-- Sprite cache (shared across all enemies)
local loadedSprites = nil
local loadedSpritesheets = nil

--- Load all enemy sprites
function EnemyPresentation.loadSprites()
    if loadedSprites then
        return loadedSprites, loadedSpritesheets
    end
    
    loadedSprites = {}
    loadedSpritesheets = {}
    
    local data = EnemyData.BaseEnemy
    local resolution = data.SpriteResolution
    local pathPattern = data.SpritePathPattern
    
    local animTypes = { "Idle", "Hit", "Death" }
    
    for _, animType in ipairs(animTypes) do
        loadedSprites[animType] = {}
        loadedSpritesheets[animType] = {}
        
        local layout = data.AnimationGrids[animType]
        local framesPerRow = layout.cols
        local framesPerCol = layout.rows
        
        for _, angle in ipairs(EnemyData.SPRITE_ANGLES) do
            local suffix = EnemyData.ANGLE_TO_SUFFIX[angle]
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

--- Get direction angle
function EnemyPresentation.getDirectionAngle(dx, dy)
    local angle = math.deg(math.atan2(dy, dx))
    angle = angle + 135
    if angle < 0 then angle = angle + 360 end
    if angle >= 360 then angle = angle - 360 end
    return angle
end

--- Get closest sprite angle
function EnemyPresentation.getClosestSpriteAngle(targetAngle)
    local closestAngle = EnemyData.SPRITE_ANGLES[1]
    local minDiff = math.abs(targetAngle - closestAngle)
    
    for _, angle in ipairs(EnemyData.SPRITE_ANGLES) do
        local diff = math.abs(targetAngle - angle)
        if diff > 180 then diff = 360 - diff end
        if diff < minDiff then
            minDiff = diff
            closestAngle = angle
        end
    end
    
    return closestAngle
end

--- Create enemy presentation state
function EnemyPresentation.new()
    EnemyPresentation.loadSprites()
    
    return {
        anim = {
            name = "idle",
            frame = 1,
            timer = 0,
            playing = true,
        },
        spriteScale = EnemyData.BaseEnemy.SpriteScale,
    }
end

--- Update animation
function EnemyPresentation.update(pres, enemy, dt)
    local data = EnemyData.BaseEnemy
    
    -- Sync animation from logic state
    if enemy.animState ~= pres.anim.name then
        EnemyPresentation.setAnim(pres, enemy.animState)
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
                    
                    if animData.returnTo and not enemy.dead then
                        EnemyPresentation.setAnim(pres, animData.returnTo)
                        enemy.animState = animData.returnTo
                    elseif pres.anim.name == "death" then
                        -- Mark death complete in logic
                        local EnemyLogic = require("logic.EnemyLogic")
                        EnemyLogic.markDeathComplete(enemy)
                    end
                end
            end
        end
    end
end

--- Set animation
function EnemyPresentation.setAnim(pres, name)
    if pres.anim.name ~= name then
        pres.anim.name = name
        pres.anim.frame = 1
        pres.anim.timer = 0
        pres.anim.playing = true
    end
end

--- Draw enemy
function EnemyPresentation.draw(pres, enemy, screenX, screenY)
    if enemy.deathAnimComplete then return end
    
    if not loadedSpritesheets then
        EnemyPresentation.loadSprites()
    end
    
    local data = EnemyData.BaseEnemy
    local animData = data.Animations[pres.anim.name]
    if not animData then return end
    
    local spriteSet = animData.spriteSet
    
    -- Get direction angle
    local targetAngle = EnemyPresentation.getDirectionAngle(enemy.facingX, enemy.facingY)
    local spriteAngle = EnemyPresentation.getClosestSpriteAngle(targetAngle)
    
    local spritesheet = loadedSpritesheets[spriteSet] and loadedSpritesheets[spriteSet][spriteAngle]
    local quad = loadedSprites[spriteSet] and loadedSprites[spriteSet][spriteAngle]
    
    if quad then
        local frameIndex = math.max(1, math.min(pres.anim.frame, animData.frames))
        quad = quad[frameIndex]
    end
    
    -- Fallback
    if not spritesheet then
        spritesheet = loadedSpritesheets["Idle"] and loadedSpritesheets["Idle"][spriteAngle]
        quad = loadedSprites["Idle"] and loadedSprites["Idle"][spriteAngle] and loadedSprites["Idle"][spriteAngle][1]
    end
    
    -- Hit flash tint
    if enemy.isHit then
        love.graphics.setColor(1, 0.5, 0.5, 1)
    else
        love.graphics.setColor(1, 1, 1, 1)
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
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.circle("fill", screenX, screenY, enemy.size)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

return EnemyPresentation
