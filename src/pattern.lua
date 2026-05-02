local Pattern = {}

local TAG = "__easyswitch_pattern"

local function tagged(kind, data)
    data = data or {}
    data[TAG] = kind
    return data
end

local function isInteger(value)
    return type(value) == "number" and value % 1 == 0
end

local function isArrayTable(value)
    if type(value) ~= "table" then
        return false
    end

    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end
        count = count + 1
    end

    return count == #value
end

function Pattern.isTagged(value)
    return type(value) == "table" and value[TAG] ~= nil
end

function Pattern.isCaseList(value)
    return isArrayTable(value) and not Pattern.isTagged(value)
end

local function matchTagged(pattern, value)
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
            if Pattern.matches(pattern.patterns[i], value) then
                return true
            end
        end
        return false
    end

    if kind == "not" then
        return not Pattern.matches(pattern.pattern, value)
    end

    if kind == "array" then
        if not isArrayTable(value) then
            return false
        end

        for i = 1, #value do
            if not Pattern.matches(pattern.item, value[i]) then
                return false
            end
        end
        return true
    end

    error("Unknown pattern kind: " .. tostring(kind), 2)
end

function Pattern.matches(pattern, value)
    if Pattern.isTagged(pattern) then
        return matchTagged(pattern, value)
    end

    if type(pattern) == "table" then
        if type(value) ~= "table" then
            return false
        end

        for key, expected in pairs(pattern) do
            if not Pattern.matches(expected, value[key]) then
                return false
            end
        end
        return true
    end

    return pattern == value
end

Pattern.string = tagged("type", { name = "string" })
Pattern.number = tagged("type", { name = "number" })
Pattern.boolean = tagged("type", { name = "boolean" })
Pattern.integer = tagged("type", { name = "integer" })
Pattern.float = tagged("type", { name = "float" })

function Pattern.when(fn)
    if type(fn) ~= "function" then
        error("Pattern predicate must be a function", 2)
    end
    return tagged("predicate", { fn = fn })
end

function Pattern.any_of(...)
    local patterns = { ... }
    if #patterns == 0 then
        error("P.any_of requires at least one pattern", 2)
    end
    return tagged("any_of", { patterns = patterns })
end

function Pattern.not_(pattern)
    return tagged("not", { pattern = pattern })
end

function Pattern.array(item)
    return tagged("array", { item = item })
end

return Pattern
