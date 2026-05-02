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
        beforeCheckFailed = {},
        noMatch = {}
    }

    return {
        on = function(event, callback)
            if not events[event] then
                error("Unknown event: " .. tostring(event), 2)
            end

            if type(callback) ~= "function" then
                error("Event callback must be a function", 2)
            end

            local length = #events[event]
            events[event][length + 1] = callback
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
                if not events[event] then
                    error("Unknown event: " .. tostring(event), 2)
                end
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
