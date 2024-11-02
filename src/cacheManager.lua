local CacheManager = {}

function CacheManager.new(eventManager)
    local cache = setmetatable({}, {__mode = "kv"}) 
    
    return {
        get = function(value)
            for k, v in pairs(cache) do -- bv SUP2Ak
                if k == value then
                    eventManager.emit("cacheHit", value, v)
                    return v
                end
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