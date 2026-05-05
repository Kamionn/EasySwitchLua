# Guide — DSL strings in `:when()`

[← Docs index](../README.md) · [Patterns reference](../api/patterns.md) · [Switch:when](../api/switch.md#switchwhen-cases-action)

You can write patterns as Rust-style strings directly inside `:when(...)`. EasySwitch detects DSL strings and routes them through matchigo's parser ; non-DSL strings stay literals.

```lua
sw:when("'GET' | 'POST'", method_handler)
sw:when("{| kind: 'click', x: Num, y: Num |}", { Num = P.number }, click_handler)
```

---

## Why use DSL strings ?

For unions, shapes, and tuples, the DSL is **shorter and more readable** than the equivalent `P.*` calls :

```lua
-- Programmatic
sw:when(P.union("GET", "POST", "PUT"), method_handler)
sw:when(P.shape({ kind = "click", x = P.number, y = P.number }), click_handler)
sw:when(P.tuple(P.string, P.number), pair_handler)

-- DSL string equivalents
sw:when("'GET' | 'POST' | 'PUT'", method_handler)
sw:when("{| kind: 'click', x: Num, y: Num |}", { Num = P.number }, click_handler)
sw:when("(Str, Num)", { Str = P.string, Num = P.number }, pair_handler)
```

Both compile to **identical** P descriptors at construction — the DSL has zero runtime overhead vs hand-built patterns.

---

## Detection rules

EasySwitch decides whether a string is DSL or a plain literal **based on two signals** :

### Rule 1 — leading character

If the string starts with one of these characters, it's parsed as DSL :

```
{   [   (   '   "
```

```lua
sw:when("'GET'",                     dsl_method)            -- DSL : starts with '
sw:when("{ kind: 'click' }",         dsl_partial_shape)     -- DSL : starts with {
sw:when("{| x: Num |}",              dsl_strict_shape)      -- DSL : starts with {
sw:when("[Num, Num]",                dsl_tuple)             -- DSL : starts with [
sw:when("(Num, Str)",                dsl_paren_tuple)       -- DSL : starts with (
```

### Rule 2 — explicit scope table forces DSL

If you pass a **table** as the second argument to `:when()`, the string is force-parsed as DSL regardless of its first character. The table is the scope used to resolve PascalCase refs.

```lua
sw:when("Str | Num", { Str = P.string, Num = P.number }, mixed_handler)
-- Even though "Str | Num" doesn't start with a DSL char,
-- the scope arg forces DSL parsing.
```

### Anything else stays a literal

```lua
sw:when("GET",       literal_get)         -- literal "GET" (uppercase scope ref form, but no scope passed)
sw:when("hi!?",      literal_emote)       -- literal — `?` and `!` aren't triggers
sw:when("foo:bar",   literal_with_colon)  -- literal — `:` isn't a trigger
sw:when("hello world", literal_phrase)    -- literal — spaces don't trigger DSL
```

> [!IMPORTANT]
> Operators like `|`, `&`, `?`, `!` inside a string do **not** trigger DSL detection. Only the leading char or an explicit scope. This protects literal strings like `"hi!?"`, `"what?"`, `"a&b"` from accidental parsing.

---

## Scope tables

Scope tables let the DSL reference your `P.*` patterns by PascalCase name. Common pattern :

```lua
local scope = {
    Num    = P.number,
    Str    = P.string,
    Bool   = P.boolean,
    Email  = P.luaPattern("^[%w._]+@[%w.]+$"),
}

sw:when("{| id: Num, name: Str, email: Email |}", scope,
        function(u) return "user " .. u.name end)
```

The scope object is captured **at compile time** of the pattern. Mutating it after `:when()` doesn't affect already-registered rules.

> [!TIP]
> Build the scope table once and reuse it across all your `:when()` calls. Or use `EasySwitch.parsePattern(src, scope)` to pre-compile patterns and store the descriptors directly.

---

## DSL grammar — quick tour

This is a minimal overview ; for the full grammar (guards, bindings, captures, interpolation), see [matchigo's DSL docs](https://github.com/SUP2Ak/matchigo-lua/blob/main/docs/en/dsl.md).

### Literal values

```
'string'      → matches the string "string"
42            → matches the number 42
3.14          → matches the float 3.14
true / false  → matches the boolean
nil           → matches nil
_             → wildcard, matches anything
```

### Scope refs (PascalCase)

```
Num           → resolved against scope.Num at compile time
Email         → resolved against scope.Email
```

### Disjunction

```
'a' | 'b' | 'c'     → P.union("a", "b", "c")
Num | Str           → P.anyOf(Num, Str)
```

### Intersection

```
Str & Num   → P.intersection(Str, Num)
```

### Negation / optional

```
!Str        → P.not_(Str)
Str?        → P.optional(Str)
```

### Partial shape (extras allowed)

```
{ kind: 'click', x: Num, y: Num }
```

### Strict shape (extras refused)

```
{| kind: 'click', x: Num |}
```

### Tuple

```
(Str, Num)              → exact length, positional
[Num, Num]              → same as a tuple when no rest
[Num, Num, ...]         → startsWith [Num, Num], rest allowed
[..., Num]              → endsWith [Num]
```

### Bindings (lowercase ident)

Bindings capture matched parts and pass them to the handler :

```lua
sw:when("{ kind: 'click', x, y }",  -- shorthand : `x` binds key x to a sub-binding
        function(b) return ("at %d,%d"):format(b.x, b.y) end)
```

> [!NOTE]
> Bindings and the `as` operator are advanced features. See matchigo's DSL docs for full reference.

---

## Pre-parsing for reuse

If a pattern is shared across multiple `:when()` calls or switches, parse it once with `EasySwitch.parsePattern(src, scope?, ctx?)` and pass the descriptor :

```lua
local writeMethods = EasySwitch.parsePattern("'POST' | 'PUT' | 'PATCH'")

sw1:when(writeMethods, write_handler)      -- reuses descriptor
sw2:when(writeMethods, log_handler)        -- reuses descriptor
sw3:when(writeMethods, audit_handler)      -- reuses descriptor
```

The DSL is parsed once at the `parsePattern` call ; subsequent `:when()` calls just store a reference.

---

## Common pitfalls

### Forgot to pass the scope

```lua
sw:when("Str | Num", function() ... end)  -- ⚠ no scope, "Str | Num" is treated as DSL
                                           --   (contains `|` ... wait, no, `|` doesn't trigger DSL.
                                           --    "Str | Num" is a literal string here.)
```

If you want DSL behaviour with refs but no leading delimiter, you **must** pass a scope :

```lua
sw:when("Str | Num", { Str = P.string, Num = P.number }, function() ... end)
```

### Used a single quote inside a literal string

```lua
sw:when("won't",  function() ... end)    -- ⚠ — starts with 'w', not a DSL trigger,
                                          --     so it's a literal "won't". Safe.

sw:when("'won't'", function() ... end)   -- DSL trigger : starts with '. Will fail to parse
                                          --   because the apostrophe inside "won't" terminates
                                          --   the string literal early.
```

If you want a literal that contains apostrophes, just don't quote the outer string :

```lua
sw:when("won't", literal_handler)   -- literal "won't"
```

### Empty strict shape vs empty partial

```lua
sw:when("{||}",  empty_strict)   -- matches ONLY {}
sw:when("{}",    empty_partial)  -- matches any table (no fields declared, partial = no constraint)
```

These look almost identical but mean very different things.

---

## See also

- **[Patterns reference](../api/patterns.md)** — `P.*` primitives the DSL compiles into
- **[`Switch:when` API](../api/switch.md#switchwhen-cases-action)** — call shapes
- **[matchigo DSL docs](https://github.com/SUP2Ak/matchigo-lua/blob/main/docs/en/dsl.md)** — full DSL grammar
