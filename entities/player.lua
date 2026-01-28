local Mace = require("weapons.mace")
local Iso = require("core.iso")


local Player = {}
Player.__index = Player

-- 16 directions with 22.5 degree steps
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

-- Resolution to use (x256p seems like a good middle ground)
local SPRITE_RESOLUTION = "x256p_Spritesheets"

-- Spritesheet grid layouts for each animation type (columns x rows)
local ANIM_GRID_LAYOUTS = {
    Idle = { cols = 4, rows = 4 },           -- 4x4 = 16 frames
    Walk = { cols = 5, rows = 4 },           -- 5x4 = 20 frames
    Run = { cols = 4, rows = 4 },            -- 4x4 = 16 frames (used for dash)
    Attack_Swipe = { cols = 5, rows = 4 },   -- 5x4 = 20 frames (left-click)
    Attack_Jump = { cols = 6, rows = 4 },    -- 6x4 = 24 frames (right-click)
}

function Player:loadSprites()
    self.sprites = {}
    self.spritesheets = {}

    -- Load spritesheets for each animation type
    local animTypes = { "Idle", "Walk", "Run", "Attack_Swipe", "Attack_Jump" }

    for _, animType in ipairs(animTypes) do
        self.sprites[animType] = {}
        self.spritesheets[animType] = {}

        -- Get grid layout for this animation type
        local layout = ANIM_GRID_LAYOUTS[animType] or { cols = 4, rows = 4 }
        local framesPerRow = layout.cols
        local framesPerCol = layout.rows

        for _, angle in ipairs(SPRITE_ANGLES) do
            local suffix = ANGLE_TO_SUFFIX[angle]
            local path = string.format("assets/sprites/player/%s/%s/%s_Body_%s.png",
                SPRITE_RESOLUTION, animType, animType, suffix)

            -- Load spritesheet image
            local success, spritesheet = pcall(love.graphics.newImage, path)
            if success then
                spritesheet:setFilter("nearest", "nearest")
                self.spritesheets[animType][angle] = spritesheet

                local sheetW = spritesheet:getWidth()
                local sheetH = spritesheet:getHeight()
                local frameW = sheetW / framesPerRow
                local frameH = sheetH / framesPerCol

                self.sprites[animType][angle] = {}
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
                        self.sprites[animType][angle][frameIndex] = quad
                    end
                end
            else
                print("Warning: Could not load spritesheet:", path)
            end
        end
    end

    -- Debug: print loaded spritesheet counts
    for animType, sheets in pairs(self.spritesheets) do
        local count = 0
        for _ in pairs(sheets) do count = count + 1 end
        print(string.format("Loaded %d spritesheets for %s", count, animType))
    end
end

function Player:getDirectionAngle(dx, dy)
    -- For isometric movement controls:
    -- S (bottom corner) = world (+1, +1) → sprite 0° (facing camera)
    -- A (left corner) = world (-1, +1) → sprite 90° 
    -- W (top corner) = world (-1, -1) → sprite 180° (facing away)
    -- D (right corner) = world (+1, -1) → sprite 270°
    
    -- +135° offset (45° base + 90° rotation fix)
    local angle = math.deg(math.atan2(dy, dx))
    angle = angle + 135
    
    -- Normalize to 0-360
    if angle < 0 then angle = angle + 360 end
    if angle >= 360 then angle = angle - 360 end
    
    return angle
end

function Player:getClosestSpriteAngle(targetAngle)
    -- Find closest sprite angle
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

function Player.new(x, y)
    local self = setmetatable({}, Player)

    -- Load directional sprites
    self:loadSprites()

    -- scale (tweak later)
    self.spriteScale = 1.2

    -- animation definitions (frames per animation)
    -- Frame counts match the grid layouts defined in ANIM_GRID_LAYOUTS
    -- Speed is time per frame in seconds (higher = slower animation)
    self.anims       = {
        idle = {
            frames = 16,   -- 4x4 = 16 frames
            speed = 0.2,   -- 0.2s per frame = 3.2s total cycle
            loop = true    -- Continuously loop
        },
        walk = {
            frames = 20,   -- 5x4 = 20 frames
            speed = 0.08,  -- 0.08s per frame = 1.6s total cycle
            loop = true    -- Continuously loop
        },
        run = {
            frames = 16,   -- 4x4 = 16 frames (used for dash)
            speed = 0.06,  -- 0.06s per frame = 0.96s total cycle
            loop = true    -- Continuously loop
        },
        attack_swipe = {
            frames = 20,   -- 5x4 = 20 frames (Attack_Swipe)
            speed = 0.1,   -- 0.1s per frame = 2s total (slow sweep)
            loop = false   -- Play once, then return to idle
        },
        attack_jump = {
            frames = 24,   -- 6x4 = 24 frames (Attack_Jump)
            speed = 0.1,   -- 0.1s per frame = 2.4s total (slow jump)
            loop = false   -- Play once, then return to idle
        }
    }

    self.anim        = {
        name = "idle",
        frame = 1,      -- current frame index (1-16)
        timer = 0,
        playing = true  -- whether animation is currently playing
    }


    self.aim = { x = 1, y = 0 }

    self.x = x
    self.y = y
    self.speed = 3
    self.size = 15

    -- direction
    self.facing = { x = 1, y = 0 } -- movement / aim vector
    self.facingDir = 1             -- sprite flip: 1 = right, -1 = left
    self.lastSpriteAngle = nil     -- track last sprite angle for direction change detection

    -- dash
    self.isDashing = false
    self.dashTime = 0
    self.dashDuration = 0.15
    self.dashSpeed = 10
    self.dashDX = 0
    self.dashDY = 0
    self.invulnerable = false

    -- weapon
    self.weapon = Mace:new(self)

    return self
