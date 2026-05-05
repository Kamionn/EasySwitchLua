# API — Events

[← Docs index](../README.md) · [API : Module](module.md) · [API : Switch](switch.md) · [API : Patterns](patterns.md)

EasySwitch fires seven events during the dispatch pipeline. Subscribe to them via `Switch:on(name, callback)`. Unknown event names throw at registration time so typos are caught early.

> [!NOTE]
> All events skip emission when no listener is bound — zero overhead for events you don't subscribe to. The `error` event also fires from within middleware errors when `safe = true` is set on the switch.

---

## Event lifecycle

```
sw:execute(value)
│
├── beforeExecute(value)                 ← step 1
│
├── (cache HIT)                          ← only with :memoize()
│   └── afterExecute(value, cached)      ← then return cached
│
├── (gate fails)
│   └── beforeCheckFailed(value)         ← then return nil
│
├── middlewareStart(value)               ← only when middlewares are registered
├── ... middleware errors → error("middleware", err)
├── middlewareEnd(transformed)           ← only when middlewares are registered
│
├── ... action errors (safe mode) → error("action", err)
│
├── noMatch(value)                       ← only when nothing matched
└── afterExecute(value, result)          ← step 8
```

---

## `beforeExecute`

Fires immediately when `:execute()` is called, before any cache lookup or dispatch logic.

| Payload | Type | Description |
|---|---|---|
| `value` | any | The original input passed to `:execute()`. |

```lua
sw:on("beforeExecute", function(value)
    print("dispatching:", value)
end)
```

---

## `afterExecute`

Fires at the end of `:execute()`, regardless of whether a rule matched, the gate blocked, the cache hit, or nothing matched. Always the last event of the call.

| Payload | Type | Description |
|---|---|---|
| `value` | any | The original input. |
| `result` | any | The final return value of `:execute()`. `nil` when no rule matched and no default is set, or when the gate blocked. |

```lua
sw:on("afterExecute", function(value, result)
    metrics:record(value, result)
end)
```

> [!NOTE]
> When the action errors and `safe = true`, `result` is `nil` (the error is reported via the `error` event).

---

## `error`

Fires when an action errors (only in `safe = true` mode) or when a middleware errors (always). The pipeline continues for middleware errors (the prior value is preserved) ; for action errors in safe mode, `:execute()` returns `nil`.

| Payload | Type | Description |
|---|---|---|
| `stage` | `string` | `"action"` or `"middleware"`. |
| `errorValue` | any | The value `error()` was called with. |

```lua
sw:on("error", function(stage, err)
    log_error(("[%s] %s"):format(stage, tostring(err)))
end)
```

> [!IMPORTANT]
> Action errors only emit `error` when the switch was created with `{ safe = true }`. Otherwise errors propagate and `:execute()` doesn't return at all.

---

## `middlewareStart`

Fires once per `:execute()` if at least one middleware is registered, before the first middleware runs. Skipped entirely when the chain is empty.

| Payload | Type | Description |
|---|---|---|
| `value` | any | The value before the chain transforms it. |

```lua
sw:on("middlewareStart", function(value)
    print("entering middleware chain:", value)
end)
```

---

## `middlewareEnd`

Fires once after all middlewares ran, before the dispatcher. Skipped when the chain is empty.

| Payload | Type | Description |
|---|---|---|
| `transformed` | any | The value after all middlewares applied. |

```lua
sw:on("middlewareEnd", function(transformed)
    print("middleware chain output:", transformed)
end)
```

---

## `noMatch`

Fires when the dispatcher walked every rule and nothing matched, **and** no default is set. Useful as a "this shouldn't happen" hook.

| Payload | Type | Description |
|---|---|---|
| `value` | any | The (possibly middleware-transformed) value that fell through. |

```lua
sw:on("noMatch", function(v)
    log_warn("unhandled value: " .. tostring(v))
end)
```

> [!NOTE]
> `noMatch` does **not** fire when a rule matched but its action returned `EasySwitch.FALLTHROUGH` and a later rule produced the result — something matched, just not the first thing. See **[Fallthrough guide](../guides/fallthrough.md)**.

---

## `beforeCheckFailed`

Fires when the gate function set via `:before(...)` returned `false`. Dispatch is short-circuited at this point ; nothing else after it runs (no middleware, no dispatcher, no `noMatch`, no `afterExecute`).

| Payload | Type | Description |
|---|---|---|
| `value` | any | The input that failed the gate. |

```lua
sw:before(function(v) return type(v) == "string" end)
sw:on("beforeCheckFailed", function(v)
    log_warn("non-string input rejected: " .. tostring(v))
end)
```

---

## Multiple listeners

You can register multiple listeners per event ; they fire in registration order :

```lua
sw:on("noMatch", function(v) print("listener 1:", v) end)
sw:on("noMatch", function(v) print("listener 2:", v) end)
sw:execute("z")
-- listener 1: z
-- listener 2: z
```

Use `Switch:clearEvents(name?)` to remove them all (per name or globally).

---

## Listener errors are isolated

If a listener throws, EasySwitch catches the error, prints it to stdout, and continues firing the remaining listeners for that event. Your dispatch pipeline is never interrupted by a logging mistake.

```lua
sw:on("afterExecute", function() error("oops") end)
sw:on("afterExecute", function() print("still runs") end)
sw:execute("x")
-- [EasySwitch] Event error in 'afterExecute': ... oops ...
-- still runs
```

---

## See also

- **[Switch API : `:on`](switch.md#switchon-event-callback)** — registration shape
- **[Middleware guide](../guides/middleware.md)** — how `error` interacts with middleware errors
- **[Fallthrough guide](../guides/fallthrough.md)** — how `FALLTHROUGH` interacts with `noMatch`
