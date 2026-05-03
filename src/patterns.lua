-- Pattern vocabulary for structural dispatch in EasySwitchLua.
-- Patterns are tagged tables (PATTERN_MT metatable) carrying a _match function.
-- Plain tables with string keys are also treated as partial table matchers.

local P = {}

local PATTERN_MT = {}
PATTERN_MT.__index = PATTERN_MT
PATTERN_MT.__tostring = function(self) return self._name end

-- Lua < 5.3 / LuaJIT / Luau polyfill for math.type
local math_type = math.type or function(n)
    if type(n) ~= "number" then return nil end
    if n ~= n or n == math.huge or n == -math.huge then return "float" end
    return (math.floor(n) == n) and "integer" or "float"
end

local function new_pattern(match_fn, name)
    return setmetatable({ _match = match_fn, _name = name }, PATTERN_MT)
end

-- Returns true if v is a pattern descriptor (created by this module)
local function is_pattern(v)
    return type(v) == "table" and getmetatable(v) == PATTERN_MT
end

-- Recursive match: pattern OR literal OR partial table
local function match(pat, value)
    if is_pattern(pat) then
        return pat._match(value)
    elseif type(pat) == "table" then
        if type(value) ~= "table" then return false end
        for k, v in pairs(pat) do
            if not match(v, value[k]) then return false end
        end
        return true
    else
        return pat == value
    end
end

-- ── Type sentinels ────────────────────────────────────────────────────────────

P.string  = new_pattern(function(v) return type(v) == "string"   end, "P.string")
P.number  = new_pattern(function(v) return type(v) == "number"   end, "P.number")
P.boolean = new_pattern(function(v) return type(v) == "boolean"  end, "P.boolean")
P.table   = new_pattern(function(v) return type(v) == "table"    end, "P.table")
P.func    = new_pattern(function(v) return type(v) == "function" end, "P.func")
P.nil_    = new_pattern(function(v) return v == nil               end, "P.nil_")
P.any     = new_pattern(function(_) return true                   end, "P.any")
P.integer = new_pattern(function(v) return math_type(v) == "integer" end, "P.integer")
P.float   = new_pattern(function(v) return math_type(v) == "float"   end, "P.float")

-- ── Combinators ───────────────────────────────────────────────────────────────

-- P.when(fn) — arbitrary predicate
function P.when(fn)
    assert(type(fn) == "function", "P.when expects a function")
    return new_pattern(fn, "P.when(...)")
end

-- P.any_of(a, b, ...) — union of literals and/or patterns
function P.any_of(...)
    local options = { ... }
    return new_pattern(function(v)
        for i = 1, #options do
            if match(options[i], v) then return true end
        end
        return false
    end, "P.any_of(...)")
end

-- P.not_(pat) — negation
function P.not_(pat)
    return new_pattern(function(v) return not match(pat, v) end, "P.not_(...)")
end

-- P.and_(a, b, ...) / P.all_of — intersection: all patterns must match
function P.and_(...)
    local pats = { ... }
    assert(#pats >= 1, "P.and_ expects at least one argument")
    return new_pattern(function(v)
        for i = 1, #pats do
            if not match(pats[i], v) then return false end
        end
        return true
    end, "P.and_(...)")
end
P.all_of = P.and_

-- P.between(min, max) — inclusive numeric range
function P.between(min, max)
    assert(type(min) == "number" and type(max) == "number", "P.between expects two numbers")
    return new_pattern(function(v)
        return type(v) == "number" and v >= min and v <= max
    end, "P.between(" .. min .. ", " .. max .. ")")
end

-- P.shape(tbl) — strict table match: all keys in tbl must match AND no extra keys allowed
function P.shape(tbl)
    assert(type(tbl) == "table", "P.shape expects a table")
    return new_pattern(function(v)
        if type(v) ~= "table" then return false end
        for k, pat in pairs(tbl) do
            if not match(pat, v[k]) then return false end
        end
        for k in pairs(v) do
            if tbl[k] == nil then return false end
        end
        return true
    end, "P.shape(...)")
end

-- P.string_match(lua_pattern) — string.match against a Lua pattern
function P.string_match(lua_pattern)
    assert(type(lua_pattern) == "string", "P.string_match expects a string pattern")
    return new_pattern(function(v)
        return type(v) == "string" and string.match(v, lua_pattern) ~= nil
    end, "P.string_match(" .. lua_pattern .. ")")
end

-- P.array(item_pat) — non-empty sequential table where every element matches item_pat
function P.array(item_pat)
    return new_pattern(function(v)
        if type(v) ~= "table" or #v == 0 then return false end
        for i = 1, #v do
            if not match(item_pat, v[i]) then return false end
        end
        return true
    end, "P.array(...)")
end

-- ── Exports ───────────────────────────────────────────────────────────────────

P.is_pattern = is_pattern
P.match      = match

return P
