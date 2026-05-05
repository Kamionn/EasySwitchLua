# API — `EasySwitch` module

[← Docs index](../README.md) · [API : Switch](switch.md) · [API : Events](events.md) · [API : Patterns](patterns.md)

The top-level module returned by `require("easyswitch")`. Two roles :

1. **Factory** — create switch instances (anonymous or named).
2. **Re-exports** — surface matchigo's pattern vocabulary and helper types so you don't need a second `require`.

---

## `EasySwitch.new(options?)`

Create an anonymous switch with its own dispatcher, events, middleware, and (when enabled) memoize cache. No global state.

| Argument | Type | Description |
|---|---|---|
| `options` | `table?` | Optional config. See below. |

| Returns | Type | Description |
|---|---|---|
| `switch` | [Switch](switch.md) | A fresh switch instance. |

### `options` fields

| Field | Type | Default | Description |
|---|---|---|---|
| `safe` | `boolean` | `false` | Wrap action execution in a `pcall`. On error, the `error` event fires (when listened) and `:execute()` returns `nil`. Off by default — errors propagate. |

### Example

```lua
local sw = EasySwitch.new()                        -- bare
local sw = EasySwitch.new({ safe = true })         -- error-safe mode
```

---

## `EasySwitch(name, options?)` — registry mode

Create or retrieve a **named** switch. Acts like `EasySwitch.new(options)` but stores the instance in the module-level registry under `name`. Subsequent code anywhere can look it up via `EasySwitch.get(name)`.

| Argument | Type | Description |
|---|---|---|
| `name` | `string` | Unique non-empty name. Throws if already registered. |
| `options` | `table?` | Same `options` table as `EasySwitch.new`. |

| Returns | Type | Description |
|---|---|---|
| `switch` | [Switch](switch.md) | The newly registered instance. |

> [!WARNING]
> Calling `EasySwitch("foo")` twice with the same name throws `"Switch [foo] is already registered"`. Use `EasySwitch.clear("foo")` first if you intend to replace it.

### Example

```lua
local menu = EasySwitch("menu")
    :when("start", function() return "Game started" end)
    :when("quit",  function() return "Game ended"   end)

-- Elsewhere in the codebase :
local same = EasySwitch.get("menu")
assert(menu == same)
```

See **[Named registry guide](../guides/named-registry.md)** for when to use this over `EasySwitch.new()`.

---

## `EasySwitch.get(name?)`

Look up registered switches.

### Form 1 — by name

| Argument | Type | Description |
|---|---|---|
| `name` | `string` | The name passed to `EasySwitch(name)`. |

| Returns | Type | Description |
|---|---|---|
| `switch` | [Switch](switch.md)`?` | The instance, or `nil` if not registered. |

### Form 2 — all switches

| Argument | Type | Description |
|---|---|---|
| `name` | `nil` (omit) | — |

| Returns | Type | Description |
|---|---|---|
| `all` | `table?` | Map keyed by name. `nil` when the registry is empty. |
| `count` | `integer` | Number of registered switches. `0` when empty. |

### Example

```lua
EasySwitch("a"):when("x", ...)
EasySwitch("b"):when("y", ...)

local one = EasySwitch.get("a")        -- the "a" switch
local all, n = EasySwitch.get()         -- { a = ..., b = ... }, n = 2
```

---

## `EasySwitch.clear(name?)`

Remove a registered switch (or all of them).

| Argument | Type | Description |
|---|---|---|
| `name` | `string?` | When given, removes only that entry. When `nil`, wipes the whole registry. |

| Returns | Type | Description |
|---|---|---|
| (nothing) | `nil` | — |

### Example

```lua
EasySwitch.clear("menu")  -- remove one
EasySwitch.clear()         -- wipe all
```

---

## `EasySwitch.P`

The pattern vocabulary, re-exported from matchigo. Use it to build pattern-typed cases :

```lua
local P = EasySwitch.P

sw:when(P.string,   string_handler)
sw:when(P.number,   number_handler)
sw:when(P.union("a", "b", "c"), letter_handler)
```

See **[Patterns reference](patterns.md)** for the curated list and **[matchigo's docs](https://github.com/SUP2Ak/matchigo-lua/tree/main/docs)** for the full surface.

---

## `EasySwitch.parsePattern(src, scope?, ctx?)`

Parse a [matchigo DSL](https://github.com/SUP2Ak/matchigo-lua/blob/main/docs/en/dsl.md) string into a `P.*` pattern descriptor. Re-exported from matchigo.

| Argument | Type | Description |
|---|---|---|
| `src` | `string` | DSL source (e.g. `"'GET' \| 'POST'"`, `"{| kind: 'click', x: Num |}"`). |
| `scope` | `table?` | PascalCase ref bindings (`{ Num = P.number }`). Required when the DSL uses scope refs. |
| `ctx` | `table?` | `$interp` values used inside the DSL. |

| Returns | Type | Description |
|---|---|---|
| `pattern` | matchigo Pattern | The parsed descriptor, usable in `sw:when(pattern, action)`. |

### Why pre-parse ?

`Switch:when` already auto-parses DSL strings, so you rarely call this directly. Use it when :

- The same pattern is shared across many switches (parse once, reuse the descriptor).
- You're storing patterns in a config table and want to validate them at load time, not at first dispatch.

### Example

```lua
local P = EasySwitch.P
local writeMethods = EasySwitch.parsePattern("'POST' | 'PUT' | 'PATCH'")

sw1:when(writeMethods, write_handler)
sw2:when(writeMethods, log_handler)
```

See **[DSL strings guide](../guides/dsl-strings.md)**.

---

## `EasySwitch.FALLTHROUGH`

A sentinel value. Returning it from an action tells the dispatcher "I handled this, but keep looking for the next matching rule".

```lua
sw:when("admin", function()
    audit_log("admin command issued")
    return EasySwitch.FALLTHROUGH       -- log AND continue dispatch
end)
sw:when(P.string, function(v)
    return execute_command(v)
end)
```

See **[Fallthrough guide](../guides/fallthrough.md)** for full semantics including how it interacts with `noMatch` and `default`.

---

## `EasySwitch.Map` / `EasySwitch.Set` / `EasySwitch.BigInt`

Re-exports of matchigo's container types. Useful when your actions need ordered insertion or arbitrary-precision integers without pulling matchigo separately.

```lua
local Map = EasySwitch.Map

local m = Map.new({{ "a", 1 }, { "b", 2 }})
m:set("c", 3)
for k, v in m:pairs() do print(k, v) end  -- a 1, b 2, c 3 (insertion order)
```

See [matchigo's type docs](https://github.com/SUP2Ak/matchigo-lua/tree/main/types) for full reference.

---

## See also

- **[Switch instance API](switch.md)** — every method on a `Switch` instance
- **[Events API](events.md)** — the seven events you can listen to
- **[Patterns API](patterns.md)** — `P.*` curated reference
