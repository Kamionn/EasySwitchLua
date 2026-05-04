# EasySwitchLua

[![CI](https://github.com/SUP2Ak/EasySwitchLua/actions/workflows/ci.yml/badge.svg)](https://github.com/SUP2Ak/EasySwitchLua/actions/workflows/ci.yml) [![focus](https://img.shields.io/badge/focus-Switch%20%2F%20Dispatcher-purple)](https://img.shields.io/badge/focus-Switch%20%2F%20Dispatcher-purple) [![lang](https://img.shields.io/badge/lang-Lua%205.1%2B%20%2F%20LuaJIT-green)](https://img.shields.io/badge/lang-Lua%205.1%2B%20%2F%20LuaJIT-green) [![license](https://img.shields.io/badge/license-MIT-blue)](./LICENSE)

A builder-style switch / pattern-matching library for Lua with middleware, events, opt-in memoize, and structural dispatch. Built on top of [matchigo-lua](https://github.com/SUP2Ak/matchigo-lua) (vendored in the bundle) for pattern-test logic and the optional Rust-style DSL.

Works on standard Lua 5.1+, LuaJIT, FiveM, Roblox (Luau), and LÖVE2D.

📖 **[Full documentation in `docs/`](docs/README.md)** — installation, API reference, guides, examples, v1→v2 migration.

---

## Installation

### Standard Lua

```lua
local EasySwitch = require("easyswitch")
```

### FiveM

Build a single bundled file (no `require` calls, runs anywhere):

```bash
lua build.lua
# → generates dist/easyswitch.lua
```

Copy `dist/easyswitch.lua` into your resource, then in `fxmanifest.lua`:

```lua
shared_scripts {
    'easyswitch.lua',
    'client.lua',
    'server.lua',
}
```

`EasySwitch` is then available in all your scripts without any `require`.

### Roblox

1. Run `lua build.lua` to generate `dist/easyswitch.lua`.
2. In Roblox Studio, create a `ModuleScript` in `ReplicatedStorage` named `EasySwitch`.
3. Paste the full content of `dist/easyswitch.lua` into it.
4. Use it from any script:

```lua
local EasySwitch = require(game.ReplicatedStorage.EasySwitch)

local sw = EasySwitch.new()
    :when("attack", function() print("attacking!") end)
    :when("defend", function() print("defending!") end)
    :default(function(v) print("unknown action:", v) end)

sw:execute("attack")
```

The bundled file has no external `require()` calls and is fully compatible with Luau's sandbox.

### LÖVE2D

Copy the `src/` folder and `easyswitch.lua` into your LÖVE project (or use the single bundled `dist/easyswitch.lua`):

```lua
-- main.lua
local EasySwitch = require("easyswitch")

local gameState = EasySwitch.new()
    :when("menu",  function() -- draw menu  end)
    :when("game",  function() -- draw game  end)
    :when("pause", function() -- draw pause end)

function love.keypressed(key)
    if key == "escape" then gameState:execute("pause") end
end
```

LÖVE runs on LuaJIT (Lua 5.1) — no configuration needed, everything works out of the box.

---

## Two modes: anonymous and named

```lua
-- Anonymous (recommended) — zero global state
local sw = EasySwitch.new()

-- Named registry — accessible from anywhere by name
local sw = EasySwitch("menu")
local sw = EasySwitch.get("menu")  -- retrieve it later
```

---

## Basic usage

```lua
local EasySwitch = require("easyswitch")

local sw = EasySwitch.new()
    :when("start", function() return "Game started" end)
    :when("quit",  function() return "Game ended"   end)
    :default(function(v) return "Unknown: " .. v    end)

sw:execute("start")  -- "Game started"
sw:execute("quit")   -- "Game ended"
sw:execute("other")  -- "Unknown: other"
```

### Multiple literals, one action

```lua
sw:when({"save", "backup"}, function(v) return "Saving..." end)
```

---

## Pattern matching

```lua
local P = EasySwitch.P
```

### Type sentinels

| Pattern | Matches |
|---|---|
| `P.string` | any string |
| `P.number` | any number |
| `P.boolean` | `true` or `false` |
| `P.integer` | whole numbers |
| `P.float` | decimal numbers |
| `P.func` | any function |
| `P.nullish` | `nil` |
| `P.defined` | any non-nil value |
| `P.any` | everything |

```lua
sw:when(P.string,  function(v) return "got string: " .. v end)
sw:when(P.integer, function(v) return "got int: " .. v    end)
sw:when(P.float,   function(v) return "got float: " .. v  end)
```

### P.when — arbitrary predicate

```lua
sw:when(P.when(function(v) return v > 0 end), function() return "positive" end)
```

### P.union / P.anyOf — disjunction

`P.union(...)` is the literal-only union (hash O(1) lookup). `P.anyOf(...)` accepts any pattern, walks linearly :

```lua
sw:when(P.union("red", "green", "blue"), function(v) return "color: " .. v end)
sw:when(P.anyOf(P.integer, P.string),    function() return "int or string"  end)
```

### P.not_ — negation

```lua
sw:when(P.not_(P.string), function() return "not a string" end)
```

### P.intersection — all-must-match

All patterns must match :

```lua
sw:when(P.intersection(P.number, P.when(function(v) return v > 0 end)),
        function() return "positive number" end)

sw:when(P.intersection(P.integer, P.between(1, 100)),
        function() return "integer between 1 and 100" end)
```

### P.between — numeric range (inclusive)

```lua
sw:when(P.between(1, 10),  function() return "low"    end)
sw:when(P.between(11, 20), function() return "medium" end)
sw:when(P.between(21, 99), function() return "high"   end)
```

### P.array / P.arrayOf — homogeneous array

`P.array(item)` matches a sequential table where every element matches `item`. The empty table `{}` matches **vacuously** (no counterexample) — same semantics as `arr.every(...)` in JS, `iter.all(...)` in Rust.

```lua
sw:when(P.array(P.number), function() return "array of numbers" end)
```

If you want to reject empty arrays, use `P.arrayOf(item, { min = 1 })` :

```lua
sw:when(P.arrayOf(P.string, { min = 1, max = 100 }), function() return "1..100 strings" end)
```

### P.luaPattern — Lua string pattern match

```lua
sw:when(P.luaPattern("^/api/"), function() return "api route"  end)
sw:when(P.luaPattern("^/web/"), function() return "web route"  end)
sw:when(P.luaPattern("%d+"),    function() return "has digits"  end)
```

### Partial table matching

A plain table with string keys acts as a partial matcher — extra keys are ignored:

```lua
sw:when({ kind = "circle" }, function(s) return math.pi * s.r ^ 2 end)
sw:when({ kind = "square" }, function(s) return s.side ^ 2         end)

sw:execute({ kind = "circle", r = 5 })  -- 78.539...
```

Patterns can be nested:

```lua
sw:when({ pos = { x = P.number, y = P.number } }, function() return "vec2" end)
```

### P.shape — strict table matching

Like partial matching, but rejects tables with extra keys:

```lua
-- partial: { active=true, score=100 } would match
sw:when({ active = true }, function() return "partial" end)

-- strict: { active=true, score=100 } does NOT match
sw:when(P.shape({ active = true }), function() return "strict" end)
```

### DSL strings in `:when()`

A string starting with `{`, `[`, `(`, `'` or `"` is parsed as a [matchigo DSL pattern](https://github.com/SUP2Ak/matchigo-lua) — anything else stays a literal. Pass a scope table as the 2nd arg to force DSL parsing and resolve PascalCase refs :

```lua
sw:when("'GET' | 'POST' | 'PUT'", function(m) return "method:" .. m end)
sw:when("{| kind: 'click', x: Num, y: Num |}", { Num = P.number },
        function(c) return ("at %d,%d"):format(c.x, c.y) end)
```

Full DSL grammar lives in matchigo's docs ; a dedicated `docs/` folder will land here later.

---

## Guards

3-argument `:when(pattern, guard, action)` — the guard receives the value and must return `true` for the action to run:

```lua
sw:when(P.number, function(v) return v > 0  end, function() return "positive" end)
sw:when(P.number, function(v) return v <= 0 end, function() return "non-positive" end)

-- Also works on literals
sw:when("hello", function(v) return #v == 5 end, function() return "five-letter hello" end)
```

---

## Fallthrough

Return `EasySwitch.FALLTHROUGH` from an action to continue matching subsequent cases:

```lua
local sw = EasySwitch.new()

sw:when("hello", function()
    print("intercepted hello")
    return EasySwitch.FALLTHROUGH  -- continue to next match
end)
sw:when(P.string, function(v)
    return "string: " .. v
end)

sw:execute("hello")
-- prints "intercepted hello"
-- returns "string: hello"
```

---

## Middleware

Middleware transforms the value before dispatch. Errors inside a middleware are caught and the original value is used as fallback:

```lua
local sw = EasySwitch.new()
    :use(function(v) return string.upper(v) end)
    :when("HELLO", function() return "matched" end)

sw:execute("hello")  -- "matched"
```

Multiple middlewares chain in order:

```lua
sw:use(function(v) return v:gsub("%s+", "_") end)  -- spaces → underscores
sw:use(function(v) return string.lower(v)    end)  -- lowercase
```

---

## Before check

Gates the entire execution — if the check returns `false`, `execute` returns `nil` immediately:

```lua
local sw = EasySwitch.new()
    :before(function(v) return type(v) == "string" end)
    :when("ok", function() return "passed" end)

sw:execute("ok")   -- "passed"
sw:execute(42)     -- nil (before check failed)
```

---

## Events

```lua
sw:on("beforeExecute",     function(value)           end)
sw:on("afterExecute",      function(value, result)   end)
sw:on("error",             function(origin, message) end)
sw:on("middlewareStart",   function(value)           end)
sw:on("middlewareEnd",     function(result)          end)
sw:on("noMatch",           function(value)           end)
sw:on("beforeCheckFailed", function(value)           end)
```

Example — logging:

```lua
local sw = EasySwitch.new()
    :on("beforeExecute", function(v)    print("in  →", v)          end)
    :on("afterExecute",  function(v, r) print("out →", r)          end)
    :on("noMatch",       function(v)    print("no match for", v)    end)
    :on("error",         function(o, e) print("error in", o, ":", e) end)
```

---

## Memoize (opt-in)

No implicit cache. Call `:memoize()` to opt in — results are then cached by input value (weak refs, GC-friendly). Pattern hits and literal hits are both cached. `nil` results aren't cached so adding a new rule afterwards isn't shadowed by a stale miss.

```lua
local sw = EasySwitch.new():memoize()
    :when("calc", function()
        local r = 0
        for i = 1, 1e6 do r = r + i end
        return r
    end)

sw:execute("calc")  -- computed
sw:execute("calc")  -- cache HIT, action not re-run
```

Mutating the switch (`:when`, `:default`, `:use`, `:before`) auto-invalidates the cache so a new rule never runs against stale entries. Clear manually with :

```lua
sw:clearCache()
```

For dev / debugging, pass `{ verify = true }` — every cache HIT re-runs the pipeline and errors on divergence (catches non-deterministic actions). Slow, do not ship to prod with verify on.

```lua
local sw = EasySwitch.new():memoize({ verify = true })
```

---

## Named registry

```lua
-- Create
local sw = EasySwitch("my-switch")

-- Retrieve by name
local sw = EasySwitch.get("my-switch")

-- Get all registered switches
local all, count = EasySwitch.get()

-- Remove one
EasySwitch.clear("my-switch")

-- Remove all
EasySwitch.clear()
```

---

## Configuration

```lua
local sw = EasySwitch.new({ safe = true })
-- or
local sw = EasySwitch("name", { safe = true })
```

| Option | Default | Description |
|---|---|---|
| `safe` | `false` | Wrap action execution in a `pcall`. On error, the `error` event fires (when listened) and `:execute()` returns `nil` instead of propagating. Off by default — errors propagate like in matchigo. |

---

## Full example — LÖVE2D game state machine

```lua
local EasySwitch = require("easyswitch")
local P = EasySwitch.P

local state = EasySwitch.new()
    :on("noMatch", function(v) print("[warn] unknown state:", v) end)
    :when("menu",  function() love.graphics.print("MENU",  10, 10) end)
    :when("game",  function() love.graphics.print("GAME",  10, 10) end)
    :when("over",  function() love.graphics.print("GAME OVER", 10, 10) end)
    :default(function() love.graphics.print("???", 10, 10) end)

local current = "menu"

function love.draw()
    state:execute(current)
end

function love.keypressed(key)
    if key == "return" and current == "menu" then current = "game"
    elseif key == "escape"                   then current = "over"
    end
end
```

---

## Full example — FiveM job dispatch

```lua
local P = EasySwitch.P

local jobSwitch = EasySwitch.new()
    :when(P.luaPattern("^police"),    function(job) return "PD — " .. job     end)
    :when(P.luaPattern("^mechanic"),  function(job) return "Garage — " .. job end)
    :when(P.union("ambulance", "doctor"), function() return "EMS"             end)
    :when(P.intersection(P.string, P.when(function(v) return #v > 0 end)),
          function(job) return "Civilian — " .. job end)
    :default(function() return "No job" end)

jobSwitch:execute("police_lspd")  -- "PD — police_lspd"
jobSwitch:execute("ambulance")    -- "EMS"
jobSwitch:execute("baker")        -- "Civilian — baker"
```

---

## License

[MIT](LICENSE)
