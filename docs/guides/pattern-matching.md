# Guide — Pattern matching

[← Docs index](../README.md) · [Patterns reference](../api/patterns.md)

Pattern matching is the heart of EasySwitch. This guide explains how `:when(cases, action)` decides whether `cases` matches the input, what gets dispatched first, and how to choose between bare tables, `P.shape`, unions and intersections.

---

## How dispatch picks a rule

When you call `sw:execute(value)`, the dispatcher runs three stages in this order :

1. **Map literal lookup** — if `value` is one of the literals registered via `:when(literal, action)` or `:when({"a", "b"}, action)`, fire that action. O(1).
2. **Pattern walk** — for each pattern rule, in declaration order, test the pattern. First match wins.
3. **Default** — fires the action set by `:default(...)` if no pattern matched.

```lua
local sw = EasySwitch.new()
    :when("hello",   function() return "literal-hello" end)   -- stage 1
    :when(P.string,  function() return "any-string"     end)  -- stage 2
    :default(function(v) return "fallback: " .. tostring(v) end)  -- stage 3

sw:execute("hello")  -- "literal-hello"  (stage 1 wins)
sw:execute("world")  -- "any-string"     (stage 1 misses, stage 2 wins)
sw:execute(42)       -- "fallback: 42"   (stage 1 misses, stage 2 misses, stage 3)
```

> [!NOTE]
> Literals are always tried before patterns, regardless of declaration order. If you `sw:when(P.string, ...)` first then `sw:when("hello", ...)`, dispatching `"hello"` still picks the literal. This is by design — the Map fast-path is too valuable to bypass.

---

## The match types, ranked from fastest to most expressive

### 1. Literal — `:when(value, action)`

Fastest possible match. The value is stored in a hash map ; lookup is O(1).

```lua
sw:when("GET",  list_handler)
sw:when(42,     forty_two_handler)
sw:when(true,   on_handler)
```

Use for HTTP methods, command tokens, finite enums, anything that's a discrete known value.

### 2. Array of literals — `:when({"a", "b", "c"}, action)`

Sugar for "register the same action for all of these literals". Each element is added separately to the Map.

```lua
sw:when({"GET", "HEAD", "OPTIONS"}, read_handler)
sw:when({200, 201, 204},            success_handler)
```

> [!IMPORTANT]
> Guards (3-arg form) are **not** supported with literal arrays. Use individual `:when()` calls if you need different guards per literal.

### 3. Bare table (partial shape) — `:when({ kind = "x" }, action)`

A dict-table is treated as a partial matcher : every declared key/value must match, extra keys on the input are ignored.

```lua
sw:when({ kind = "click" },       click_handler)
sw:when({ kind = "click", x = P.number, y = P.number }, typed_click_handler)

sw:execute({ kind = "click" })                            -- match (1st rule)
sw:execute({ kind = "click", x = 5, y = 10 })            -- match (1st rule still wins)
sw:execute({ kind = "click", x = 5, y = "??" })          -- match (1st — value of x doesn't matter for the 1st rule)
```

Patterns nest naturally :

```lua
sw:when({ user = { id = P.number, role = P.union("admin", "mod") } },
        privileged_handler)
```

> [!TIP]
> Rule order matters within the pattern walk. Place more specific patterns first, then fall back to broader ones :
> ```lua
> sw:when({ kind = "click", x = P.number, y = P.number }, typed_handler)
> sw:when({ kind = "click" }, anything_click_handler)
> ```

### 4. `P.shape({...})` — strict shape

Same syntax as a bare table, but **rejects** any input that has keys not declared in the pattern.

```lua
sw:when(P.shape({ x = P.number, y = P.number }), strict_handler)

sw:execute({ x = 1, y = 2 })             -- match
sw:execute({ x = 1, y = 2, z = 3 })      -- no match (extra key z)
sw:execute({ x = 1 })                     -- no match (missing y)
```

Use for input validation : "this payload must look exactly like this, nothing more".

### 5. `P.*` descriptors — typed predicates

The richest layer. Compose primitives like `P.string`, `P.between`, `P.luaPattern`, `P.union`, `P.intersection`, ... See **[Patterns reference](../api/patterns.md)** for the full list.

```lua
sw:when(P.intersection(P.string, P.minLengthStr(8)),
        function() return "long string" end)

sw:when(P.between(0, 100),  in_range_handler)
sw:when(P.luaPattern("^/api/"), api_handler)
```

### 6. DSL strings — patterns as text

A string starting with `{`, `[`, `(`, `'`, `"` is auto-parsed as a [matchigo DSL pattern](dsl-strings.md). Particularly handy for unions and shapes :

```lua
sw:when("'GET' | 'POST'",                       method_handler)
sw:when("{| kind: 'click', x: Num |}",
        { Num = P.number },                      -- scope for refs
        click_handler)
```

See **[DSL strings guide](dsl-strings.md)**.

---

## Common pitfalls

### Pattern declaration order matters within stage 2

```lua
sw:when(P.any,       broad_handler)   -- this swallows everything
sw:when(P.string,    string_handler)  -- never reached
```

Put broader patterns last. The dispatcher walks declaratively.

### Bare table vs P.shape — silently different

These two rules look identical in source but behave very differently :

```lua
sw:when({ active = true }, partial_handler)         -- partial : extras allowed
sw:when(P.shape({ active = true }), strict_handler)  -- strict : extras refused
```

If you're getting "this rule doesn't match what I expect" weirdness on table inputs, double-check whether you wanted partial or strict semantics.

### `P.array(item)` matches the empty array

In v2 (and standard `every`/`all` semantics across languages), `P.array(P.number)` matches `{}` because there's no counterexample. If you want to reject empty arrays, use `P.arrayOf(item, { min = 1 })`.

### `P.union` is for literals, `P.anyOf` is for patterns

```lua
P.union("a", "b", "c")              -- ✓ all literals → fast hash lookup
P.anyOf(P.integer, P.string)        -- ✓ mixed patterns → linear walk
P.union(P.integer, "x")             -- ✗ mixing literal + pattern : use P.anyOf
```

`P.union` builds a hash set at construction ; passing a pattern descriptor would compare against the table's address, never matching at runtime. Always pick the right tool — see **[Patterns reference](../api/patterns.md#disjunction-or)**.

### Numbers and number-strings don't unify

```lua
sw:when(P.number, num_handler)
sw:execute("42")  -- no match — "42" is a string, not a number
```

Add a middleware (`:use(tonumber)`) if you want loose coercion. EasySwitch never coerces silently.

---

## Performance hints

- **Literals are 4-5× faster than patterns** thanks to the Map fast-path. Prefer literals when you can enumerate the cases.
- **`P.union` is 4× faster than `P.any_of` was in v1** — always prefer it over `P.anyOf` when every member is a literal.
- **`P.shape` baked tests** are pre-computed at construction, so repeated dispatches don't re-walk the shape. No need to cache descriptors yourself.
- **Pattern descriptors are reusable** : the same `P.union(...)` value can be passed to multiple `:when()` calls or even multiple switches with no overhead.

For real bench numbers, see [`test_bench/v1_vs_v2.lua`](../../test_bench/v1_vs_v2.lua).

---

## See also

- **[Patterns reference](../api/patterns.md)** — every `P.*` primitive
- **[DSL strings guide](dsl-strings.md)** — Rust-style match syntax
- **[Fallthrough guide](fallthrough.md)** — when one rule should run but not "win"
