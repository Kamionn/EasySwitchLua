local Pattern = require("src.pattern")

local DEFAULT_MAX_CASES = 100

local ActionManager = {}

function ActionManager.new(maxCases)
    if maxCases ~= nil and (type(maxCases) ~= "number" or maxCases < 1) then
        error("maxCases must be a positive number", 2)
    end

    local dispatch = {}
    local patterns = {}
    local defaultAction
    local caseCount = 0
    local caseLimit = maxCases or DEFAULT_MAX_CASES

    local function addCase(value, action)
        if value == nil then
            error("Case value cannot be nil", 3)
        end

        if dispatch[value] == nil then
            if caseCount >= caseLimit then
                error("Too many cases", 3)
            end
            caseCount = caseCount + 1
        end
        dispatch[value] = action
    end

    local function addPattern(pattern, action)
        if caseCount >= caseLimit then
            error("Too many cases", 3)
        end

        caseCount = caseCount + 1
        patterns[#patterns + 1] = {
            pattern = pattern,
            action = action
        }
    end

    local function addCaseOrPattern(value, action)
        if type(value) == "table" and (Pattern.isTagged(value) or not Pattern.isCaseList(value)) then
            addPattern(value, action)
        else
            addCase(value, action)
        end
    end

    return {
        add = function(cases, action)
            if type(action) ~= "function" then
                error("Action must be a function", 2)
            end

            if type(cases) ~= "table" then
                addCase(cases, action)
            elseif Pattern.isCaseList(cases) then
                for i = 1, #cases do
                    addCaseOrPattern(cases[i], action)
                end
            else
                addPattern(cases, action)
            end
        end,

        execute = function(value)
            local action = dispatch[value]
            if action then
                return action(value), true, true
            end

            for i = 1, #patterns do
                local entry = patterns[i]
                if Pattern.matches(entry.pattern, value) then
                    return entry.action(value), true, false
                end
            end

            if defaultAction then
                return defaultAction(value), true, true
            end
            return nil, false, true
        end,

        setDefault = function(action)
            if type(action) ~= "function" then
                error("Default action must be a function", 2)
            end
            defaultAction = action
        end,

        hasAction = function(value)
            if dispatch[value] ~= nil then
                return true
            end

            for i = 1, #patterns do
                if Pattern.matches(patterns[i].pattern, value) then
                    return true
                end
            end

            return false
        end
    }
end

return ActionManager
