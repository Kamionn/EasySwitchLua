# Guide — Middleware

[← Docs index](../README.md) · [Switch:use API](../api/switch.md#switchuse-middleware)

Middlewares transform the input value **before** it reaches the dispatcher. They run between the gate (`:before`) and the dispatcher itself, in declaration order.

```lua
local sw = EasySwitch.new()
    :use(function(v) return string.lower(v) end)   -- normalise case
    :use(function(v) return v:gsub("%s+", "_") end) -- spaces → underscores
    :when("hello_world", function() return "matched!" end)

sw:execute("Hello World")   -- "matched!"
```

---

## When to use middleware

- **Normalisation** — lowercase, trim, encode.
- **Coercion** — `tonumber`, JSON parsing, type adjustments.
- **Augmentation** — adding default fields to incoming tables.
- **Logging** — before/after observation (though events are usually a better fit).

If your transform is per-rule (e.g. only one rule needs the lowercased value), do the transform inside the action instead. Middleware is for cross-cutting concerns shared by all rules.

---

## Chain semantics

Middlewares run in declaration order. Each receives the current value, returns the new one (or `nil` to keep the prior).

```lua
sw:use(function(v) return v .. "1" end)
sw:use(function(v) return v .. "2" end)
sw:use(function(v) return v .. "3" end)

sw:when("hello123", function() return "match" end)
sw:execute("hello")  -- "match"
```

The return value of each middleware feeds the next.

### Returning `nil` keeps the prior value

```lua
sw:use(function(v)
    if some_condition() then return nil end   -- skip this transform
    return v .. "!"
end)
```

This is useful when a middleware is conditional — returning `nil` means "no change", not "discard the value".

---

## Error isolation

Errors inside a middleware are caught by EasySwitch :

- The `error` event fires with `("middleware", error_value)` (when listened).
- The prior value is preserved (the failed middleware is treated as a no-op).
- The chain continues with the next middleware.

```lua
local sw = EasySwitch.new()
    :on("error", function(stage, err) print("error in", stage, ":", err) end)
    :use(function(v) return v:upper() end)
    :use(function(_) error("middleware 2 boom") end)
    :use(function(v) return v .. "!" end)
    :when("HELLO!", function() return "match" end)

sw:execute("hello")
-- error in middleware : ...middleware 2 boom...
-- "match"   ← matched, because middleware 2's failure preserved "HELLO" then 3 appended "!"
```

> [!IMPORTANT]
> This isolation is intentional but can hide bugs in production. Subscribe to the `error` event in dev to surface middleware failures :
> ```lua
> sw:on("error", function(stage, err) log_error(stage, err) end)
> ```

---

## Events around the chain

Two events bracket the middleware chain (only fire when at least one middleware is registered) :

- **`middlewareStart(value)`** — fires before the first middleware runs.
- **`middlewareEnd(transformed_value)`** — fires after all middlewares ran.

Use them for instrumentation :

```lua
sw:on("middlewareStart", function(v) print("→ chain in :",  v) end)
sw:on("middlewareEnd",   function(v) print("← chain out :", v) end)
```

> [!TIP]
> When the middleware chain is empty (no `:use()` calls), the dispatcher is called directly with the raw input value — neither event fires. Memoize / event paths skip the middleware step entirely in that case.

---

## Order matters

```lua
:use(function(v) return v:lower() end)        -- 1. lowercase
:use(function(v) return v:gsub("%s+", "_") end) -- 2. spaces → underscores
```

Switching the order would lowercase first then replace spaces, which is fine. But :

```lua
:use(function(v) return v:upper() end)    -- 1. uppercase
:use(function(v) return v:lower() end)    -- 2. lowercase
```

The second middleware undoes the first. The dispatcher receives the lowercased value, regardless of what the first one did.

---

## Common patterns

### Coerce input to a known shape

```lua
local sw = EasySwitch.new()
    :use(function(v)
        if type(v) == "string" then return tonumber(v) or v end
        return v
    end)
    :when(P.number, num_handler)
    :when(P.string, fallback_str_handler)
```

### Wrap context

```lua
sw:use(function(v)
    return { input = v, timestamp = os.time(), userId = current_user_id() }
end)
sw:when({ input = P.string }, ...)  -- pattern match against the wrapper
```

### Tracing without events

```lua
sw:use(function(v)
    log_trace("dispatch input:", v)
    return v   -- or return nil — both keep the value
end)
```

The `error` event still applies if your trace logger throws.

---

## Memoize and middleware

The memoize cache stores results **keyed by the original input**, before any middleware ran. So if your middleware is non-deterministic (e.g. injects `os.time()`), the dispatcher sees different values each call, but the cache only sees the original input.

```lua
local sw = EasySwitch.new():memoize()
    :use(function(v) return v .. ":" .. os.time() end)   -- non-deterministic
    :when(P.luaPattern("^cmd:"), function(v) return v end)

sw:execute("cmd")
-- 1st call : middleware adds ":1714828512" → action returns "cmd:1714828512" → cached as cache["cmd"]
sw:execute("cmd")
-- 2nd call : cache HIT, returns "cmd:1714828512" — but middleware would have produced ":1714828513"!
```

This is a non-determinism bug at the **switch** level (caching shadows middleware). Use `:memoize({ verify = true })` in dev to catch it, or move the timestamp injection inside the action where the user can decide whether to memoize separately.

See **[Memoize guide](memoize.md)**.

---

## See also

- **[Switch:use API](../api/switch.md#switchuse-middleware)** — method signature
- **[Events API : `error`](../api/events.md#error)** — middleware error payload
- **[Memoize guide](memoize.md)** — interaction with non-deterministic middlewares
