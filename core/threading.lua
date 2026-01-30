--[[
    Threading System
    Custom coroutine-based threading for async game operations.
    Based on Hades 2 architecture patterns.
]]

local Threading = {}

-- Internal state
local _threads = {}
local _workingThreads = {}
local _eventListeners = {}
local _events = {}
local _eventTimeoutRecord = {}
local _worldTime = 0
local _worldTimeUnmodified = 0

-- Thread pool for recycling coroutines
local _coroutinePool = {}
local _poolSize = 0
local MAX_POOL_SIZE = 100

-- Get or create a coroutine
local function getCoroutine()
    if _poolSize > 0 then
        local co = _coroutinePool[_poolSize]
        _coroutinePool[_poolSize] = nil
        _poolSize = _poolSize - 1
        return co
    end
    return coroutine.create(function(func, ...)
        while true do
            func(...)
            func = coroutine.yield()
        end
    end)
end

-- Return coroutine to pool
local function recycleCoroutine(co)
    if _poolSize < MAX_POOL_SIZE then
        _poolSize = _poolSize + 1
        _coroutinePool[_poolSize] = co
    end
end

-- Resume a coroutine and handle its return value
local function resume(co, threadTable, func, ...)
    local status, result = coroutine.resume(co, func, ...)
    
    if not status then
        print("[Threading] Error: " .. tostring(result))
        return
    end
    
    if result then
        -- Thread yielded with wait info
        local threadInfo = {
            thread = co,
            resumeTime = _worldTime + (result.wait or 0),
            tag = result.tag,
            event = result.event,
            persist = result.Persist,
            unmodifiedTime = result.unmodifiedTime,
        }
        
        if result.event then
            -- Register event listener
            _eventListeners[result.event] = _eventListeners[result.event] or {}
            table.insert(_eventListeners[result.event], threadInfo)
        else
            table.insert(threadTable, threadInfo)
        end
    else
        -- Thread completed
        recycleCoroutine(co)
    end
end

--- Create a new thread
-- @param func Function to run in thread
-- @param ... Arguments to pass to function
function Threading.thread(func, ...)
    local co = getCoroutine()
    resume(co, _threads, func, ...)
end

--- Wait for duration (seconds)
-- @param duration Time to wait in seconds
-- @param tag Optional tag for thread management
-- @param persist Keep thread across map loads
function Threading.wait(duration, tag, persist)
    if duration == nil or duration <= 0 then return end
    coroutine.yield({
        wait = duration,
        tag = tag or "Untagged",
        Persist = persist
    })
end

--- Wait until event fires
-- @param event Event name to wait for
-- @param tag Optional tag for thread management
-- @param persist Keep thread across map loads
function Threading.waitUntil(event, tag, persist)
    -- Check if event already fired
    if _events[event] ~= nil then
        _events[event] = nil
        return
    end
    coroutine.yield({
        wait = -1,
        event = event,
        tag = tag,
        Persist = persist
    })
end

--- Wait until any of the specified events fires
-- @param events Table of event names
-- @param tag Optional tag
-- @return The event that fired
function Threading.waitForAny(events, tag)
    -- Check if any event already fired
    for _, event in ipairs(events) do
        if _events[event] then
            _events[event] = nil
            return event
        end
    end
    
    -- Register for all events
    local currentCo = coroutine.running()
    for _, event in ipairs(events) do
        _eventListeners[event] = _eventListeners[event] or {}
        table.insert(_eventListeners[event], {
            thread = currentCo,
            tag = tag,
            multiEvent = events,
        })
    end
    
    coroutine.yield({ wait = -1 })
end

--- Notify an event (trigger waiting threads)
-- @param event Event name
-- @param wasTimeout Whether this was a timeout
function Threading.notify(event, wasTimeout)
    _eventTimeoutRecord[event] = wasTimeout
    local eventListeners = _eventListeners[event]
    
    if eventListeners then
        _eventListeners[event] = nil
        for _, listener in ipairs(eventListeners) do
            resume(listener.thread, _workingThreads)
        end
    else
        -- Store for future waiters
        _events[event] = true
    end
end

--- Kill all threads with a specific tag
-- @param tag Tag to match
function Threading.killTaggedThreads(tag)
    -- Remove from active threads
    for i = #_threads, 1, -1 do
        if _threads[i].tag == tag then
            table.remove(_threads, i)
        end
    end
    
    -- Remove from working threads
    for i = #_workingThreads, 1, -1 do
        if _workingThreads[i].tag == tag then
            table.remove(_workingThreads, i)
        end
    end
    
    -- Remove from event listeners
    for event, listeners in pairs(_eventListeners) do
        for i = #listeners, 1, -1 do
            if listeners[i].tag == tag then
                table.remove(listeners, i)
            end
        end
    end
end

--- Kill all non-persistent threads (for map transitions)
function Threading.killNonPersistentThreads()
    for i = #_threads, 1, -1 do
        if not _threads[i].persist then
            table.remove(_threads, i)
        end
    end
end

--- Update threading system (call from main loop)
-- @param time World time
-- @param unmodifiedTime Unmodified time (ignores pause/slow-mo)
function Threading.update(time, unmodifiedTime)
    _worldTime = time
    _worldTimeUnmodified = unmodifiedTime or time
    
    -- Process threads
    for _, threadInfo in ipairs(_threads) do
        local checkTime = threadInfo.unmodifiedTime and _worldTimeUnmodified or _worldTime
        
        if threadInfo.resumeTime <= checkTime then
            resume(threadInfo.thread, _workingThreads)
        else
            table.insert(_workingThreads, threadInfo)
        end
    end
    
    -- Swap thread tables
    _threads, _workingThreads = _workingThreads, _threads
    for i = #_workingThreads, 1, -1 do
        _workingThreads[i] = nil
    end
end

--- Get current world time
function Threading.getTime()
    return _worldTime
end

--- Check if event timed out
function Threading.didEventTimeout(event)
    return _eventTimeoutRecord[event]
end

--- Clear all threads (for reset)
function Threading.clear()
    _threads = {}
    _workingThreads = {}
    _eventListeners = {}
    _events = {}
    _eventTimeoutRecord = {}
end

return Threading
