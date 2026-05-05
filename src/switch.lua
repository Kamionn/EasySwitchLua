-- Switch instance for EasySwitch v2. Methods live on a shared metatable
-- (`Switch`) so 1000 instances pay 1 metatable, not 1000 closure sets.
--
-- Pipeline (in order) :
--   1. emit beforeExecute  (skip if no listener)
--   2. cache lookup        (only if memoize() was called ; skip rest on HIT)
--   3. beforeCheck gate    (nil = always pass)
--   4. middleware chain
--   5. dispatcher          (Map literals → complex walk → default, FALLTHROUGH-aware)
--   6. cache set           (only if memoize() and result ≠ nil)
--   7. emit noMatch        (only when nothing handled the value)
--   8. emit afterExecute   (skip if no listener)
--
-- `Switch.new({ safe = true })` wraps the dispatcher in a pcall and emits
-- the `error` event on action errors ; default is `nil` (errors propagate
-- like matchigo).
--
-- Memoization is opt-in via `:memoize()`. When ON, results are cached by
-- input value (weak refs, GC-friendly). NaN and nil keys aren't cached
-- (Lua disallows them). Mutating the switch (`:when`, `:default`, `:use`,
-- `:before`) auto-invalidates the cache so a new rule can't be shadowed
-- by a stale entry. Verify mode (`:memoize({ verify = true })`) re-runs
-- the pipeline on every HIT and errors on divergence — meant for dev.

local Dispatcher        = require("src.dispatcher")
local EventManager      = require("src.eventManager")
local MiddlewareManager = require("src.middlewareManager")

local M = {}

local FALLTHROUGH = Dispatcher.FALLTHROUGH
M.FALLTHROUGH = FALLTHROUGH

local Switch = {}
Switch.__index = Switch
M.Switch = Switch

function M.new(options)
    local opts = options or {}
    return setmetatable({
        _dispatcher    = Dispatcher.new(),
        _events        = EventManager.new(),
        _middleware    = MiddlewareManager.new(),
        _beforeCheck   = nil,
        _safe          = opts.safe == true,
        _cache         = nil,    -- nil = memoize disabled
        _memoizeVerify = false,
        FALLTHROUGH    = FALLTHROUGH,
    }, Switch)
end

local function newCache()
    return setmetatable({}, { __mode = "kv" })
end

-- Cache invalidation : clears entries but keeps memoize enabled. Called
-- on any state change that could alter dispatch results (rule add, default
-- change, middleware add, beforeCheck change).
local function invalidate(self)
    if self._cache ~= nil then self._cache = newCache() end
end

function Switch:on(event, callback)
    self._events:on(event, callback)
    return self
end

-- 2-arg : :when(cases, action)
-- 3-arg with function-2nd : :when(cases, guard_fn, action) — guard form
-- 3-arg with table-2nd    : :when(dsl_string, scope_tbl, action) — DSL+scope form
function Switch:when(cases, second, action)
    if type(action) == "function" then
        if type(second) == "function" then
            self._dispatcher:add(cases, second, action)
        elseif type(second) == "table" then
            self._dispatcher:add(cases, nil, action, second)
        else
            error("Switch:when : 3-arg form expects (cases, guard|scope, action)", 2)
        end
    else
        self._dispatcher:add(cases, nil, second)
    end
    invalidate(self)
    return self
end

function Switch:default(action)
    self._dispatcher:setDefault(action)
    invalidate(self)
    return self
end

function Switch:use(middleware)
    self._middleware:add(middleware)
    invalidate(self)
    return self
end

function Switch:before(checkFunction)
    self._beforeCheck = checkFunction
    invalidate(self)
    return self
end

-- ── Memoize (opt-in) ──────────────────────────────────────────────────────
-- Calls are cached by input value (weak refs). Verify mode re-runs the
-- pipeline on every HIT and errors on divergence — dev-only safety net.
-- Calling memoize() multiple times only updates the verify flag.
function Switch:memoize(opts)
    opts = opts or {}
    if self._cache == nil then
        self._cache = newCache()
    end
    self._memoizeVerify = opts.verify == true
    return self
end

-- Empties the cache without disabling memoize. No-op when memoize is OFF.
function Switch:clearCache()
    if self._cache ~= nil then
        self._cache = newCache()
    end
    return self
end

-- Runs beforeCheck + middleware + dispatcher and returns just `result`.
-- Used by the memoize verify path : we need to reproduce the exact result
-- the original execute() produced for the same input, without touching
-- the cache or emitting events (the caller already did those steps).
function Switch:_runPipelineForVerify(value)
    local check = self._beforeCheck
    if check ~= nil and not check(value) then return nil end

    local middleware = self._middleware
    local final_value
    if middleware.n == 0 then
        final_value = value
    else
        final_value = middleware:execute(value, self._events)
    end

    local dispatcher = self._dispatcher
    if self._safe then
        local ok, r = pcall(dispatcher.execute, dispatcher, final_value)
        return ok and r or nil
    end
    return (dispatcher:execute(final_value))
end

function Switch:execute(value)
    local events     = self._events
    local middleware = self._middleware
    local dispatcher = self._dispatcher

    -- Inlined `events:has(name)` : direct array length check skips the
    -- method dispatch + extra hash lookup. Saves ~5-10 ns per check on
    -- the hot path where no listener is bound.
    if events.beforeExecute[1] ~= nil then
        events:emit("beforeExecute", value)
    end

    -- Memoize lookup. Cache is nil when memoize() was never called, so the
    -- whole branch costs one nil check on the hot path. NaN and nil keys
    -- can't be stored in a Lua table, so we skip caching for them.
    local cache = self._cache
    local cacheable = cache ~= nil and value ~= nil and value == value
    if cacheable then
        local cached = cache[value]
        if cached ~= nil then
            if self._memoizeVerify then
                local fresh = self:_runPipelineForVerify(value)
                if fresh ~= cached then
                    error(string.format(
                        "Memoize verify failed for input %s : cached=%s, action returned %s. Your action is non-deterministic ; do not enable memoize.",
                        tostring(value), tostring(cached), tostring(fresh)), 2)
                end
            end
            if events.afterExecute[1] ~= nil then
                events:emit("afterExecute", value, cached)
            end
            return cached
        end
    end

    local check = self._beforeCheck
    if check ~= nil and not check(value) then
        if events.beforeCheckFailed[1] ~= nil then
            events:emit("beforeCheckFailed", value)
        end
        return nil
    end

    -- Inlined middleware short-circuit : zero-middleware case skips the
    -- method call entirely. Common in apps that just dispatch.
    local final_value
    if middleware.n == 0 then
        final_value = value
    else
        final_value = middleware:execute(value, events)
    end

    local result, matched
    if self._safe then
        local ok, r, m = pcall(dispatcher.execute, dispatcher, final_value)
        if not ok then
            if events.error[1] ~= nil then
                events:emit("error", "action", r)
            end
            if events.afterExecute[1] ~= nil then
                events:emit("afterExecute", value, nil)
            end
            return nil
        end
        result, matched = r, m
    else
        result, matched = dispatcher:execute(final_value)
    end

    if cacheable and result ~= nil then
        cache[value] = result
    end

    if not matched and events.noMatch[1] ~= nil then
        events:emit("noMatch", value)
    end

    if events.afterExecute[1] ~= nil then
        events:emit("afterExecute", value, result)
    end

    return result
end

function Switch:clearEvents(event)
    self._events:clear(event)
    return self
end

return M
