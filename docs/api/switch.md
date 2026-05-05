# API — `Switch` instance

[← Docs index](../README.md) · [API : Module](module.md) · [API : Events](events.md) · [API : Patterns](patterns.md)

The `Switch` instance is what `EasySwitch.new(...)` and `EasySwitch("name", ...)` return. All builder methods return `self` for fluent chaining ; `:execute(value)` is the only terminal call.

---

## Pipeline

`:execute(value)` runs this pipeline in order :

1. emit **`beforeExecute`** *(skipped when no listener bound)*
2. **memoize cache lookup** *(only if `:memoize()` was called)* — cache HIT short-circuits the rest, fires `afterExecute` and returns
3. **`:before(...)` gate** — if it returns `false`, fires `beforeCheckFailed` and returns `nil`
4. **middleware chain** — transforms the value
5. **dispatcher** — Map literal lookup → complex pattern walk → default
6. **memoize cache store** *(only if `:memoize()` and result ≠ nil)*
7. emit **`noMatch`** *(only when nothing handled the value)*
8. emit **`afterExecute`** *(skipped when no listener bound)*

---

## `Switch:on(event, callback)`

Subscribe a listener to one of the seven events. Throws on unknown event names — typos are caught at registration time.

| Argument | Type | Description |
|---|---|---|
| `event` | `string` | One of the seven event names (see [Events](events.md)). |
| `callback` | `function` | Receives the event-specific payload. |

| Returns | Type | Description |
|---|---|---|
| `self` | `Switch` | For chaining. |

### Example

```lua
sw:on("noMatch", function(v) print("[warn] unmatched:", v) end)
   :on("error",   function(stage, err) log_error(stage, err) end)
```

See **[Events API](events.md)** for the complete list with payloads.

---

## `Switch:when(cases, action)`

Add a dispatch rule. Three call shapes are accepted depending on the second argument :

### Shape 1 — `:when(cases, action)`

The simplest form. `cases` is matched against the input ; if it matches, `action(input)` runs and its return value is the dispatch result.

| Argument | Type | Description |
|---|---|---|
| `cases` | any | Literal, array of literals, table pattern, P descriptor, or DSL string. |
| `action` | `function` | Called with the matched input value. |

### Shape 2 — `:when(cases, guard, action)` — guard form

Adds a runtime predicate that must return truthy for the action to fire. Useful when the pattern needs to depend on the value's content beyond what `P.*` can express directly.

| Argument | Type | Description |
|---|---|---|
| `cases` | any | Same as shape 1. |
| `guard` | `function` | Called with the input. The action only fires when this returns truthy. |
| `action` | `function` | The action to run when both pattern and guard match. |

```lua
sw:when(P.number, function(n) return n > 0 end, function() return "positive" end)
```

### Shape 3 — `:when(dsl_string, scope, action)` — DSL with scope

When the second argument is a **table**, it's interpreted as a [matchigo scope](../guides/dsl-strings.md) table — `cases` is force-parsed as DSL, and the scope's PascalCase entries resolve refs inside it.

| Argument | Type | Description |
|---|---|---|
| `cases` | `string` | DSL source. |
| `scope` | `table` | PascalCase refs (e.g. `{ Num = P.number, Str = P.string }`). |
| `action` | `function` | Called with the matched value. |

```lua
sw:when("{| kind: 'click', x: Num, y: Num |}", { Num = P.number },
        function(c) return ("at %d,%d"):format(c.x, c.y) end)
```

### `cases` can be

