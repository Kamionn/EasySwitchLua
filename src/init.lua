local EventManager = require("src.eventManager")
local MiddlewareManager = require("src.middlewareManager")
local ActionManager = require("src.actionManager")
local CacheManager = require("src.cacheManager")
local Pattern = require("src.pattern")

local function SwitchInit(obj, name, _options)
    if not name then
        error("Switch id is required", 2)
    end

    if obj.registered[name] then
        error("Switch with id [" .. tostring(name) .. "] already registered", 2)
    end

    local options = _options or {}
    if type(options) ~= "table" then
        error("Switch options must be a table", 2)
    end
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

    local function defaultBeforeCheck() return true end
    local beforeCheck = defaultBeforeCheck

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
        beforeCheck = checkFunction or defaultBeforeCheck
        cacheManager.clear()
        return self
    end

    -- Execution
    function switch:execute(value)
        eventManager.emit("beforeExecute", value)

        local beforeSuccess, beforeResult = pcall(beforeCheck, value)
        if not beforeSuccess then
            eventManager.emit("error", "before", beforeResult)
            eventManager.emit("afterExecute", value, nil, nil)
            return nil
        end

        if not beforeResult then
            eventManager.emit("beforeCheckFailed", value)
            eventManager.emit("afterExecute", value, nil, nil)
            return nil
        end

        local finalValue = middlewareManager.execute(value)

        if cacheEnabled then
            local cached = cacheManager.get(finalValue)
            if cached ~= nil then
                eventManager.emit("afterExecute", value, cached, finalValue)
                return cached
            end
        end

        local success, result, matched, cacheable = pcall(actionManager.execute, finalValue)
        if not success then
            eventManager.emit("error", "action", result)
            result = nil
        elseif not matched then
            eventManager.emit("noMatch", finalValue)
        end

        if cacheEnabled and cacheable ~= false and result ~= nil then
            cacheManager.set(finalValue, result)
        end

        eventManager.emit("afterExecute", value, result, finalValue)
        return result
    end

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

local Switch = setmetatable({ registered = {}, P = Pattern }, { __call = SwitchInit })

function Switch:get(name)
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
    if name ~= nil then
        self.registered[name] = nil
    else
        self.registered = {}
    end
    return self
end

return Switch
