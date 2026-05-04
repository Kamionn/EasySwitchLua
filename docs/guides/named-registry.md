# Guide — Named registry

[← Docs index](../README.md) · [Module API](../api/module.md)

EasySwitch ships two ways to create a switch :

```lua
local sw = EasySwitch.new()        -- anonymous
local sw = EasySwitch("menu")      -- named, registered globally
```

Both return an identical Switch instance. The difference is whether the instance is reachable by name from elsewhere in your code.

---

## Anonymous (recommended default)

`EasySwitch.new()` returns a fresh switch. Nothing else in the codebase can find it unless you explicitly pass it around. Best for :

- **Module-local switches** — defined and used in the same file.
- **Function-scoped dispatch** — created inside a function, used immediately, GC'd when out of scope.
- **Testability** — no global state means tests don't leak between runs.

```lua
-- handlers.lua
local EasySwitch = require("easyswitch")

local handler = EasySwitch.new()
    :when("ping", function() return "pong" end)
    :when(EasySwitch.P.string, function(v) return "echo:" .. v end)

return handler   -- explicit export
```

---

## Named (registry mode)

`EasySwitch("name")` creates and registers a switch under that name. Any module can later retrieve it via `EasySwitch.get("name")` :

```lua
-- bootstrap.lua
local EasySwitch = require("easyswitch")

EasySwitch("menu")
    :when("start", function() return "Game started" end)
    :when("quit",  function() return "Game ended"   end)
```

```lua
-- somewhere_else.lua
local EasySwitch = require("easyswitch")

local menu = EasySwitch.get("menu")
print(menu:execute("start"))
```

Use the registry when :

- **You can't easily pass the switch around** — e.g. FiveM event handlers in different files that all need the same dispatcher.
- **You're integrating with a framework that calls you back** — the registry gives you a stable handle.
- **You're prototyping** — you can `EasySwitch("test")` from a Lua console and rebuild without rewiring imports.

> [!TIP]
> Don't reach for the registry as a default. Anonymous + explicit `require`-and-export keeps your dependency graph clear. The registry is a tool for cases where dependency injection would be cumbersome.

---

## API surface

```lua
EasySwitch(name, options?)         -- create + register
EasySwitch.get(name)                -- retrieve by name
EasySwitch.get()                    -- retrieve all : returns (table, count)
EasySwitch.clear(name)              -- unregister one
EasySwitch.clear()                  -- wipe registry
```

### Duplicate registration throws

```lua
EasySwitch("menu"):when(...)
EasySwitch("menu"):when(...)   -- ⚠ throws "Switch [menu] is already registered"
```

If you intend to replace, clear first :

```lua
EasySwitch.clear("menu")
local menu = EasySwitch("menu"):when(...)
```

### Iterating all switches

```lua
local all, count = EasySwitch.get()   -- returns (nil, 0) when empty

if all then
    for name, sw in pairs(all) do
        print(name, "→", sw)
    end
    print("total:", count)
end
```

The iteration order is **insertion order** — the registry is backed by matchigo's `Map` (linked list, not hash). Useful when dumping state for logging.

> [!NOTE]
> `EasySwitch.registered` is **not** part of v2's public API (it existed in v1 as a raw table). Use `EasySwitch.get()` instead — it returns a fresh copy that's safe to iterate / mutate without affecting the live registry.

---

## Hot-reload pattern

When developing with hot-reload (FiveM scripts, LÖVE2D, Roblox), the registry persists across module reloads. You'll typically want to wipe and re-register :

```lua
-- on_reload.lua
EasySwitch.clear()        -- wipe everything

-- ... re-register all your switches ...
EasySwitch("menu"):when(...)
EasySwitch("game"):when(...)
```

Or per-switch :

```lua
EasySwitch.clear("menu")  -- only wipe menu
local menu = EasySwitch("menu"):when(...)
```

> [!IMPORTANT]
> Old references to the previous instance are still alive after `clear`. If you cache a switch in another module's local variable, that variable points to the **stale** switch. Always retrieve via `EasySwitch.get` at use time, or wire up a fresh reference after each reload.

---

## Anonymous + exported vs named registry — when to pick what

| Situation | Recommendation |
|---|---|
| Module-local dispatch | **Anonymous** + return / export |
| Cross-module dispatch (single project, you control imports) | **Anonymous** + explicit dependency injection |
| Cross-module dispatch (framework-driven, callbacks fire from anywhere) | **Named** registry |
| Quick console / REPL experimentation | **Named** registry |
| Hot-reloaded code (FiveM, LÖVE2D) | **Named** registry + manual `clear` on reload |
| Test setup / teardown | **Anonymous** (no leakage between tests) |

---

## Performance

Switch lookup via `EasySwitch.get(name)` is O(1) (hash). The registry adds **zero overhead** to anonymous switches — `EasySwitch.new()` doesn't touch the registry table.

Per-instance, named and anonymous switches are byte-for-byte identical in memory and method dispatch cost. The only difference is the entry in the global Map.

---

## See also

- **[`EasySwitch(name, options)`](../api/module.md#easyswitchname-options--registry-mode)** — full method reference
- **[`EasySwitch.get`](../api/module.md#easyswitchget-name)** — lookup
- **[`EasySwitch.clear`](../api/module.md#easyswitchclear-name)** — unregister
