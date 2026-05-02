local EventManager = require("src.eventManager")
local MiddlewareManager = require("src.middlewareManager")
local ActionManager = require("src.actionManager")
local CacheManager = require("src.cacheManager")

local function SwitchInit(obj, name, _options)
    if not name then
        error("Switch id is required", 2)
    end

    if obj.registered[name] then
        error("Switch with id [" .. tostring(name) .. "] already registered", 2)
    end

    local options = _options or {}
    local cacheEnabled = options.cache ~= false

    -- Initialize managers
    local eventManager = EventManager.new()
    local middlewareManager = MiddlewareManager.new(eventManager)
    local actionManager = ActionManager.new(options.maxCases)
    local cacheManager = CacheManager.new(eventManager, {
        weak = options.weakCache == true
    })

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
        cacheManager.clear()
        return self
    end

    function switch:default(action)
        actionManager.setDefault(action)
        cacheManager.clear()
        return self
    end

    -- API Middleware
    function switch:use(middleware)
        middlewareManager.add(middleware)
        cacheManager.clear()
        return self
    end

    -- API Before
    function switch:before(checkFunction)
        if checkFunction ~= nil and type(checkFunction) ~= "function" then
            error("Before check must be a function", 2)
        end
        beforeCheck = checkFunction or beforeCheck
        cacheManager.clear()
        return self
    end

    -- Execution
    function switch:execute(value)
        eventManager.emit("beforeExecute", value)

        local beforeSuccess, beforeResult = pcall(beforeCheck, value)
        if not beforeSuccess then
            eventManager.emit("error", "before", beforeResult)
            eventManager.emit("afterExecute", value, nil)
            return nil
        end

        if not beforeResult then
            eventManager.emit("beforeCheckFailed", value)
            eventManager.emit("afterExecute", value, nil)
            return nil
        end

        -- Apply middlewares
        local final_value = middlewareManager.execute(value)

        -- Check the cache after validation and middlewares so they still run.
        if cacheEnabled then
            local cached = cacheManager.get(final_value)
            if cached ~= nil then
                eventManager.emit("afterExecute", value, cached, final_value)
                return cached
            end
        end

        -- Execute the action
        local success, result, matched = pcall(actionManager.execute, final_value)
        if not success then
            eventManager.emit("error", "action", result)
            result = nil
        elseif not matched then
            eventManager.emit("noMatch", final_value)
        end

        -- Cache and return
        if cacheEnabled and result ~= nil then
            cacheManager.set(final_value, result)
        end

        eventManager.emit("afterExecute", value, result, final_value)
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
            size = size + 1
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
