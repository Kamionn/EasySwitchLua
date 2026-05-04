# Migration v1 → v2

[← Docs index](README.md)

EasySwitch v2 is a major rewrite. The internals are now built on top of [matchigo-lua](https://github.com/SUP2Ak/matchigo-lua) (vendored in the bundle), the implicit value cache is gone, and several `P.*` primitives were renamed to align with matchigo's vocabulary.

This page lists every breaking change so you can mechanically port your v1 code.

---

## At a glance — the rename table

| v1 | v2 | Reason |
|---|---|---|
| `P.any_of(...)` | `P.union(...)` (literals) **or** `P.anyOf(...)` (mixed) | matchigo splits the two for performance |
| `P.and_(...)` / `P.all_of(...)` | `P.intersection(...)` | aliases removed, single canonical name |
| `P.nil_` | `P.nullish` | matchigo's vocabulary |
| `P.string_match(pat)` | `P.luaPattern(pat)` | matchigo's vocabulary |
| `P.array(P.x)` rejects `{}` | `P.array(P.x)` accepts `{}` | vacuously-true semantics, matches JS / Rust / Python `all(...)` |
| (no escape hatch) | `P.arrayOf(item, { min = 1 })` | new — explicit non-empty array |
| `cacheHit` event | (removed) | no implicit cache to fire |
| `cacheMiss` event | (removed) | no implicit cache to fire |
| Auto-cache on every `:execute()` | `:memoize()` opt-in | explicit caching ; defaults to no cache |
| `:clearCache()` | `:clearCache()` (no-op when memoize disabled) | now requires `:memoize()` first to do anything |
| `{ maxCases = N }` constructor option | (removed) | no internal cap, no `actionManager` |
| (no `safe` option) | `{ safe = true }` | new — opt-in `pcall` around the action |

---

## Pattern renames

### `P.any_of` is now two functions

```lua
-- v1
sw:when(P.any_of("red", "green", "blue"), color_handler)
sw:when(P.any_of(P.integer, P.string),    mixed_handler)
```

```lua
-- v2 — pure literals : prefer P.union (hash O(1) lookup)
sw:when(P.union("red", "green", "blue"), color_handler)

-- v2 — mixed patterns : use P.anyOf (linear walk like v1)
sw:when(P.anyOf(P.integer, P.string),    mixed_handler)
```

`P.union` is **3-4× faster** than `P.any_of` was, because it precomputes a hash set at construction time. Always prefer it when every member is a literal value.

### `P.and_` / `P.all_of` → `P.intersection`

```lua
-- v1
sw:when(P.and_(P.number, P.when(positive)),  positive_handler)
sw:when(P.all_of(P.integer, P.between(1, 10)), bounded_handler)
```

```lua
-- v2
sw:when(P.intersection(P.number, P.when(positive)),    positive_handler)
sw:when(P.intersection(P.integer, P.between(1, 10)),   bounded_handler)
```

### `P.nil_` → `P.nullish`

```lua
sw:when(P.nullish, function() return "got nil" end)
```

### `P.string_match` → `P.luaPattern`

```lua
sw:when(P.luaPattern("^/api/"), api_handler)
sw:when(P.luaPattern("%d+"),    digits_handler)
```

---

## Array semantics

In v1, `P.array(P.number)` rejected the empty table `{}`. In v2, it accepts it (vacuously-true logic, same as `[].every(...)` in JavaScript or `iter::all(...)` in Rust).

```lua
sw:when(P.array(P.number), function() return "array of nums" end)

sw:execute({})         -- v1 : no match  | v2 : match (vacuously)
sw:execute({ 1, 2 })   -- both : match
sw:execute({ 1, "x" }) -- both : no match
```

If you specifically want to reject empty arrays, use `P.arrayOf(item, { min = 1 })` :

```lua
sw:when(P.arrayOf(P.number, { min = 1 }), function() return "non-empty nums" end)
```

---

## Caching → opt-in memoize

The biggest semantic change. v1 cached every `:execute()` result implicitly (with weak refs). v2 has zero implicit cache — you opt in via `:memoize()`.

```lua
-- v1 — cache is automatic
local sw = EasySwitch.new()
    :when("calc", expensive_compute)
sw:execute("calc")  -- runs
sw:execute("calc")  -- cached
```

```lua
-- v2 — call :memoize() once to opt in
local sw = EasySwitch.new():memoize()
    :when("calc", expensive_compute)
sw:execute("calc")  -- runs
sw:execute("calc")  -- cached
```

> [!IMPORTANT]
> v2 cache is more aggressive than v1's : it caches **both literal hits and pattern hits**, not just literals. Make sure your actions are deterministic before enabling memoize. Use `:memoize({ verify = true })` in development to catch non-deterministic actions — see **[Memoize guide](guides/memoize.md)**.

If you depended on side effects running on every call, leave memoize off. v2 is **1.5× faster than v1 on cold dispatch** anyway, so the cache wasn't pulling its weight in most real-world workloads.

---

## Removed events

```lua
-- v1
sw:on("cacheHit",  function(value, result) ... end)
sw:on("cacheMiss", function(value)         ... end)
```

Both events are gone in v2. If you need to track cache behaviour, attach a logging middleware or wrap your actions manually.

---

## Removed constructor option

```lua
-- v1
local sw = EasySwitch.new({ maxCases = 500 })
```

In v2, there is no upper bound on the number of rules — the `actionManager` it was capping was removed. Just drop the option :

```lua
-- v2
local sw = EasySwitch.new()
```

---

## New constructor option : `safe`

```lua
local sw = EasySwitch.new({ safe = true })
```

When `safe = true`, action errors are caught and emit the `error` event ; `:execute()` returns `nil` instead of propagating. Defaults to `false` (errors propagate, matching matchigo's behaviour).

---

## Public API additions in v2

These are not breaking changes (your v1 code keeps working), but they're worth knowing :

- **DSL strings in `:when()`** — pass a quoted-or-bracketed string and it's parsed as a matchigo DSL pattern. See **[DSL strings guide](guides/dsl-strings.md)**.
- **`P.shape(tbl)`** — strict shape (refuses extra keys). v1 already had this ; same semantics, listed here for completeness.
- **matchigo types exposed** — `EasySwitch.Map`, `EasySwitch.Set`, `EasySwitch.BigInt` are available for use inside actions.
- **`EasySwitch.parsePattern(src, scope?, ctx?)`** — pre-parse a DSL string once, reuse the descriptor across switches.

---

## Mechanical migration checklist

Run these find/replace operations across your codebase :

```
P.any_of(   →  P.union(    (when all args are literals)
            →  P.anyOf(    (when args mix literals and patterns)
P.and_(     →  P.intersection(
P.all_of(   →  P.intersection(
P.nil_      →  P.nullish
P.string_match(  →  P.luaPattern(
```

Then :

1. Drop any `{ maxCases = N }` from `EasySwitch.new(...)` / `EasySwitch(name, ...)`.
2. Drop any `cacheHit` / `cacheMiss` event listeners.
3. If you relied on automatic caching, add `:memoize()` to the call chain.
4. If your `P.array(...)` rules were specifically expecting empty arrays to fail, swap them to `P.arrayOf(item, { min = 1 })`.

Your tests should now pass on v2 with no behavioural drift other than the new opt-in cache.

---

## Need help porting ?

Open an issue at https://github.com/SUP2Ak/EasySwitchLua/issues with a snippet of your v1 code and the error you're hitting — happy to help.
