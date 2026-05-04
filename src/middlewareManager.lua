-- Middleware chain for EasySwitch v2. Shared metatable, state on self.
-- Errors in a middleware emit `error` (if listened) and skip the failing
-- transform — the prior `current` is preserved, matching v1 semantics.
-- start/end events are only emitted when at least one listener is bound
-- so an empty middleware chain stays cheap.

local M = {}

local MiddlewareManager = {}
MiddlewareManager.__index = MiddlewareManager
M.MiddlewareManager = MiddlewareManager

function M.new()
    return setmetatable({
        list = {},
        n    = 0,
    }, MiddlewareManager)
end

function MiddlewareManager:add(middleware)
    if type(middleware) ~= "function" then
        error("Middleware must be a function", 2)
    end
    self.n = self.n + 1
    self.list[self.n] = middleware
end

function MiddlewareManager:execute(value, events)
    local n = self.n
    if n == 0 then return value end

    if events:has("middlewareStart") then
        events:emit("middlewareStart", value)
    end

    local current, list = value, self.list
    for i = 1, n do
        local ok, result = pcall(list[i], current)
        if not ok then
            if events:has("error") then
                events:emit("error", "middleware", result)
            end
        elseif result ~= nil then
            current = result
        end
    end

    if events:has("middlewareEnd") then
        events:emit("middlewareEnd", current)
    end

    return current
end

function MiddlewareManager:count()
    return self.n
end

return M
