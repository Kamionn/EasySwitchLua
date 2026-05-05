---@meta

-- ────────────────────────────────────────────────────────────────────────
-- EasySwitch type definitions for lua-language-server (LuaLS / sumneko).
-- Drop the `types/` folder anywhere in your workspace ; LuaLS picks up
-- `---@meta` files as definition-only (no runtime code executes).
--
-- Splits :
--   types/easyswitch.d.lua  — module entry + Switch options + event names
--   types/Switch.d.lua      — Switch instance methods
-- Pattern primitives (`P.*`) live in matchigo's own types/ folder
-- (vendored at build time). Use those for `EasySwitch.P.*` annotations.
-- ────────────────────────────────────────────────────────────────────────

---Names accepted by `Switch:on(event, callback)`. Unknown names raise.
---@alias easyswitch.Event
---| "beforeExecute"     # fired right before the cache + dispatch pipeline
---| "afterExecute"      # fired after dispatch with `(value, result)` ; also fires on cache HIT
---| "error"             # fired with `(stage, errorValue)` when an action / middleware errors (stage : "action" | "middleware")
---| "middlewareStart"   # fired with `(value)` before the middleware chain runs
---| "middlewareEnd"     # fired with `(transformed_value)` after middlewares run
---| "noMatch"           # fired with `(value)` when nothing handled the value
---| "beforeCheckFailed" # fired with `(value)` when the `:before(check)` gate returned false

---Options passed to `EasySwitch.new(...)` / `EasySwitch("name", ...)`.
---@class easyswitch.SwitchOptions
---@field safe? boolean  When true, action errors are caught and emit `error` event ; default false (errors propagate).

---Options for `Switch:memoize(opts?)`.
---@class easyswitch.MemoizeOptions
---@field verify? boolean  When true, every cache HIT re-runs the pipeline and errors on divergence ; dev-only safety net (slow).

-- ── Module API ─────────────────────────────────────────────────────────

---@class easyswitch
---@overload fun(name: string, options?: easyswitch.SwitchOptions): easyswitch.Switch
local M = {}

---Create an anonymous switch. Returns a fresh `Switch` instance with its
---own dispatcher / events / middleware / registry slot. No global state.
---@param options? easyswitch.SwitchOptions
---@return easyswitch.Switch
function M.new(options) end

---matchigo's pattern vocabulary, exposed unchanged. See matchigo's own
---types/P.d.lua for the full surface.
---@type matchigo.P
M.P = nil

---Parse a DSL string into a P descriptor. Same call as
---`matchigo.parsePattern`. Useful for pre-parsing patterns once and
---reusing them across switches.
---@param src string
---@param scope? table  PascalCase ref bindings (e.g. `{ Num = P.number }`)
---@param ctx? table    `$interp` values
---@return matchigo.Pattern
function M.parsePattern(src, scope, ctx) end

---Sentinel returned by an action to tell the dispatcher "I handled this,
---but keep looking for the next match". Useful for layering rules :
---a literal action that runs side effects then falls through to a
---pattern action that returns the result.
---@type any
M.FALLTHROUGH = nil

---@type matchigo.MapModule
M.Map = nil

---@type matchigo.SetModule
M.Set = nil

---@type matchigo.BigIntModule
M.BigInt = nil

-- ── Named registry ────────────────────────────────────────────────────

---Look up a registered switch by name, or all switches when called
---without args. The all-switches form returns `(table, count)` where
---table is keyed by name ; returns `nil, 0` when the registry is empty.
---@overload fun(): table?, integer
---@param name string
---@return easyswitch.Switch?
function M.get(name) end

---Remove one switch by name, or wipe the whole registry when called
---without args.
---@param name? string
function M.clear(name) end

return M
