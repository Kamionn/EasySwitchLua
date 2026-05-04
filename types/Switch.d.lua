---@meta

---Switch instance returned by `EasySwitch.new()` or `EasySwitch("name")`.
---All builder methods return `self` for fluent chaining ; `:execute(v)`
---is the terminal call that runs the dispatch pipeline and returns the
---matched action's result (or `nil` when nothing matched and no default
---is set).
---
---Pipeline (in order) :
---  1. emit `beforeExecute`           (skip when no listener bound)
---  2. memoize cache lookup           (no-op when memoize is OFF)
---  3. `:before(...)` gate            (skip when nil)
---  4. middleware chain               (skip when empty)
---  5. dispatcher                     (Map literals → complex walk → default)
---  6. memoize cache store            (no-op when memoize is OFF or result is nil)
---  7. emit `noMatch`                 (only when nothing handled the value)
---  8. emit `afterExecute`            (skip when no listener bound)
---@class easyswitch.Switch
---@field FALLTHROUGH any  Sentinel : action returns this to keep matching subsequent rules.
local Switch = {}

---Subscribe a callback to one of the known events. Throws on unknown
---event names (catches typos at registration time).
---@param event easyswitch.Event
---@param callback fun(...): any
---@return easyswitch.Switch
function Switch:on(event, callback) end

---Add a dispatch rule. Three call forms :
---  `:when(cases, action)`                 — plain rule, no guard
---  `:when(cases, guard_fn, action)`       — guard form ; `guard_fn(value)` must return truthy
---  `:when(dsl_string, scope_tbl, action)` — DSL form ; the scope table forces DSL parsing
---
---`cases` accepts :
---  • any literal scalar (string, number, boolean) → Map fast path
---  • array of literals `{"GET", "POST"}`           → exploded into the Map
---  • plain table `{ kind = "click" }`              → partial shape pattern
---  • matchigo P descriptor (`P.string`, `P.union(...)`)
---  • DSL string starting with `{`, `[`, `(`, `'`, `"` → auto-parsed
---  • any other string                              → literal (use `'GET'` quoted-DSL or pass scope to force DSL)
---@param cases any
---@param action_or_second fun(value: any): any | fun(value: any): boolean | table
---@param action? fun(value: any): any
---@return easyswitch.Switch
function Switch:when(cases, action_or_second, action) end

---Set the fallback action that fires when nothing else matches and no
---rule returned a value. Calling this twice replaces the prior default.
---@param action fun(value: any): any
---@return easyswitch.Switch
function Switch:default(action) end

---Append a middleware. Each middleware receives the current `value` and
---returns the transformed one (or `nil` to keep the prior value). Errors
---inside a middleware are isolated : the prior value is preserved and
---the `error` event fires (when listened).
---@param middleware fun(value: any): any
---@return easyswitch.Switch
function Switch:use(middleware) end

---Set the gate function. Returning false from it short-circuits dispatch
---(emits `beforeCheckFailed`, returns nil). Pass `nil` to clear the gate.
---@param checkFunction (fun(value: any): boolean)?
---@return easyswitch.Switch
function Switch:before(checkFunction) end

---Run the dispatch pipeline against `value` and return the matched
---action's result. Returns `nil` when nothing matched and no default
---is set.
---@param value any
---@return any
function Switch:execute(value) end

---Enable result caching by input value. Cache uses weak refs ; mutating
---the switch (`:when`, `:default`, `:use`, `:before`) auto-invalidates.
---NaN and nil keys are never cached (Lua disallows them as table keys).
---Pass `{ verify = true }` to re-run the pipeline on every HIT and
---error on divergence — dev-only safety net for non-deterministic
---actions.
---@param opts? easyswitch.MemoizeOptions
---@return easyswitch.Switch
function Switch:memoize(opts) end

---Empty the memoize cache. No-op when memoize is disabled.
---@return easyswitch.Switch
function Switch:clearCache() end

---Remove all listeners for a given event, or for every event when no
---name is passed.
---@param event? easyswitch.Event
---@return easyswitch.Switch
function Switch:clearEvents(event) end

return Switch
