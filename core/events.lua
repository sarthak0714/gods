--[[
    Event System
    Decoupled event-driven communication between game systems.
    Based on Hades 2 architecture patterns.
]]

local Events = {}

-- Internal state
local _eventHandlers = {}
local _onceHandlers = {}

--- Register an event handler
-- @param eventName Name of the event
-- @param handler Function to call when event fires
-- @param priority Optional priority (lower = called first)
-- @return Handler ID for removal
function Events.on(eventName, handler, priority)
    _eventHandlers[eventName] = _eventHandlers[eventName] or {}
    
    local handlerInfo = {
        func = handler,
        priority = priority or 0,
        id = tostring(handler),
    }
    
    table.insert(_eventHandlers[eventName], handlerInfo)
    
    -- Sort by priority
    table.sort(_eventHandlers[eventName], function(a, b)
        return a.priority < b.priority
    end)
    
    return handlerInfo.id
end

--- Register a one-time event handler (auto-removes after firing)
-- @param eventName Name of the event
-- @param handler Function to call
function Events.once(eventName, handler)
    _onceHandlers[eventName] = _onceHandlers[eventName] or {}
    table.insert(_onceHandlers[eventName], handler)
end

--- Remove an event handler
-- @param eventName Name of the event
-- @param handlerId Handler ID returned from on()
function Events.off(eventName, handlerId)
    local handlers = _eventHandlers[eventName]
    if not handlers then return end
    
    for i = #handlers, 1, -1 do
        if handlers[i].id == handlerId then
            table.remove(handlers, i)
            return true
        end
    end
    return false
end

--- Notify/trigger an event
-- @param eventName Name of the event
-- @param args Arguments to pass to handlers
function Events.notify(eventName, args)
    args = args or {}
    
    -- Call regular handlers
    local handlers = _eventHandlers[eventName]
    if handlers then
        for _, handlerInfo in ipairs(handlers) do
            local success, err = pcall(handlerInfo.func, args)
            if not success then
                print(string.format("[Events] Error in handler for '%s': %s", eventName, err))
            end
        end
    end
    
    -- Call and remove one-time handlers
    local onceHandlers = _onceHandlers[eventName]
    if onceHandlers then
        _onceHandlers[eventName] = nil
        for _, handler in ipairs(onceHandlers) do
            local success, err = pcall(handler, args)
            if not success then
                print(string.format("[Events] Error in once-handler for '%s': %s", eventName, err))
            end
        end
    end
end

--- Clear all handlers for an event
-- @param eventName Name of the event (nil = clear all)
function Events.clear(eventName)
    if eventName then
        _eventHandlers[eventName] = nil
        _onceHandlers[eventName] = nil
    else
        _eventHandlers = {}
        _onceHandlers = {}
    end
end

--- Check if event has handlers
-- @param eventName Name of the event
function Events.hasHandlers(eventName)
    return (_eventHandlers[eventName] and #_eventHandlers[eventName] > 0)
        or (_onceHandlers[eventName] and #_onceHandlers[eventName] > 0)
end

-- =====================
-- Convenience Functions
-- =====================

-- Pre-defined event registration helpers (Hades style)
function Events.OnWeaponFired(handler)
    return Events.on("OnWeaponFired", handler)
end

function Events.OnDamage(handler)
    return Events.on("OnDamage", handler)
end

function Events.OnDeath(handler)
    return Events.on("OnDeath", handler)
end

function Events.OnPlayerDash(handler)
    return Events.on("OnPlayerDash", handler)
end

function Events.OnPlayerMove(handler)
    return Events.on("OnPlayerMove", handler)
end

function Events.OnEnemySpawned(handler)
    return Events.on("OnEnemySpawned", handler)
end

function Events.OnRoomCleared(handler)
    return Events.on("OnRoomCleared", handler)
end

function Events.OnMapLoad(handler)
    return Events.on("OnMapLoad", handler)
end

return Events
