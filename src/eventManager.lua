local EventManager = {}

function EventManager.new()
    local events = {
        beforeExecute = {},
        afterExecute = {},
        error = {},
        cacheHit = {},
        cacheMiss = {},
        middlewareStart = {},
        middlewareEnd = {},
        noMatch = {}
    }
    
    return {
        on = function(event, callback)
            if events[event] then
                table.insert(events[event], callback)
            end
        end,
        
        emit = function(event, ...)
            for _, callback in ipairs(events[event] or {}) do
                local success, err = pcall(callback, ...)
                if not success then
                    print("Event error:", err)
                end
            end
        end,
        
        clear = function(event)
            if event then
                events[event] = {}
            else
                for k in pairs(events) do
                    events[k] = {}
                end
            end
        end
    }
end

return EventManager