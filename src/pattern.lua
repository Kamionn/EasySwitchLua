local Pattern = {}

local TAG = "__easyswitch_pattern"

local function freeze(t)
    return setmetatable({}, {
        __index = t,
        __newindex = function() error("Pattern is readonly", 2) end,
        __pairs = function() return pairs(t) end,
        __len = function() return #t end,
        __metatable = false
    })
end

local function tagged(kind, data)
    data = data or {}
    data[TAG] = kind
    return data
end

local function frozenTagged(kind, data)
    return freeze(tagged(kind, data))
end

local function isInteger(value)
    return type(value) == "number" and value % 1 == 0
end

local function isArrayTable(value)
    if type(value) ~= "table" then
        return false
    end

    local count = 0
    for _ in pairs(value) do
        count = count + 1
    end

    for i = 1, count do
        if value[i] == nil then
            return false
        end
    end

    return true
end

function Pattern.isTagged(value)
    return type(value) == "table" and value[TAG] ~= nil
end

function Pattern.isCaseList(value)
    return isArrayTable(value)
end

local matchesImpl

local function matchTagged(pattern, value, visited)
    local kind = pattern[TAG]

    if kind == "type" then
        local name = pattern.name
        if name == "integer" then
            return isInteger(value)
        end
        if name == "float" then
            return type(value) == "number" and not isInteger(value)
        end
        return type(value) == name
    end

    if kind == "predicate" then
        return not not pattern.fn(value)
    end

    if kind == "any_of" then
        for i = 1, #pattern.patterns do
            if matchesImpl(pattern.patterns[i], value, visited) then
                return true
            end
        end
        return false
    end

    if kind == "not" then
        return not matchesImpl(pattern.pattern, value, visited)
    end

    if kind == "array" then
        if not isArrayTable(value) then
            return false
        end

        for i = 1, #value do
            if not matchesImpl(pattern.item, value[i], visited) then
                return false
            end
        end
        return true
    end

    error("Unknown pattern kind: " .. tostring(kind), 2)
end

matchesImpl = function(pattern, value, visited)
    if Pattern.isTagged(pattern) then
        return matchTagged(pattern, value, visited)
    end

    if type(pattern) == "table" then
        if type(value) ~= "table" then
            return false
        end

        if visited[pattern] then
            return true
        end
        visited[pattern] = true

        for key, expected in pairs(pattern) do
            if not matchesImpl(expected, value[key], visited) then
                return false
            end
        end
        return true
    end

    return pattern == value
end

function Pattern.matches(pattern, value)
    return matchesImpl(pattern, value, {})
end

Pattern.string = frozenTagged("type", { name = "string" })
Pattern.number = frozenTagged("type", { name = "number" })
Pattern.boolean = frozenTagged("type", { name = "boolean" })
Pattern.integer = frozenTagged("type", { name = "integer" })
Pattern.float = frozenTagged("type", { name = "float" })

function Pattern.when(fn)
    if type(fn) ~= "function" then
        error("Pattern predicate must be a function", 2)
    end
    return frozenTagged("predicate", { fn = fn })
end

function Pattern.any_of(...)
    local patterns = { ... }
    if #patterns == 0 then
        error("P.any_of requires at least one pattern", 2)
    end
    return frozenTagged("any_of", { patterns = patterns })
end

function Pattern.not_(pattern)
    if pattern == nil then
        error("P.not_ requires a pattern", 2)
    end
    return frozenTagged("not", { pattern = pattern })
end

function Pattern.array(item)
    if item == nil then
        error("P.array requires an item pattern", 2)
    end
    return frozenTagged("array", { item = item })
end

return Pattern
