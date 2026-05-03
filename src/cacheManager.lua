local CacheManager = {}

function CacheManager.new(eventManager)
    local cache = setmetatable({}, {__mode = "kv"})

    return {
        get = function(value)
            local v = cache[value]
            if v ~= nil then
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

        update = function(value, fn)
            if cache[value] ~= nil then
                local newResult = fn(cache[value])
                if newResult ~= nil then
                    cache[value] = newResult
                end
            end
        end,

        clear = function()
            cache = setmetatable({}, {__mode = "kv"})
        end
    }
end

return CacheManager