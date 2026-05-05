-- Dispatch core for EasySwitch v2. Built on matchigo's `buildTest` so all
-- pattern-test logic lives in matchigo (single source of truth). Adds two
-- things matchigo doesn't have natively :
--   • Map literal fast path with FALLTHROUGH continuation semantics
--   • walk-then-default ordering matching the v1 EasySwitch contract
--
-- `:when()` arguments are normalised here :
--   • matchigo P descriptor          → complex rule, test = pat._test
--   • plain table with #t > 0        → array of literals, exploded into the Map
--   • plain table with #t == 0       → shape pattern, test = buildTest(t)
--   • DSL-looking string             → parsePattern → complex rule
--   • any other scalar               → Map literal
--
-- DSL detection rules (strict, to keep `:when("hi!?", action)` literal) :
--   1. A scope table was passed (3-arg form `:when(s, scope, action)`)
--      → always treat the string as DSL.
--   2. Otherwise, leading char must be one of `{[(\"'` (a structural
--      delimiter or string-literal quote). Operators like `|`, `&`, `?`,
--      `!` are NOT triggers because they appear legitimately in many
--      string literals.

local matchigo = require("vendor.matchigo")
local buildTest    = matchigo.buildTest
local isP          = matchigo.isP
local parsePattern = matchigo.parsePattern

local M = {}

local FALLTHROUGH = setmetatable({}, {
    __tostring = function() return "EasySwitch.FALLTHROUGH" end,
})
M.FALLTHROUGH = FALLTHROUGH

local Dispatcher = {}
Dispatcher.__index = Dispatcher
M.Dispatcher = Dispatcher

function M.new()
    return setmetatable({
        literals     = {},
        complex      = {},
        complexCount = 0,
        default      = nil,
    }, Dispatcher)
end

local function hasDSLLeadingChar(s)
    local first = s:sub(1, 1)
    return first == "{" or first == "[" or first == "(" or first == "'" or first == '"'
end
M.hasDSLLeadingChar = hasDSLLeadingChar

local function isLiteralKeySafe(v)
    if v == nil then return false end
    if type(v) == "table" then return false end
    return v == v -- excludes NaN
end

function Dispatcher:add(cases, guard, action, scope)
    if type(action) ~= "function" then
        error("Action must be a function", 3)
    end

    if type(cases) == "string" and (scope ~= nil or hasDSLLeadingChar(cases)) then
        cases = parsePattern(cases, scope)
    end

    if isP(cases) then
        self.complexCount = self.complexCount + 1
        self.complex[self.complexCount] = {
            test = cases._test, guard = guard, action = action,
        }
        return
    end

    if type(cases) == "table" then
        local n = #cases
        if n > 0 then
            if guard ~= nil then
                error("Guards are not supported with literal arrays", 3)
            end
            for i = 1, n do
                self.literals[cases[i]] = action
            end
            return
        end
        self.complexCount = self.complexCount + 1
        self.complex[self.complexCount] = {
            test = buildTest(cases), guard = guard, action = action,
        }
        return
    end

    if guard == nil and isLiteralKeySafe(cases) then
        self.literals[cases] = action
        return
    end

    self.complexCount = self.complexCount + 1
    self.complex[self.complexCount] = {
        test = buildTest(cases), guard = guard, action = action,
    }
end

function Dispatcher:setDefault(action)
    if type(action) ~= "function" then
        error("Default action must be a function", 3)
    end
    self.default = action
end

function Dispatcher:execute(value)
    local everMatched = false

    -- Hot path : literal Map hit + non-fallthrough result. We exit before
    -- ever needing `everMatched`, so we only set it when we actually
    -- continue past this point (fallthrough sentinel returned).
    local action = self.literals[value]
    if action ~= nil then
        local result = action(value)
        if result ~= FALLTHROUGH then
            return result, true
        end
        everMatched = true
    end

    local complex, n = self.complex, self.complexCount
    for i = 1, n do
        local r = complex[i]
        if r.test(value) and (r.guard == nil or r.guard(value)) then
            local result = r.action(value)
            if result ~= FALLTHROUGH then
                return result, true
            end
            everMatched = true
        end
    end

    if self.default then
        return self.default(value), true
    end

    return nil, everMatched
end

return M
