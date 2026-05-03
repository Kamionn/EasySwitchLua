# EasySwitchLua

A performant switch/pattern-matching library for Lua with middleware, events, caching, and structural dispatch.

Works on standard Lua 5.1+, LuaJIT, and FiveM.

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
| `P.table` | any table |
| `P.func` | any function |
| `P.nil_` | `nil` |
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

### P.any_of — union

```lua
sw:when(P.any_of("red", "green", "blue"), function(v) return "color: " .. v end)
sw:when(P.any_of(P.integer, P.string),    function() return "int or string"  end)
```

### P.not_ — negation

```lua
sw:when(P.not_(P.string), function() return "not a string" end)
```

### P.and_ / P.all_of — intersection

All patterns must match:

```lua
sw:when(P.and_(P.number, P.when(function(v) return v > 0 end)),
        function() return "positive number" end)

-- P.all_of is an alias
sw:when(P.all_of(P.integer, P.between(1, 100)),
        function() return "integer between 1 and 100" end)
```

### P.between — numeric range (inclusive)

```lua
sw:when(P.between(1, 10),  function() return "low"    end)
sw:when(P.between(11, 20), function() return "medium" end)
sw:when(P.between(21, 99), function() return "high"   end)
```

### P.array — homogeneous array

Matches a non-empty sequential table where every element matches the given pattern:

```lua
sw:when(P.array(P.number), function() return "array of numbers" end)
sw:when(P.array(P.string), function() return "array of strings" end)
```

### P.string_match — Lua pattern on strings

```lua
sw:when(P.string_match("^/api/"), function() return "api route"  end)
sw:when(P.string_match("^/web/"), function() return "web route"  end)
sw:when(P.string_match("%d+"),    function() return "has digits"  end)
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
sw:on("beforeExecute",     function(value)          end)
sw:on("afterExecute",      function(value, result)   end)
sw:on("error",             function(origin, message) end)
sw:on("cacheHit",          function(value, result)   end)
sw:on("cacheMiss",         function(value)           end)
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

## Caching

Literal dispatch results are cached automatically (weak-key table, GC-friendly). Pattern results are never cached.

```lua
sw:when("calc", function()
    -- runs once, result cached on subsequent calls
    local r = 0
    for i = 1, 1e6 do r = r + i end
    return r
end)

sw:execute("calc")  -- computed
sw:execute("calc")  -- from cache
```

Clear the cache manually:

```lua
sw:clearCache()
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
local sw = EasySwitch.new({ maxCases = 500 })
-- or
local sw = EasySwitch("name", { maxCases = 500 })
```

| Option | Default | Description |
|---|---|---|
| `maxCases` | `100` | Maximum number of registered cases |

---

## Full example — FiveM job dispatch

```lua
local P = EasySwitch.P

local jobSwitch = EasySwitch.new()
    :when(P.string_match("^police"),  function(job) return "PD — " .. job   end)
    :when(P.string_match("^mechanic"),function(job) return "Garage — " .. job end)
    :when(P.any_of("ambulance", "doctor"), function() return "EMS"          end)
    :when(P.and_(P.string, P.when(function(v) return #v > 0 end)),
          function(job) return "Civilian — " .. job end)
    :default(function() return "No job" end)

jobSwitch:execute("police_lspd")  -- "PD — police_lspd"
jobSwitch:execute("ambulance")    -- "EMS"
jobSwitch:execute("baker")        -- "Civilian — baker"
```

---

## License

[MIT](LICENSE)