end

function Player:setAnim(name)
    if self.anim.name ~= name then
        self.anim.name = name
        self.anim.frame = 1
        self.anim.timer = 0
        self.anim.playing = true
    end
end

function Player:setDirection(newAngle)
    -- Just track the sprite angle, don't reset animation
    -- Resetting animation on direction change causes sliding effect
    self.lastSpriteAngle = newAngle
end

function Player:updateAim(camera, tileW, tileH)
    local mx, my = love.mouse.getPosition()

    -- convert mouse screen → camera space
    local cx = mx - camera.x
    local cy = my - camera.y

    -- convert camera space → world (iso)
    local wx, wy = Iso.screenToWorld(cx, cy, tileW, tileH)

    local dx = wx - self.x
    local dy = wy - self.y

    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0.0001 then
        self.aim.x = dx / len
        self.aim.y = dy / len
    end
    self.facingDir = self.aim.x >= 0 and 1 or -1
end

-- INPUT (called from main)
function Player:startDash(dx, dy)
    self.isDashing = true
    self.dashTime = self.dashDuration
    self.dashDX = dx
    self.dashDY = dy

    -- Update facing direction for dash
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then
        self.facing.x = dx / len
        self.facing.y = dy / len
    end

    self.invulnerable = true
end

function Player:update(dt, room, sounds, Audio)
    -- DASH LOGIC
    self.weapon:update(dt, sounds, Audio)

    -- Update animation frame (only advance when enough time has passed)
    local a = self.anims[self.anim.name]
    if a and self.anim.playing then
        self.anim.timer = self.anim.timer + dt
        -- Only advance frame when timer exceeds speed threshold
        while self.anim.timer >= a.speed do
            self.anim.timer = self.anim.timer - a.speed
            self.anim.frame = self.anim.frame + 1
            
            -- Handle frame wrapping based on loop setting
            if self.anim.frame > a.frames then
                if a.loop then
                    self.anim.frame = 1  -- Loop back to start
                else
                    -- Non-looping animation finished, return to idle
                    self.anim.frame = a.frames  -- Stay on last frame
                    self.anim.playing = false
                    if self.anim.name == "attack_swipe" or self.anim.name == "attack_jump" then
                        self:setAnim("idle")
                    end
                end
            end
        end
    end

    -- Check movement input for animation state
    -- Movement is in isometric screen-space:
    -- W = top corner (world: -X, -Y), S = bottom corner (world: +X, +Y)
    -- A = left corner (world: -X, +Y), D = right corner (world: +X, -Y)
    local dx, dy = 0, 0
    if love.keyboard.isDown("w") then 
        dx = dx - 1  -- move toward top corner
        dy = dy - 1
    end
    if love.keyboard.isDown("s") then 
        dx = dx + 1  -- move toward bottom corner
        dy = dy + 1
    end
    if love.keyboard.isDown("a") then 
        dx = dx - 1  -- move toward left corner
        dy = dy + 1
    end
    if love.keyboard.isDown("d") then 
        dx = dx + 1  -- move toward right corner
        dy = dy - 1
    end
    local len = math.sqrt(dx * dx + dy * dy)
    local hasMovement = len > 0

    -- Determine animation state
    if self.weapon.anim.type then
        -- Attack animation based on weapon anim type
        local attackAnim = "attack_swipe"
        if self.weapon.anim.type == "slam" then
            attackAnim = "attack_jump"
        end
        -- Only set if not already playing the correct attack animation
        if self.anim.name ~= attackAnim or not self.anim.playing then
            self:setAnim(attackAnim)
        end
    elseif self.isDashing then
        -- Dash/Run animation
        self:setAnim("run")
    elseif hasMovement then
        -- Walk animation
        self:setAnim("walk")
    else
        -- Idle animation
        self:setAnim("idle")
    end

    if self.isDashing then
        local step = 0.05
        local remaining = self.dashSpeed * dt

        while remaining > 0 do
            local s = math.min(step, remaining)

            local nx = self.x + self.dashDX * s
            local ny = self.y + self.dashDY * s

            if room:isWalkable(nx, self.y) then
                self.x = nx
            else
                break
            end

            if room:isWalkable(self.x, ny) then
                self.y = ny
            else
                break
            end

            remaining = remaining - s
        end

        self.dashTime = self.dashTime - dt
        if self.dashTime <= 0 then
            self.isDashing = false
            self.invulnerable = false
        end

        return -- skip normal movement
    end

    -- NORMAL MOVEMENT (skip if attacking)
    if self.weapon.anim.type then
        return  -- stop movement during attack animations
    end

    if hasMovement then
        dx, dy = dx / len, dy / len
        self.facing.x = dx
        self.facing.y = dy
    end

    local speed = self.speed * dt
    local tryX = self.x + dx * speed
    local tryY = self.y + dy * speed

    if room:isWalkable(tryX, self.y) then
        self.x = tryX
    end
    if room:isWalkable(self.x, tryY) then
        self.y = tryY
    end