| Type | Behaviour |
|---|---|
| string starting with `{`, `[`, `(`, `'`, `"` | Auto-parsed as DSL pattern |
| any other string | Literal value (Map fast path) |
| number, boolean | Literal value (Map fast path) |
| array `{"a", "b"}` (#cases > 0) | Each element registered as a Map literal (one action shared) |
| dict-like table `{ kind = "x", n = P.number }` | Partial shape pattern (extra keys allowed) |
| matchigo P descriptor (`P.string`, `P.union(...)`) | Pattern-typed rule (walked on dispatch) |

> [!IMPORTANT]
> Guards are **not supported** with literal arrays. `sw:when({"a", "b"}, guard, action)` throws. Workaround : write two rules.

| Returns | Type | Description |
|---|---|---|
| `self` | `Switch` | For chaining. |

> [!NOTE]
> Calling `:when()` invalidates the memoize cache (when enabled). Stale entries that would conflict with the new rule are wiped.

---

## `Switch:default(action)`

Set the fallback action that fires when no rule matched.

| Argument | Type | Description |
|---|---|---|
| `action` | `function` | Receives the input value. |

| Returns | Type | Description |
|---|---|---|
| `self` | `Switch` | For chaining. |

### Example

```lua
sw:default(function(v) return "unhandled: " .. tostring(v) end)
```

> [!NOTE]
> Calling `:default()` invalidates the memoize cache.

---

## `Switch:use(middleware)`

Append a middleware function. Middlewares run in declaration order between the gate check and the dispatcher.

| Argument | Type | Description |
|---|---|---|
| `middleware` | `function(value): any` | Receives the current value, returns the transformed one (or `nil` to keep the prior value). |

| Returns | Type | Description |
|---|---|---|
| `self` | `Switch` | For chaining. |

### Example

```lua
sw:use(function(v) return string.lower(v) end)        -- normalise input
sw:use(function(v) return string.gsub(v, "%s+", "") end)  -- strip whitespace
```

> [!NOTE]
> Errors inside a middleware are isolated : the prior value is preserved, the `error` event fires (when listened), and the chain continues. Calling `:use()` invalidates the memoize cache.

See **[Middleware guide](../guides/middleware.md)**.

---

## `Switch:before(checkFunction)`

Set the gate function. Returning `false` from it short-circuits dispatch — `beforeCheckFailed` fires (when listened) and `:execute()` returns `nil`. Pass `nil` to clear an existing gate.

| Argument | Type | Description |
|---|---|---|
| `checkFunction` | `function(value): boolean` | Or `nil` to clear. |

| Returns | Type | Description |
|---|---|---|
| `self` | `Switch` | For chaining. |

### Example

```lua
sw:before(function(v)
    return type(v) == "string"   -- only string inputs proceed
end)
```

> [!NOTE]
> Calling `:before()` invalidates the memoize cache.

---

## `Switch:execute(value)`

Run the dispatch pipeline against `value` and return the matched action's result.

| Argument | Type | Description |
|---|---|---|
| `value` | any | The input to dispatch on. |

| Returns | Type | Description |
|---|---|---|
| `result` | any | The matching action's return value, the `default`'s return value, or `nil` if neither matched. |

### Behaviour

- If a matching action returns `EasySwitch.FALLTHROUGH`, the dispatcher continues to the next rule (see **[Fallthrough](../guides/fallthrough.md)**).
- If `safe = true` was passed to `EasySwitch.new`, action errors are caught — `error` fires and `:execute()` returns `nil`. Otherwise errors propagate.
- The `noMatch` event fires only when literally no rule and no default produced a value.

---

## `Switch:memoize(opts?)`

Enable result caching by input value. Idempotent — calling it more than once just updates the verify flag.

| Argument | Type | Description |
|---|---|---|
| `opts` | `table?` | Optional config. See below. |

| Returns | Type | Description |
|---|---|---|
| `self` | `Switch` | For chaining. |

### `opts` fields

| Field | Type | Default | Description |
|---|---|---|---|
| `verify` | `boolean` | `false` | When `true`, every cache HIT re-runs the full pipeline and errors if the result differs from the cached one. Dev-only safety net for non-deterministic actions. |

### Behaviour

- Cache uses **weak references** (`__mode = "kv"`) — table values get GC-reclaimed when otherwise unreferenced.
- `nil` and `NaN` keys are never cached (Lua disallows them as table keys).
- `nil` results are not cached, so adding a rule afterwards isn't shadowed by a stale miss.
- Mutations (`:when`, `:default`, `:use`, `:before`) automatically invalidate the cache.

### Example

```lua
local sw = EasySwitch.new():memoize()
    :when("expensive", function() return slow_compute() end)

sw:execute("expensive")  -- runs slow_compute()
sw:execute("expensive")  -- returns cached value, action does NOT re-run
```

See **[Memoize guide](../guides/memoize.md)**.

---

## `Switch:clearCache()`

Empty the memoize cache without disabling memoize. No-op when memoize is disabled.

| Returns | Type | Description |
|---|---|---|
| `self` | `Switch` | For chaining. |

### Example

```lua
sw:memoize()
sw:execute("x")          -- caches "x"
sw:clearCache()          -- cache empty
sw:execute("x")          -- runs again, caches again
```

---

## `Switch:clearEvents(event?)`

Remove all listeners for a given event, or for every event when no name is passed.

| Argument | Type | Description |
|---|---|---|
| `event` | `string?` | Event name. When `nil`, clears every event. |

| Returns | Type | Description |
|---|---|---|
| `self` | `Switch` | For chaining. |

### Example

```lua
sw:clearEvents("noMatch")   -- only noMatch listeners
sw:clearEvents()             -- all listeners across all events
```

---

## `Switch.FALLTHROUGH` (field)

The sentinel value, also reachable from `EasySwitch.FALLTHROUGH`. Returning it from an action keeps dispatch going. See **[Fallthrough guide](../guides/fallthrough.md)**.

---

## See also

- **[Module API](module.md)** — `EasySwitch.new`, registry helpers, re-exports
- **[Events API](events.md)** — payloads for every event
- **[Pattern matching guide](../guides/pattern-matching.md)** — how patterns get evaluated
