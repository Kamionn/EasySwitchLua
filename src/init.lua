local EventManager = require("src.eventManager")
local MiddlewareManager = require("src.middlewareManager")
local ActionManager = require("src.actionManager")
local CacheManager = require("src.cacheManager")

local function SwitchInit(obj, name, _options)
    if not name or obj.registered[name] then
        error("Switch with id [" .. name .. "] already registered", 2)
        return
    end
    
    local options = _options or {}

    -- Initialize managers
    local eventManager = EventManager.new()
    local middlewareManager = MiddlewareManager.new(eventManager)
    local actionManager = ActionManager.new(options.maxCases)
    local cacheManager = CacheManager.new(eventManager)

    -- Build the switch
    local switch = {}

    local beforeCheck = function() return true end

    -- API Events
    function switch:on(event, callback)
        eventManager.on(event, callback)
        return self
    end

    -- API Actions
    function switch:when(cases, action)
        actionManager.add(cases, action)
        return self
    end

    function switch:default(action)
        actionManager.setDefault(action)
        return self
    end

    -- API Middleware
    function switch:use(middleware)
        middlewareManager.add(middleware)
        return self
    end

    -- API Before
    function switch:before(checkFunction)
        beforeCheck = checkFunction or beforeCheck
        return self
    end

    -- Execution
    function switch:execute(value)
        eventManager.emit("beforeExecute", value)

        -- Check the cache
        local cached = cacheManager.get(value)
        if cached ~= nil then
            eventManager.emit("afterExecute", value, cached)
            return cached
        end

        if not beforeCheck(value) then
            eventManager.emit("beforeCheckFailed", value)
            return nil
        end

        -- Apply middlewares
        local final_value = middlewareManager.execute(value)

        -- Execute the action
        local success, result = pcall(actionManager.execute, final_value)
        if not success then
            eventManager.emit("error", "action", result)
            result = nil
        end

        -- Cache and return
        if result ~= nil then
            cacheManager.set(value, result)
        end

        eventManager.emit("afterExecute", value, result)
        return result
    end

    -- Utility methods
    function switch:clearCache()
        cacheManager.clear()
        return self
    end

    function switch:clearEvents(event)
        eventManager.clear(event)
        return self
    end

    obj.registered[name] = switch
    return switch
end

local Switch = setmetatable({ registered = {} }, { __call = SwitchInit })

function Switch:get(name)
    if not next(self.registered) then
        print('No switches registered')
        return
    end

    if not name then
        local switches, size = {}, 0
        for k, v in pairs(self.registered) do
            size += 1
            switches[k] = v
        end
        return switches, size
    end

    return self.registered[name]
end

function Switch:clear(name)
    if name then
        self.registered[name] = nil
    else
        self.registered = {}
    end
    return self
end

return Switch