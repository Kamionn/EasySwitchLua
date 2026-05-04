# Getting started

[← Docs index](README.md)

This page walks through the core concepts in under 5 minutes. By the end you'll have a working switch with literal dispatch, patterns, a default fallback, and one event listener.

---

## Step 1 — Create a switch

```lua
local EasySwitch = require("easyswitch")

local sw = EasySwitch.new()
```

`EasySwitch.new()` returns a fresh switch instance. It has no rules yet — calling `:execute(value)` on it would just return `nil`.

> [!TIP]
> Always prefer `EasySwitch.new()` (anonymous) over `EasySwitch("name")` (registry) unless you specifically need to look the switch up by name from somewhere else. See **[Named registry](guides/named-registry.md)** for the registry use case.

---

## Step 2 — Add rules

Use `:when(cases, action)` to register a rule. Multiple call shapes are accepted :

```lua
sw:when("GET",       function() return "list"     end)  -- single literal
sw:when({"POST", "PUT"}, function(m) return "write:" .. m end)  -- array of literals (one action)
sw:when(EasySwitch.P.string, function(v) return "str:" .. v end)  -- pattern
```

Rules are processed in this order on every `:execute(value)` :

1. **Literal hash lookup** (O(1)) — if `value` is a literal that was registered, fire that action.
2. **Pattern walk** (in declaration order) — try each pattern rule until one matches.
3. **Default** (if set) — fires when nothing else matched.

The first matching rule wins — unless its action returns `EasySwitch.FALLTHROUGH` (see **[Fallthrough](guides/fallthrough.md)**).

---

## Step 3 — Add a fallback

```lua
sw:default(function(v) return "unknown: " .. tostring(v) end)
```

`:default(action)` registers the fallback action that fires only when no rule matched. It takes the original input value as its argument.

---

## Step 4 — Execute

```lua
print(sw:execute("GET"))      -- list
print(sw:execute("POST"))     -- write:POST
print(sw:execute("hello"))    -- str:hello
print(sw:execute(42))         -- unknown: 42
```

`:execute(value)` runs the dispatch pipeline and returns the matched action's result.

---

## Step 5 — Add an event listener

```lua
sw:on("noMatch", function(v) print("[warn] no rule for:", v) end)

sw:execute(true)  -- prints "[warn] no rule for: true" then returns "unknown: true"
```

`:on(event, callback)` subscribes to one of the seven [events](api/events.md). The `noMatch` event fires when nothing handled the value (the default still runs, but you get a chance to log / observe).

---

## Step 6 — Make it fluent

Every builder method returns `self`, so you can chain everything :

```lua
local sw = EasySwitch.new()
    :when("GET",         function() return "list"     end)
    :when({"POST", "PUT"},   function(m) return "write:" .. m end)
    :when(EasySwitch.P.string, function(v) return "str:" .. v end)
    :default(function(v) return "unknown: " .. tostring(v) end)
    :on("noMatch", function(v) print("[warn] no rule for:", v) end)
```

That's the full builder API — you're ready to use EasySwitch productively.

---

## Common next steps

- **Pattern matching** : you've used `P.string` ; the full pattern vocabulary covers shapes, unions, intersections, ranges, predicates, and more. See **[Patterns reference](api/patterns.md)** and **[Pattern matching guide](guides/pattern-matching.md)**.

- **DSL strings** : write patterns as Rust-style strings inside `:when()` :
    ```lua
    sw:when("'DELETE' | 'PATCH'", function(m) return "modify:" .. m end)
    sw:when("{| kind: 'click', x: Num, y: Num |}", { Num = P.number },
            function(c) return ("at %d,%d"):format(c.x, c.y) end)
    ```
    See **[DSL strings guide](guides/dsl-strings.md)**.

- **Memoize** : opt-in cache for expensive deterministic actions :
    ```lua
    local sw = EasySwitch.new():memoize()
    ```
    See **[Memoize guide](guides/memoize.md)**.

- **Middleware** : transform values before dispatch :
    ```lua
    sw:use(function(v) return string.lower(v) end)
    ```
    See **[Middleware guide](guides/middleware.md)**.

- **Coming from v1** : if you used the previous EasySwitch version (with `cacheManager`, `actionManager`, `P.any_of`, ...), read the **[Migration v1 → v2 guide](migration-v1-to-v2.md)** first.
