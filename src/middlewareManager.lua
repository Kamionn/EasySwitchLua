local MiddlewareManager = {}

function MiddlewareManager.new(eventManager)
    local middlewares = {}
    local compiled_middleware
    local middleware_hash = ""
    
    local function hashMiddlewares()
        local hash = ""
        for i, middleware in ipairs(middlewares) do
            hash = hash .. tostring(middleware)
        end
        return hash
    end
    
    local function compileMiddlewares()
        local new_hash = hashMiddlewares()
        if new_hash == middleware_hash and compiled_middleware then
            return compiled_middleware
        end
        
        middleware_hash = new_hash
        
        return function(value)
            local current = value
            for i, middleware in ipairs(middlewares) do
                local success, result = pcall(middleware, current)
                if not success then
                    eventManager.emit("error", "middleware", result)
                    current = value
                elseif result ~= nil then
                    current = result
                end
            end
            return current
        end
    end
    
    return {
        add = function(middleware)
            if type(middleware) ~= "function" then
                error("Middleware must be a function", 2)
            end
            table.insert(middlewares, middleware)
            compiled_middleware = nil  -- Force recompilation
        end,
        
        execute = function(value)
            if #middlewares == 0 then 
                return value 
            end
            
            eventManager.emit("middlewareStart", value)
            if not compiled_middleware then
                compiled_middleware = compileMiddlewares()
            end
            
            local result = compiled_middleware(value)
            eventManager.emit("middlewareEnd", result)
            return result
        end,
        
        count = function()
            return #middlewares
        end
    }
end

return MiddlewareManager