# API — Patterns (`P.*`)

[← Docs index](../README.md) · [API : Module](module.md) · [API : Switch](switch.md) · [API : Events](events.md)

`EasySwitch.P` is matchigo's pattern vocabulary, re-exported untouched. This page covers the **curated subset** most useful inside `Switch:when()`. For exhaustive reference (BigInt patterns, Set / Map patterns, captureSlice, ...), see [matchigo's patterns docs](https://github.com/SUP2Ak/matchigo-lua/blob/main/docs/en/patterns.md).

```lua
local P = EasySwitch.P
```

---

## Type sentinels

Plain pattern descriptors that test the input's type only.

| Pattern | Matches |
|---|---|
| `P.string` | any string |
| `P.number` | any number (integer or float) |
| `P.boolean` | `true` or `false` |
| `P.integer` | whole numbers (`math.type(v) == "integer"`) |
| `P.float` | non-integer numbers (`math.type(v) == "float"`) |
| `P.func` | any function |
| `P.nullish` | `nil` only |
| `P.defined` | any non-nil value |
| `P.any` | always matches |
| `P.positive` | numbers `> 0` |
| `P.negative` | numbers `< 0` |
| `P.finite` | numbers other than `±inf` and `NaN` |

```lua
sw:when(P.string,  function(v) return "got string: " .. v end)
sw:when(P.integer, function(v) return "got int: "    .. v end)
sw:when(P.float,   function(v) return "got float: "  .. v end)
```

---

## Number ranges

```lua
P.between(min, max)   -- inclusive : v >= min AND v <= max
P.gt(n)               -- v > n
P.gte(n)              -- v >= n
P.lt(n)               -- v < n
P.lte(n)              -- v <= n
```

All require `type(v) == "number"`. Strings comparing equal to a number do not match.

```lua
sw:when(P.between(1, 10),  function() return "low"    end)
sw:when(P.gte(11),          function() return "big"    end)
```

---

## String refinements

```lua
P.startsWithStr(prefix)
P.endsWithStr(suffix)
P.includesStr(substring)
P.lengthStr(n)
P.minLengthStr(n)
P.maxLengthStr(n)
P.luaPattern(lua_pattern)   -- string.match(v, lua_pattern) ~= nil
```

```lua
sw:when(P.startsWithStr("/api/"), api_handler)
sw:when(P.luaPattern("^%d+$"),   digit_only_handler)
sw:when(P.minLengthStr(8),        long_string_handler)
```

---

## Disjunction (OR)

### `P.union(literal, ...)` — literals only, hash O(1)

The fastest disjunction. Every argument must be a **value** (not a pattern). At construction it builds a hash set ; at runtime it's a single hash lookup.

```lua
sw:when(P.union("GET", "POST", "PUT"),       method_handler)
sw:when(P.union(1, 2, 3, 4, 5, "fast-path"),  numeric_or_label_handler)
```

`nil` and `NaN` are handled (shielded into separate flags so they can still match).

### `P.anyOf(pattern_or_literal, ...)` — mixed, linear walk

Use when your alternatives include patterns, not just literals. Walks the list at runtime.

```lua
sw:when(P.anyOf(P.integer, P.string),                int_or_str_handler)
sw:when(P.anyOf("admin", P.luaPattern("^mod_")),     priv_user_handler)
```

> [!TIP]
> If every alternative is a literal value, prefer `P.union(...)` — it's 3-4× faster than `P.anyOf(...)`.

---

## Conjunction (AND)

### `P.intersection(pat, ...)` — every member must match

```lua
sw:when(P.intersection(P.number, P.gt(0)),
        function() return "positive number" end)

sw:when(P.intersection(P.string, P.startsWithStr("admin_"), P.minLengthStr(10)),
        admin_id_handler)
```

---

## Negation

### `P.not_(pattern)` — matches when `pattern` does **not**

```lua
sw:when(P.not_(P.string), function() return "not a string" end)
sw:when(P.not_(P.union(0, "")), function() return "truthy-ish" end)
```

---

## Optional

### `P.optional(pattern)` — matches `nil` OR matches `pattern`

```lua
sw:when({ name = P.string, age = P.optional(P.integer) }, partial_form_handler)

sw:execute({ name = "Bob" })           -- match (no age field)
sw:execute({ name = "Bob", age = 30 }) -- match (age is integer)
sw:execute({ name = "Bob", age = "x" }) -- no match (age is wrong type)
```

---

## Predicate

### `P.when(fn)` — arbitrary boolean predicate

`fn(value)` is called with the input ; returning truthy = match.

```lua
sw:when(P.when(function(v) return type(v) == "table" and v.kind == "click" end),
        click_handler)
```

> [!TIP]
> Prefer the more specialised `P.*` helpers (`P.between`, `P.luaPattern`, `P.intersection`, ...) when they fit — they're typically faster and self-documenting. Reach for `P.when` for ad-hoc checks that don't have a dedicated helper.

---

## Tables — partial vs strict

### Bare table — partial shape (extras allowed)

A plain dict-table is treated as a **partial** matcher : every declared key must match, extra keys on the input are ignored.

```lua
sw:when({ kind = "click" }, click_handler)

sw:execute({ kind = "click", x = 5, y = 10 })  -- match (extras ignored)
sw:execute({ kind = "key" })                   -- no match
```

Patterns can nest :

```lua
sw:when({ user = { id = P.number, role = P.union("admin", "mod") } },
        privileged_handler)
```

### `P.shape(tbl)` — strict shape (extras refused)

```lua
sw:when(P.shape({ x = P.number, y = P.number }), strict_point_handler)

sw:execute({ x = 1, y = 2 })             -- match
sw:execute({ x = 1, y = 2, z = 3 })      -- no match (extra key z)
sw:execute({ x = 1 })                     -- no match (missing y)
```

> [!IMPORTANT]
> The strict `P.shape` is a v2 addition (it existed in v1 EasySwitch but was reimplemented through matchigo). Bare-table partial matching has been the matchigo / ts-pattern standard since matchigo's first release.

---

## Tables — sequences (arrays)

### `P.array(item_pattern)` — every element matches `item_pattern`

```lua
sw:when(P.array(P.number), function() return "all numbers" end)

sw:execute({ 1, 2, 3 })       -- match
sw:execute({ 1, "x", 3 })     -- no match (mid element fails)
sw:execute({})                 -- match (vacuously true)
```

> [!IMPORTANT]
> Empty arrays match `P.array(...)` (no counterexample = vacuously true, same as JS `arr.every(...)`). If you need to require at least one element, use `P.arrayOf(item, { min = 1 })` instead.

### `P.arrayOf(item, opts)` — like `P.array` but with length bounds

```lua
sw:when(P.arrayOf(P.string, { min = 1 }),         non_empty_strings)
sw:when(P.arrayOf(P.integer, { min = 2, max = 4 }), bounded_int_list)
```

| `opts` field | Type | Description |
|---|---|---|
| `min` | `integer?` | Minimum length (inclusive). |
| `max` | `integer?` | Maximum length (inclusive). |

### `P.tuple(pat1, pat2, ...)` — exact length, positional

```lua
sw:when(P.tuple(P.string, P.number), function(t) return t[1] .. ":" .. t[2] end)

sw:execute({ "x", 42 })    -- match
sw:execute({ "x", 42, 99 })-- no match (length mismatch)
sw:execute({ 42, "x" })    -- no match (types swapped)
```

### `P.startsWith(p1, p2, ...)` / `P.endsWith(p1, p2, ...)` — prefix/suffix

```lua
sw:when(P.startsWith(1, 2),  function() return "starts 1,2" end)
sw:when(P.endsWith(99, 100), function() return "ends 99,100" end)
```

### `P.arrayIncludes(item)` — at least one element matches

```lua
sw:when(P.arrayIncludes("admin"), has_admin_role_handler)
sw:when(P.arrayIncludes(P.number), has_at_least_one_number_handler)
```

---

## `instanceOf`

Match by Lua metatable identity. Useful for OOP patterns.

```lua
local PointMt = { __index = ... }

sw:when(P.instanceOf(PointMt), point_handler)
```

---

## Pre-parsing DSL strings

You don't strictly need `P.*` to express patterns — DSL strings work directly inside `:when()`. But you can also pre-parse a DSL string into a P descriptor and reuse it :

```lua
local writeMethods = EasySwitch.parsePattern("'POST' | 'PUT' | 'PATCH'")

sw1:when(writeMethods, write_handler)
sw2:when(writeMethods, log_handler)
```

See **[DSL strings guide](../guides/dsl-strings.md)** and **[`EasySwitch.parsePattern`](module.md#easyswitchparsepatternsrc-scope-ctx)**.

---

## More patterns

For advanced use cases, matchigo also provides :

- **`P.set(item)` / `P.map(key, val)`** — match matchigo's ordered Map / Set types
- **`P.bigint*`** — comparison patterns for `EasySwitch.BigInt`
- **`P.captureSlice`** — for DSL `...rest` named captures

Full reference : [matchigo's patterns docs](https://github.com/SUP2Ak/matchigo-lua/blob/main/docs/en/patterns.md).

---

## See also

- **[Pattern matching guide](../guides/pattern-matching.md)** — how patterns get evaluated
- **[DSL strings guide](../guides/dsl-strings.md)** — write patterns as text
- **[Switch:when API](switch.md#switchwhen-cases-action)** — call shapes for registering rules
