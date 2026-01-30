--[[
    Global State Management
    Centralized state tables for game data persistence.
    Based on Hades 2 architecture patterns.
]]

local State = {}

-- =====================
-- GameState: Persistent across sessions (saved to disk)
-- =====================
State.GameState = {
    -- Audio settings
    MusicVolume = 1.0,
    SFXVolume = 1.0,
    
    -- Progress tracking
    TotalRuns = 0,
    TotalDeaths = 0,
    TotalKills = 0,
    
    -- Unlocks
    UnlockedItems = {},
    UnlockedWeapons = {},
    
    -- Records
    BestTime = nil,
    HighestDamage = 0,
}

-- =====================
-- CurrentRun: Current playthrough (reset on death/completion)
-- =====================
State.CurrentRun = {
    -- Hero reference
    Hero = nil,
    
    -- Current room/level
    CurrentRoom = nil,
    BiomeDepth = 1,
    RoomNumber = 0,
    
    -- Run stats
    RunTime = 0,
    KillsThisRun = 0,
    DamageTaken = 0,
    DamageDealt = 0,
    
    -- Active modifiers
    ActiveBoons = {},
    ActiveCurses = {},
}

-- =====================
-- SessionState: Current session only (reset on game close)
-- =====================
State.SessionState = {
    -- Session tracking
    MapLoads = 0,
    SessionStartTime = 0,
    
    -- Temporary flags
    HasSeenTutorial = false,
    DebugMode = false,
}

-- =====================
-- MapState: Current map only (reset on room transition)
-- =====================
State.MapState = {
    -- Active objects
    ActiveObstacles = {},
    ActiveEnemies = {},
    ActiveEffects = {},
    
    -- Room state
    RoomCleared = false,
    DoorsOpen = false,
    SpawnPointsUsed = {},
    
    -- Required objects (must be destroyed to clear room)
    RoomRequiredObjects = {},
}

-- =====================
-- Initialization Functions
-- =====================

--- Initialize GameState with defaults
function State.initGameState()
    State.GameState = State.GameState or {}
    State.GameState.MusicVolume = State.GameState.MusicVolume or 1.0
    State.GameState.SFXVolume = State.GameState.SFXVolume or 1.0
    State.GameState.TotalRuns = State.GameState.TotalRuns or 0
    State.GameState.UnlockedItems = State.GameState.UnlockedItems or {}
end

--- Initialize CurrentRun with defaults
function State.initCurrentRun()
    State.CurrentRun = {
        Hero = nil,
        CurrentRoom = nil,
        BiomeDepth = 1,
        RoomNumber = 0,
        RunTime = 0,
        KillsThisRun = 0,
        DamageTaken = 0,
        DamageDealt = 0,
        ActiveBoons = {},
        ActiveCurses = {},
    }
end

--- Initialize SessionState
function State.initSessionState()
    State.SessionState = {
        MapLoads = 0,
        SessionStartTime = love and love.timer.getTime() or os.time(),
        HasSeenTutorial = false,
        DebugMode = false,
    }
end

--- Initialize MapState (call on room load)
function State.initMapState()
    State.MapState = {
        ActiveObstacles = {},
        ActiveEnemies = {},
        ActiveEffects = {},
        RoomCleared = false,
        DoorsOpen = false,
        SpawnPointsUsed = {},
        RoomRequiredObjects = {},
    }
end

--- Initialize all state
function State.initAll()
    State.initGameState()
    State.initCurrentRun()
    State.initSessionState()
    State.initMapState()
end

-- =====================
-- Utility Functions
-- =====================

--- Add enemy to map state
function State.addEnemy(enemy)
    table.insert(State.MapState.ActiveEnemies, enemy)
    if enemy.Required then
        table.insert(State.MapState.RoomRequiredObjects, enemy)
    end
end

--- Remove enemy from map state
function State.removeEnemy(enemy)
    for i, e in ipairs(State.MapState.ActiveEnemies) do
        if e == enemy then
            table.remove(State.MapState.ActiveEnemies, i)
            break
        end
    end
    
    for i, e in ipairs(State.MapState.RoomRequiredObjects) do
        if e == enemy then
            table.remove(State.MapState.RoomRequiredObjects, i)
            break
        end
    end
    
    -- Check if room is cleared
    if #State.MapState.RoomRequiredObjects == 0 then
        State.MapState.RoomCleared = true
    end
end

--- Record a kill
function State.recordKill()
    State.CurrentRun.KillsThisRun = State.CurrentRun.KillsThisRun + 1
    State.GameState.TotalKills = State.GameState.TotalKills + 1
end

--- Record damage dealt
function State.recordDamageDealt(amount)
    State.CurrentRun.DamageDealt = State.CurrentRun.DamageDealt + amount
    if amount > State.GameState.HighestDamage then
        State.GameState.HighestDamage = amount
    end
end

--- Record damage taken
function State.recordDamageTaken(amount)
    State.CurrentRun.DamageTaken = State.CurrentRun.DamageTaken + amount
end

--- Serialize GameState for saving
function State.serializeGameState()
    -- Simple serialization (would need proper implementation for production)
    return State.GameState
end

--- Load GameState from saved data
function State.loadGameState(data)
    if data then
        for k, v in pairs(data) do
            State.GameState[k] = v
        end
    end
end

return State
