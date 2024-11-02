local ActionManager = {}

function ActionManager.new(maxCases)
    local dispatch = {}
    local default_action
    local case_count = 0
    local max_cases = maxCases or 100
    
    return {
        add = function(cases, action)
            if type(action) ~= "function" then
                error("Action must be a function", 2)
            end
            
            if type(cases) ~= "table" then
                if case_count >= max_cases then
                    error("Too many cases", 2)
                end
                dispatch[cases] = action
                case_count = case_count + 1
            else
                local new_count = case_count + #cases
                if new_count > max_cases then
                    error("Too many cases", 2)
                end
                for i = 1, #cases do
                    dispatch[cases[i]] = action
                end
                case_count = new_count
            end
        end,
        
        execute = function(value)
            local action = dispatch[value]
            if action then
                return action(value)
            end
            return default_action and default_action(value)
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