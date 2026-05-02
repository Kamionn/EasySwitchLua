local CacheManager = {}

function CacheManager.new(eventManager, options)
    local weak = options and options.weak == true

    local function createCache()
        if weak then
            return setmetatable({}, { __mode = "kv" })
        end
        return {}
    end

    local cache = createCache()

    return {
        get = function(value)
            if value == nil then
                eventManager.emit("cacheMiss", value)
                return nil
            end

            local v = cache[value]
            if v ~= nil then
                eventManager.emit("cacheHit", value, v)
                return v
            end

            eventManager.emit("cacheMiss", value)
            return nil
        end,

        set = function(value, result)
            if value ~= nil and result ~= nil then
                cache[value] = result
            end
        end,

        clear = function()
            cache = createCache()
        end
    }
end

return CacheManager
