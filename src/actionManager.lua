local ActionManager = {}

function ActionManager.new(maxCases)
    local dispatch = {}
    local default_action
    local case_count = 0
    local max_cases = maxCases or 100

    if type(max_cases) ~= "number" or max_cases < 1 then
        error("maxCases must be a positive number", 2)
    end

    local function addCase(value, action)
        if value == nil then
            error("Case value cannot be nil", 3)
        end

        if dispatch[value] == nil then
            if case_count >= max_cases then
                error("Too many cases", 3)
            end
            case_count = case_count + 1
        end
        dispatch[value] = action
    end

    return {
        add = function(cases, action)
            if type(action) ~= "function" then
                error("Action must be a function", 2)
            end

            if type(cases) ~= "table" then
                addCase(cases, action)
            else
                local length = #cases
                for i = 1, length do
                    local value = cases[i]
                    addCase(value, action)
                end
            end
        end,

        execute = function(value)
            local action = dispatch[value]
            if action then
                return action(value), true
            end
            if default_action then
                return default_action(value), true
            end
            return nil, false
        end,

        setDefault = function(action)
            if type(action) ~= "function" then
                error("Default action must be a function", 2)
            end
            default_action = action
        end,

        hasAction = function(value)
            return dispatch[value] ~= nil
        end
    }
end

return ActionManager
