local Iso = require("core.iso")

local Enemy = {}
Enemy.__index = Enemy

-- 16 directions with 22.5 degree steps (same as player)
local SPRITE_ANGLES = {
    0, 22.5, 45, 67.5, 90, 112.5, 135, 157.5,
    180, 202.5, 225, 247.5, 270, 292.5, 315, 337.5
}

-- Angle to sprite file suffix mapping
local ANGLE_TO_SUFFIX = {
    [0] = "000",
    [22.5] = "022",
    [45] = "045",
    [67.5] = "067",
    [90] = "090",
    [112.5] = "112",
    [135] = "135",
    [157.5] = "157",
    [180] = "180",
    [202.5] = "202",
    [225] = "225",
    [247.5] = "247",
    [270] = "270",
    [292.5] = "292",
    [315] = "315",
    [337.5] = "337"
}

-- Resolution to use
local SPRITE_RESOLUTION = "x256p_Spritesheets"

-- Spritesheet grid layouts for each animation type (columns x rows)
local ANIM_GRID_LAYOUTS = {
    Idle = { cols = 5, rows = 4 },   -- 5x4 = 20 frames
    Hit = { cols = 4, rows = 4 },    -- 4x4 = 16 frames
    Death = { cols = 6, rows = 5 },  -- 6x5 = 30 frames
}

-- Static sprite cache (shared across all enemies)
local loadedSprites = nil
local loadedSpritesheets = nil

local function loadEnemySprites()
    if loadedSprites then return loadedSprites, loadedSpritesheets end

    loadedSprites = {}
    loadedSpritesheets = {}

    local animTypes = { "Idle", "Hit", "Death" }

    for _, animType in ipairs(animTypes) do
        loadedSprites[animType] = {}
        loadedSpritesheets[animType] = {}

        -- Get grid layout for this animation type
        local layout = ANIM_GRID_LAYOUTS[animType]
        local framesPerRow = layout.cols
        local framesPerCol = layout.rows

        for _, angle in ipairs(SPRITE_ANGLES) do
            local suffix = ANGLE_TO_SUFFIX[angle]
            local path = string.format("assets/sprites/enemy/%s/%s/%s_Body_%s.png",
                SPRITE_RESOLUTION, animType, animType, suffix)

            -- Load spritesheet image
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
                            col * frameW,
                            row * frameH,
                            frameW,
                            frameH,
                            sheetW,
                            sheetH
                        )
                        loadedSprites[animType][angle][frameIndex] = quad
                    end
                end
            else
                print("Warning: Could not load enemy spritesheet:", path)
            end
        end
    end

    -- Debug: print loaded spritesheet counts
    for animType, sheets in pairs(loadedSpritesheets) do
        local count = 0
        for _ in pairs(sheets) do count = count + 1 end
        print(string.format("Enemy: Loaded %d spritesheets for %s", count, animType))
    end

    return loadedSprites, loadedSpritesheets
end

function Enemy:getDirectionAngle(dx, dy)
    -- Same calculation as player for consistency
    local angle = math.deg(math.atan2(dy, dx))
    angle = angle + 135

    -- Normalize to 0-360
    if angle < 0 then angle = angle + 360 end
    if angle >= 360 then angle = angle - 360 end

    return angle
end

function Enemy:getClosestSpriteAngle(targetAngle)
    local closestAngle = SPRITE_ANGLES[1]
    local minDiff = math.abs(targetAngle - closestAngle)

    for _, angle in ipairs(SPRITE_ANGLES) do
        local diff = math.abs(targetAngle - angle)
        -- Handle wrap-around (e.g., 350° is close to 0°)
        if diff > 180 then diff = 360 - diff end

        if diff < minDiff then
            minDiff = diff
            closestAngle = angle
        end
    end

    return closestAngle
end

function Enemy.new(x, y)
    local self = setmetatable({}, Enemy)

    -- Load sprites (shared cache)
    self.sprites, self.spritesheets = loadEnemySprites()

    -- Scale
    self.spriteScale = 1.5

    -- Animation definitions
    self.anims = {
        idle = {
            frames = 20,   -- 5x4 = 20 frames
            speed = 0.15,  -- 0.15s per frame
            loop = true
        },
        hit = {
            frames = 16,   -- 4x4 = 16 frames
            speed = 0.05,  -- 0.05s per frame = 0.8s total (quick hit reaction)
            loop = false
        },
        death = {
            frames = 30,   -- 6x5 = 30 frames
            speed = 0.08,  -- 0.08s per frame = 2.4s total
            loop = false
        }
    }

    self.anim = {
        name = "idle",
        frame = 1,
        timer = 0,
        playing = true
    }

    self.x = x
    self.y = y
    self.hp = 3
    self.size = 20  -- collision size
    self.hitRange = 1.5  -- reduced from larger values

    self.isHit = false
    self.hitFlash = 0
    self.dead = false
    self.deathAnimComplete = false

    -- Direction facing (towards player)
    self.facingX = 1
    self.facingY = 0

    return self
