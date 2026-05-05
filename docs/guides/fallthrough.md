# Guide — Fallthrough

[← Docs index](../README.md) · [EasySwitch.FALLTHROUGH](../api/module.md#easyswitchfallthrough)

By default, the **first matching rule wins** : its action runs, the result is returned, dispatch ends. Fallthrough lets a rule "match but not stop" — useful when you want a side effect AND a final result from different rules.

```lua
sw:when("admin", function()
    audit_log("admin command issued")
    return EasySwitch.FALLTHROUGH    -- log AND keep dispatching
end)
sw:when(P.string, function(v)
    return execute_command(v)
end)

sw:execute("admin")
-- 1. fires the audit_log
-- 2. continues to the P.string rule
-- 3. returns execute_command("admin")
```

---

## How it works

Whenever an action's return value is the special `EasySwitch.FALLTHROUGH` sentinel, the dispatcher :

1. Notes "something matched" (so the `noMatch` event won't fire).
2. **Discards** the return value — it's not propagated as the dispatch result.
3. **Continues** to the next pattern in declaration order.

If a later rule produces a non-FALLTHROUGH result, that's the dispatch result. If everything fell through and no further rule matched, the default fires (or `nil` is returned).

---

## Use cases

### Layered side effects + final value

```lua
sw:when({ kind = "click" }, function(c)
    metrics:increment("click_count")
    return EasySwitch.FALLTHROUGH
end)
sw:when({ kind = "click", x = P.number, y = P.number }, function(c)
    return ("click at %d,%d"):format(c.x, c.y)
end)
```

The first rule runs metrics for any click ; the second produces the formatted result for typed clicks.

### Conditional rule "skip"

A guard returning false would mean the rule didn't match at all. FALLTHROUGH means it matched but explicitly chose not to terminate :

```lua
sw:when(P.string, function(v)
    if not should_handle(v) then
        return EasySwitch.FALLTHROUGH    -- skip to next rule
    end
    return handle(v)
end)
sw:when(P.string, function(v) return fallback(v) end)
```

This is similar to a guard but lets you do work before deciding to skip.

### Chaining audit / logging rules

```lua
sw:when(P.any, function(v) log("input:", v); return EasySwitch.FALLTHROUGH end)
sw:when("ping", function() return "pong" end)
sw:when(P.string, function(v) return "echo: " .. v end)
sw:when(P.number, function(n) return n * 2 end)
sw:default(function() return "?" end)
```

The audit rule sees every input then falls through to the actual dispatch logic.

---

## How it interacts with other features

### `noMatch` event

`noMatch` only fires when **literally nothing matched** — including patterns whose actions returned FALLTHROUGH. As long as at least one rule matched (regardless of whether it kept dispatch going), `noMatch` is suppressed.

```lua
sw:when("trace", function() return EasySwitch.FALLTHROUGH end)
-- no other rules

sw:on("noMatch", function() print("no match") end)

sw:execute("trace")  -- "trace" matched and fell through
-- result : nil
-- noMatch event : NOT fired (something did match)
```

If you want `noMatch`-style logging to fire even on fallthrough-only matches, do it in the action itself or in `afterExecute`.

### `:default(action)`

The default fires when nothing produced a result, including the case where every match returned FALLTHROUGH :

```lua
sw:when("x", function() return EasySwitch.FALLTHROUGH end)
sw:default(function(v) return "default: " .. v end)

sw:execute("x")  -- "default: x" — fell through to default
```

### Memoize cache

The cache stores the **final** result of `:execute()`, not the intermediate FALLTHROUGH-returning result. Hitting the cache later skips the entire dispatch chain — no audit log, no fallthrough, just the cached value :

```lua
local sw = EasySwitch.new():memoize()
sw:when(P.any, function(v)
    print("audit:", v)
    return EasySwitch.FALLTHROUGH
end)
sw:when(P.string, function(v) return "result:" .. v end)

sw:execute("hi")
-- audit: hi
-- → returns "result:hi", cached

sw:execute("hi")
-- → cache HIT, returns "result:hi" — audit log does NOT fire
```

If you need the audit on every call, **don't memoize** that switch (or move the audit to a middleware / event listener that runs before the cache check).

### Map literal vs pattern walk

The Map fast-path is checked **first** — if a literal hit returns FALLTHROUGH, dispatch continues to the **pattern walk** (and only then to default).

```lua
sw:when("foo", function() return EasySwitch.FALLTHROUGH end)   -- Map literal
sw:when(P.string, function(v) return "pat:" .. v end)          -- Pattern

sw:execute("foo")  -- "pat:foo" — literal fell through to pattern
```

A literal that doesn't return FALLTHROUGH (returns its actual value) terminates dispatch as usual ; pattern rules never see it.

---

## Common pitfalls

### Forgot to `return` the sentinel

```lua
sw:when("x", function()
    do_work()
    EasySwitch.FALLTHROUGH    -- ⚠ MISSING return
end)
```

Without `return`, the action returns `nil`. The dispatcher sees `nil` (a real value, not FALLTHROUGH), terminates dispatch, and `:execute()` returns `nil`. Always `return EasySwitch.FALLTHROUGH`, never just write it.

### Using FALLTHROUGH as a guard

If the "skip this rule" decision is based purely on the input value, prefer the 3-arg guard form :

```lua
-- Less idiomatic
sw:when(P.string, function(v)
    if not predicate(v) then return EasySwitch.FALLTHROUGH end
    return handle(v)
end)

-- More idiomatic — guard short-circuits the test, the action only runs when predicate is true
sw:when(P.string, predicate, handle)
sw:when(P.string, fallback)
```

Guards run as part of the pattern test, so a guard returning false leaves `everMatched = false` for that rule. FALLTHROUGH explicitly marks "I matched, just keep going".

### Multiple FALLTHROUGH chains accumulating side effects

```lua
sw:when(P.any, function() metric_a:inc(); return EasySwitch.FALLTHROUGH end)
sw:when(P.any, function() metric_b:inc(); return EasySwitch.FALLTHROUGH end)
sw:when(P.string, ...)
```

Both `metric_a` and `metric_b` increment for every dispatch. That's the behaviour you asked for, but it scales linearly with the number of FALLTHROUGH rules. Move cross-cutting concerns to `:use(...)` middleware or `:on("beforeExecute", ...)` / `:on("afterExecute", ...)` listeners when they're truly cross-cutting.

---

## See also

- **[`EasySwitch.FALLTHROUGH`](../api/module.md#easyswitchfallthrough)** — sentinel reference
- **[Pattern matching guide](pattern-matching.md)** — dispatch order and rule precedence
- **[Memoize guide](memoize.md)** — what gets cached when fallthrough is involved