end

function Player:drawWeapon(sx, sy)
    local anim = self.weapon.anim
    if not anim or not anim.type then return end

    local t = 1 - (anim.timer / anim.duration)

    local aim = self.aim
    local baseAngle = math.atan2(aim.y, aim.x)

    local angle = baseAngle
    local length = 100

    if anim.type == "sweep" then
        local sweepArc = math.pi * 0.8
        angle = baseAngle - sweepArc / 2 + t * sweepArc
    elseif anim.type == "slam" then
        length = 100 + t * 14
    end

    love.graphics.push()
    love.graphics.translate(sx, sy)
    love.graphics.rotate(angle)

    -- handle
    love.graphics.setColor(0.45, 0.3, 0.2)
    love.graphics.rectangle("fill", 0, -2, length, 4)

    -- head
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.rectangle("fill", length - 4, -6, 8, 12)

    love.graphics.pop()
end

function Player:draw(iso, camera)
    local sx, sy = iso(self.x, self.y)

    -- apply camera
    sx = sx + camera.x
    sy = sy + camera.y

    -- Determine which sprite set to use
    local spriteSet = "Idle"
    if self.anim.name == "walk" then
        spriteSet = "Walk"
    elseif self.anim.name == "run" then
        spriteSet = "Run"
    elseif self.anim.name == "attack_swipe" then
        spriteSet = "Attack_Swipe"
    elseif self.anim.name == "attack_jump" then
        spriteSet = "Attack_Jump"
    end

    -- Get direction angle:
    -- - attacks: use aim direction (towards mouse for attack targeting)
    -- - all other states: use movement direction (facing)
    local dirX, dirY = self.facing.x, self.facing.y
    if self.anim.name == "attack_swipe" or self.anim.name == "attack_jump" then
        dirX, dirY = self.aim.x, self.aim.y
    end

    -- Ensure direction is normalized
    local dirLen = math.sqrt(dirX * dirX + dirY * dirY)
    if dirLen > 0.001 then
        dirX, dirY = dirX / dirLen, dirY / dirLen
    else
        -- Default to right if no direction
        dirX, dirY = 1, 0
    end

    local targetAngle = self:getDirectionAngle(dirX, dirY)
    local spriteAngle = self:getClosestSpriteAngle(targetAngle)

    -- Reset animation if direction changed significantly
    self:setDirection(spriteAngle)

    -- Get the spritesheet and quad for this direction and frame
    local spritesheet = nil
    local quad = nil

    if self.spritesheets[spriteSet] and self.spritesheets[spriteSet][spriteAngle] then
        spritesheet = self.spritesheets[spriteSet][spriteAngle]
        if self.sprites[spriteSet] and self.sprites[spriteSet][spriteAngle] then
            local a = self.anims[self.anim.name]
            local maxFrames = a and a.frames or 16
            local frameIndex = math.max(1, math.min(self.anim.frame, maxFrames))
            quad = self.sprites[spriteSet][spriteAngle][frameIndex]
        end
    end

    -- Fallback to Idle if sprite not found
    if not spritesheet and self.spritesheets["Idle"] then
        local fallbackAngle = spriteAngle or SPRITE_ANGLES[1]
        spritesheet = self.spritesheets["Idle"][fallbackAngle]
        if self.sprites["Idle"] and self.sprites["Idle"][fallbackAngle] then
            local a = self.anims[self.anim.name]
            local maxFrames = a and a.frames or 16
            local frameIndex = math.max(1, math.min(self.anim.frame, maxFrames))
            quad = self.sprites["Idle"][fallbackAngle][frameIndex]
        end
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
        love.graphics.setColor(1, 0, 0)
        love.graphics.circle("fill", sx, sy, 10)
        love.graphics.setColor(1, 1, 1)
    end
end

function Player:usePrimary(enemies)
    return self.weapon:primary(enemies)
end

function Player:useSecondary(enemies)
    return self.weapon:secondary(enemies)
end

return Player
