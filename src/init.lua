--[[
    EasySwitchLua
    Un système de switch avancé et performant pour Lua
    
    Usage:
    local Switch = require("easyswitch")
    
    local menuSwitch = Switch("menu")
        :when("start", function() 
            return "Game started" 
        end)
        :when("quit", function() 
            return "Game ended" 
        end)

    print(menuSwitch:execute("start"))
]]

local EventManager = require("src.eventManager")
local MiddlewareManager = require("src.middlewareManager")
local ActionManager = require("src.actionManager")
local CacheManager = require("src.cacheManager")

local function Switch(name, options)
    options = options or {}
    
    -- Initialisation des managers
    local eventManager = EventManager.new()
    local middlewareManager = MiddlewareManager.new(eventManager)
    local actionManager = ActionManager.new(options.maxCases)
    local cacheManager = CacheManager.new(eventManager)
    
    -- Construction du switch
    local switch = {}
    
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
    
    -- Exécution
    function switch:execute(value)
        eventManager.emit("beforeExecute", value)
        
        -- Vérification du cache
        local cached = cacheManager.get(value)
        if cached ~= nil then
            eventManager.emit("afterExecute", value, cached)
            return cached
        end
        
        -- Application des middlewares
        local final_value = middlewareManager.execute(value)
        
        -- Exécution de l'action
        local success, result = pcall(actionManager.execute, final_value)
        if not success then
            eventManager.emit("error", "action", result)
            result = nil
        end
        
        -- Cache et retour
        if result ~= nil then
            cacheManager.set(value, result)
        end
        
        eventManager.emit("afterExecute", value, result)
        return result
    end
    
    -- Méthodes utilitaires
    function switch:clearCache()
        cacheManager.clear()
        return self
    end
    
    function switch:clearEvents(event)
        eventManager.clear(event)
        return self
    end
    
    return switch
end

return Switch