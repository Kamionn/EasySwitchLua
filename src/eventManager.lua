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
                local length = #events[event]
                events[event][length + 1] = callback
            end
        end,

        emit = function(event, ...)
            local array = events[event] or {}
            local length = #array

            for i = 1, length do
                local callback = array[i]
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