-- Pure switch instance factory — zero global state.
-- All managers are created fresh per instance.

local EventManager      = require("src.eventManager")
local MiddlewareManager = require("src.middlewareManager")
local ActionManager     = require("src.actionManager")
local CacheManager      = require("src.cacheManager")
local P                 = require("src.patterns")

local Switch = {}

-- Sentinel returned by an action to continue matching subsequent cases.
local FALLTHROUGH = setmetatable({}, {
    __tostring = function() return "EasySwitch.FALLTHROUGH" end,
})
Switch.FALLTHROUGH = FALLTHROUGH

function Switch.new(options)
    local opts = options or {}

    local eventManager      = EventManager.new()
    local middlewareManager = MiddlewareManager.new(eventManager)
    local actionManager     = ActionManager.new(opts.maxCases, FALLTHROUGH)
    local cacheManager      = CacheManager.new(eventManager)

    local beforeCheck = function() return true end

    local instance = {}

    -- ── Events ────────────────────────────────────────────────────────────────

    function instance:on(event, callback)
        eventManager.on(event, callback)
        return self
    end

    -- ── Cases ─────────────────────────────────────────────────────────────────

    -- 2-arg form : when(cases, action)
    -- 3-arg form : when(cases, guard, action) — guard(v) must return true to proceed
    function instance:when(cases, guard_or_action, action)
        if type(action) == "function" then
            local guard = guard_or_action
            actionManager.add(P.when(function(v)
                return P.match(cases, v) and guard(v)
            end), action)
        else
            actionManager.add(cases, guard_or_action)
        end
        return self
    end

    function instance:default(action)
        actionManager.setDefault(action)
        return self
    end

    -- ── Middleware ────────────────────────────────────────────────────────────

    function instance:use(middleware)
        middlewareManager.add(middleware)
        return self
    end

    -- ── Gate ──────────────────────────────────────────────────────────────────

    function instance:before(checkFunction)
        beforeCheck = checkFunction or beforeCheck
        return self
    end

    -- ── Execution ─────────────────────────────────────────────────────────────

    function instance:execute(value)
        eventManager.emit("beforeExecute", value)

        -- Cache check — only hits for scalar keys; table refs almost never reuse
        local cached = cacheManager.get(value)
        if cached ~= nil then
            eventManager.emit("afterExecute", value, cached)
            return cached
        end

        if not beforeCheck(value) then
            eventManager.emit("beforeCheckFailed", value)
            return nil
        end

        local final_value = middlewareManager.execute(value)

        -- result, cacheable, matched
        local ok, result, cacheable, matched = pcall(actionManager.execute, final_value)
        if not ok then
            eventManager.emit("error", "action", result)
            eventManager.emit("afterExecute", value, nil)
            return nil
        end

        if not matched then
            eventManager.emit("noMatch", value)
        end

        if cacheable and result ~= nil then
            cacheManager.set(value, result)
        end

        eventManager.emit("afterExecute", value, result)
        return result
    end

    -- ── Sentinel ──────────────────────────────────────────────────────────────

    instance.FALLTHROUGH = FALLTHROUGH

    -- ── Utilities ─────────────────────────────────────────────────────────────

    function instance:clearCache()
        cacheManager.clear()
        return self
    end

    function instance:clearEvents(event)
        eventManager.clear(event)
        return self
    end

    return instance
end

return Switch
