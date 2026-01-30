--[[
    Deep Table Inheritance System
    Enables data definitions to use InheritFrom pattern for shared properties.
    Based on Hades 2 architecture patterns.
]]

local Inheritance = {}

--- Deep copy a table
-- @param orig Original table
-- @param copies Internal cache for circular references
-- @return Deep copy of the table
function Inheritance.deepCopy(orig, copies)
    copies = copies or {}
    local copy
    
    if type(orig) == "table" then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for k, v in next, orig, nil do
                copy[Inheritance.deepCopy(k, copies)] = Inheritance.deepCopy(v, copies)
            end
            setmetatable(copy, Inheritance.deepCopy(getmetatable(orig), copies))
        end
    else
        copy = orig
    end
    
    return copy
end

--- Shallow merge tables (later tables override earlier)
-- @param ... Tables to merge
-- @return Merged table
function Inheritance.shallowMerge(...)
    local result = {}
    for _, t in ipairs({...}) do
        if type(t) == "table" then
            for k, v in pairs(t) do
                result[k] = v
            end
        end
    end
    return result
end

--- Deep merge tables (nested tables are merged recursively)
-- @param base Base table
-- @param override Override table
-- @return Merged table
function Inheritance.deepMerge(base, override)
    local result = Inheritance.deepCopy(base)
    
    if type(override) ~= "table" then
        return result
    end
    
    for k, v in pairs(override) do
        if type(v) == "table" and type(result[k]) == "table" then
            result[k] = Inheritance.deepMerge(result[k], v)
        else
            result[k] = Inheritance.deepCopy(v)
        end
    end
    
    return result
end

--- Resolve inheritance for a data definition
-- Looks up InheritFrom and merges parent properties
-- @param data The data table to resolve
-- @param dataStore The store containing parent definitions
-- @param resolved Cache of already-resolved definitions
-- @return Resolved data with inherited properties
function Inheritance.resolve(data, dataStore, resolved)
    resolved = resolved or {}
    
    if not data then return nil end
    if not data.InheritFrom then return Inheritance.deepCopy(data) end
    
    -- Start with empty table
    local result = {}
    
    -- Apply each parent in order
    for _, parentName in ipairs(data.InheritFrom) do
        local parent = dataStore[parentName]
        if parent then
            -- Recursively resolve parent if needed
            if not resolved[parentName] then
                resolved[parentName] = Inheritance.resolve(parent, dataStore, resolved)
            end
            -- Merge parent properties
            result = Inheritance.deepMerge(result, resolved[parentName])
        else
            print(string.format("[Inheritance] Warning: Parent '%s' not found", parentName))
        end
    end
    
    -- Apply own properties (override parents)
    for k, v in pairs(data) do
        if k ~= "InheritFrom" then
            if type(v) == "table" and type(result[k]) == "table" and data.DeepInheritance then
                result[k] = Inheritance.deepMerge(result[k], v)
            else
                result[k] = Inheritance.deepCopy(v)
            end
        end
    end
    
    return result
end

--- Resolve all entries in a data store
-- @param dataStore Table of data definitions
-- @return New table with all inheritance resolved
function Inheritance.resolveAll(dataStore)
    local resolved = {}
    local result = {}
    
    for name, data in pairs(dataStore) do
        result[name] = Inheritance.resolve(data, dataStore, resolved)
    end
    
    return result
end

--- Convert array to lookup table
-- @param array Array like {"a", "b", "c"}
-- @return Lookup table like {a = true, b = true, c = true}
function Inheritance.toLookup(array)
    local lookup = {}
    for _, v in ipairs(array) do
        lookup[v] = true
    end
    return lookup
end

--- Create a sparse table without nil gaps
-- @param sparseTable Table with potential nil values
-- @return Collapsed array
function Inheritance.collapse(sparseTable)
    local result = {}
    for _, v in pairs(sparseTable) do
        if v ~= nil then
            table.insert(result, v)
        end
    end
    return result
end

--- Clear a table in-place
-- @param t Table to clear
function Inheritance.tableClear(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

return Inheritance
