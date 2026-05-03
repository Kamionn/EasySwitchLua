local MiddlewareManager = {}

function MiddlewareManager.new(eventManager)
    local middlewares = {}
    local compiled

    local function compile()
        return function(value)
            local current = value
            for i = 1, #middlewares do
                local success, result = pcall(middlewares[i], current)
                if not success then
                    eventManager.emit("error", "middleware", result)
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

            middlewares[#middlewares + 1] = middleware
            compiled = nil
        end,

        execute = function(value)
            if #middlewares == 0 then
                return value
            end

            eventManager.emit("middlewareStart", value)
            if not compiled then
                compiled = compile()
            end

            local result = compiled(value)
            eventManager.emit("middlewareEnd", result)
            return result
        end,

        count = function()
            return #middlewares
        end
    }
end

return MiddlewareManager
