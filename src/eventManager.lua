local EventManager = {}

function EventManager.new()
    local events = {
        beforeExecute     = {},
        afterExecute      = {},
        error             = {},
        cacheHit          = {},
        cacheMiss         = {},
        middlewareStart   = {},
        middlewareEnd     = {},
        noMatch           = {},
        beforeCheckFailed = {},
    }

    return {
        on = function(event, callback)
            if not events[event] then
                error("Unknown event: '" .. tostring(event) .. "'", 2)
            end
            events[event][#events[event] + 1] = callback
        end,

        emit = function(event, ...)
            local array = events[event]
            if not array then return end
            for i = 1, #array do
                local ok, err = pcall(array[i], ...)
                if not ok then
                    print("[EasySwitch] Event error in '" .. event .. "':", err)
                end
            end
        end,

        clear = function(event)
            if event then
                if events[event] then events[event] = {} end
            else
                for k in pairs(events) do events[k] = {} end
            end
        end,
    }
end

return EventManager