end

function Enemy:setAnim(name)
    if self.anim.name ~= name then
        self.anim.name = name
        self.anim.frame = 1
        self.anim.timer = 0
        self.anim.playing = true
    end
end

function Enemy:takeDamage(dmg)
    if self.dead then return end

    self.hp = self.hp - dmg
    self.isHit = true
    self.hitFlash = 0.1

    if self.hp <= 0 then
        self.dead = true
        self:setAnim("death")
    else
        self:setAnim("hit")
    end
end

function Enemy:facePlayer(playerX, playerY)
    local dx = playerX - self.x
    local dy = playerY - self.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0.001 then
        self.facingX = dx / len
        self.facingY = dy / len
    end
end

function Enemy:update(dt, player)
    -- Always face the player
    if player then
        self:facePlayer(player.x, player.y)
    end

    -- Update hit flash
    if self.isHit then
        self.hitFlash = self.hitFlash - dt
        if self.hitFlash <= 0 then
            self.isHit = false
        end
    end

    -- Update animation frame
    local a = self.anims[self.anim.name]
    if a and self.anim.playing then
        self.anim.timer = self.anim.timer + dt
        while self.anim.timer >= a.speed do
            self.anim.timer = self.anim.timer - a.speed
            self.anim.frame = self.anim.frame + 1

            if self.anim.frame > a.frames then
                if a.loop then
                    self.anim.frame = 1
                else
                    self.anim.frame = a.frames  -- Stay on last frame
                    self.anim.playing = false
                    -- Transition after non-looping animations
                    if self.anim.name == "hit" and not self.dead then
                        self:setAnim("idle")
                    elseif self.anim.name == "death" then
                        self.deathAnimComplete = true
                    end
                end
            end
        end
    end
end

function Enemy:draw(iso, camera)
    -- Don't draw if death animation is complete
    if self.deathAnimComplete then return end

    local sx, sy = iso(self.x, self.y)

    -- Apply camera
    sx = sx + camera.x
    sy = sy + camera.y

    -- Determine sprite set based on animation state
    local spriteSet = "Idle"
    if self.anim.name == "hit" then
        spriteSet = "Hit"
    elseif self.anim.name == "death" then
        spriteSet = "Death"
    end

    -- Get direction angle (facing player)
    local targetAngle = self:getDirectionAngle(self.facingX, self.facingY)
    local spriteAngle = self:getClosestSpriteAngle(targetAngle)

    -- Get the spritesheet and quad for this direction and frame
    local spritesheet = nil
    local quad = nil

    if self.spritesheets[spriteSet] and self.spritesheets[spriteSet][spriteAngle] then
        spritesheet = self.spritesheets[spriteSet][spriteAngle]
        if self.sprites[spriteSet] and self.sprites[spriteSet][spriteAngle] then
            local a = self.anims[self.anim.name]
            local maxFrames = a and a.frames or 20
            local frameIndex = math.max(1, math.min(self.anim.frame, maxFrames))
            quad = self.sprites[spriteSet][spriteAngle][frameIndex]
        end
    end

    -- Fallback to Idle if sprite not found
    if not spritesheet and self.spritesheets["Idle"] then
        local fallbackAngle = spriteAngle or SPRITE_ANGLES[1]
        spritesheet = self.spritesheets["Idle"][fallbackAngle]
        if self.sprites["Idle"] and self.sprites["Idle"][fallbackAngle] then
            quad = self.sprites["Idle"][fallbackAngle][1]
        end
    end

    -- Apply hit flash tint
    if self.isHit then
        love.graphics.setColor(1, 0.5, 0.5, 1)
    else
        love.graphics.setColor(1, 1, 1, 1)
    end

    if spritesheet and quad then
        -- Get frame dimensions from the quad
        local _, _, frameW, frameH = quad:getViewport()

        -- Draw sprite centered
        love.graphics.draw(
            spritesheet,
            quad,
            sx,
            sy,
            0,
            self.spriteScale,
            self.spriteScale,
            frameW / 2,
            frameH / 2
        )
    else
        -- Fallback: draw a simple circle if sprites aren't loaded
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.circle("fill", sx, sy, self.size)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Enemy
