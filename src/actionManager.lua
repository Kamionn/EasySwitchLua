local P = require("src.patterns")

local ActionManager = {}

function ActionManager.new(maxCases, fallthrough_sentinel)
    local literal_dispatch = {}  -- O(1) hash, results are cacheable
    local pattern_rules    = {}  -- ordered list, iterated, not cached
    local default_action
    local case_count  = 0
    local max_cases   = maxCases or 100
    local has_patterns = false

    local function guard_count(n)
        if case_count + n > max_cases then
            error("Too many cases (max " .. max_cases .. ")", 3)
        end
    end

    return {
        add = function(cases, action)
            if type(action) ~= "function" then
                error("Action must be a function", 2)
            end

            if P.is_pattern(cases) then
                -- P.string, P.when(fn), P.any_of(...), etc.
                guard_count(1)
                has_patterns = true
                pattern_rules[#pattern_rules + 1] = { pat = cases, action = action }
                case_count = case_count + 1

            elseif type(cases) == "table" then
                if #cases > 0 then
                    -- {"a", "b", "c"} → array of literals (backward-compat)
                    guard_count(#cases)
                    for i = 1, #cases do
                        literal_dispatch[cases[i]] = action
                    end
                    case_count = case_count + #cases
                else
                    -- {kind="circle", r=P.number} → partial table pattern
                    guard_count(1)
                    has_patterns = true
                    pattern_rules[#pattern_rules + 1] = { pat = cases, action = action }
                    case_count = case_count + 1
                end

            else
                -- "hello", 42, true → single literal
                guard_count(1)
                literal_dispatch[cases] = action
                case_count = case_count + 1
            end
        end,

        -- Returns: result, cacheable, matched
        -- cacheable=true only for literal hits (safe to cache by key)
        -- matched=false when nothing handled the value (noMatch event)
        -- An action may return fallthrough_sentinel to continue matching.
        execute = function(value)
            local ever_matched = false

            local action = literal_dispatch[value]
            if action then
                ever_matched = true
                local result = action(value)
                if result ~= fallthrough_sentinel then
                    return result, true, true
                end
            end

            if has_patterns then
                for i = 1, #pattern_rules do
                    local rule = pattern_rules[i]
                    if P.match(rule.pat, value) then
                        ever_matched = true
                        local result = rule.action(value)
                        if result ~= fallthrough_sentinel then
                            return result, false, true
                        end
                    end
                end
            end

            if default_action then
                return default_action(value), false, true
            end

            return nil, false, ever_matched
        end,

        setDefault = function(action)
            if type(action) ~= "function" then
                error("Default action must be a function", 2)
            end
            default_action = action
        end,

        hasAction = function(value)
            return literal_dispatch[value] ~= nil
        end,

        hasPatterns = function()
            return has_patterns
        end,
    }
end

return ActionManager
