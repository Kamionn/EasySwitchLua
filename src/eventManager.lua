-- Event hub for EasySwitch v2. Shared metatable : every Switch instance
-- holds one EventManager, methods live on the metatable, state lives on
-- self. `has(event)` is a hot-path helper used by switch.lua to skip
-- emit() calls when nobody listens.
--
-- Cache events (`cacheHit` / `cacheMiss`) are gone — v2 makes memoize
-- opt-in, no implicit cache so no implicit events to fire.

local M = {}

local EventManager = {}
EventManager.__index = EventManager
M.EventManager = EventManager

local KNOWN_EVENTS = {
    beforeExecute     = true,
    afterExecute      = true,
    error             = true,
    middlewareStart   = true,
    middlewareEnd     = true,
    noMatch           = true,
    beforeCheckFailed = true,
}
M.KNOWN_EVENTS = KNOWN_EVENTS

function M.new()
    return setmetatable({
        beforeExecute     = {},
        afterExecute      = {},
        error             = {},
        middlewareStart   = {},
        middlewareEnd     = {},
        noMatch           = {},
        beforeCheckFailed = {},
    }, EventManager)
end

function EventManager:on(event, callback)
    if not KNOWN_EVENTS[event] then
        error("Unknown event: '" .. tostring(event) .. "'", 2)
    end
    local arr = self[event]
    arr[#arr + 1] = callback
end

function EventManager:has(event)
    local arr = self[event]
    return arr ~= nil and #arr > 0
end

function EventManager:emit(event, ...)
    local arr = self[event]
    if arr == nil then return end
    local n = #arr
    if n == 0 then return end
    for i = 1, n do
        local ok, err = pcall(arr[i], ...)
        if not ok then
            print("[EasySwitch] Event error in '" .. event .. "':", err)
        end
    end
end

function EventManager:clear(event)
    if event then
        if self[event] then self[event] = {} end
    else
        for k in pairs(KNOWN_EVENTS) do self[k] = {} end
    end
end

return M
