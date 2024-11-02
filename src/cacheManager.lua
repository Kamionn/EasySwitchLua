local CacheManager = {}

function CacheManager.new(eventManager)
    local cache = setmetatable({}, {__mode = "kv"})

    return {
        get = function(value)
            if cache[value] then
                local v = cache[value]
                eventManager.emit("cacheHit", value, v)
                return v
            end

            eventManager.emit("cacheMiss", value)
            return nil
        end,

        set = function(value, result)
            if result ~= nil then
                cache[value] = result
            end
        end,

        clear = function()
            cache = setmetatable({}, {__mode = "kv"})
        end
    }
end

return CacheManager