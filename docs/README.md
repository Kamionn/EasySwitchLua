# EasySwitchLua — Documentation

A builder-style switch / pattern-matching library for Lua. Thin wrapper around [matchigo-lua](https://github.com/SUP2Ak/matchigo-lua) with events, middleware, opt-in memoize, and a named registry.

[← Back to repository root](../README.md)

---

## Start here

- **[Installation](installation.md)** — Lua, FiveM, Roblox, LÖVE2D
- **[Getting started](getting-started.md)** — Your first switch in under 2 minutes
- **[Migration v1 → v2](migration-v1-to-v2.md)** — If you used the previous version

## API reference

- **[Module](api/module.md)** — `EasySwitch.new()`, registry, `P`, `FALLTHROUGH`, `Map` / `Set` / `BigInt`
- **[Switch instance](api/switch.md)** — Every method on the switch (`:when`, `:execute`, `:memoize`, ...)
- **[Events](api/events.md)** — All seven events with their payloads
- **[Patterns](api/patterns.md)** — Curated `P.*` reference

## Guides

- **[Pattern matching](guides/pattern-matching.md)** — Bare tables, `P.shape`, unions, intersections
- **[DSL strings](guides/dsl-strings.md)** — Detection rules, scope tables, common pitfalls
- **[Memoize](guides/memoize.md)** — When to opt in, verify mode, auto-invalidation
- **[Middleware](guides/middleware.md)** — Chain semantics, error isolation
- **[Fallthrough](guides/fallthrough.md)** — `FALLTHROUGH` sentinel + propagation
- **[Named registry](guides/named-registry.md)** — Anonymous vs named instances

## Examples

- **[HTTP router](examples/http-router.md)** — Method + path dispatch
- **[Game state machine](examples/game-state.md)** — LÖVE2D-style states + transitions
- **[FiveM job dispatch](examples/fivem-job-dispatch.md)** — Realistic FiveM resource

---

## Quick reference

```lua
local EasySwitch = require("easyswitch")
local P = EasySwitch.P

local sw = EasySwitch.new()
    :when("GET",        function() return "list"   end)        -- literal
    :when({"POST", "PUT"}, function(m) return "write:" .. m end)  -- array of literals
    :when(P.string,     function(v) return "str:" .. v end)    -- pattern
    :when(P.number, function(n) return n > 0 end,
                    function() return "positive number" end)    -- guard
    :when("'DELETE' | 'PATCH'", function(m) return "modify" end)  -- DSL string
    :default(function() return "fallback" end)
    :on("noMatch", function(v) print("unhandled:", v) end)
    :memoize()                                                  -- opt-in cache

print(sw:execute("GET"))
```

## License

[MIT](../LICENSE)
