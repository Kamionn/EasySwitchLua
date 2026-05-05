# Guide — Memoize (opt-in cache)

[← Docs index](../README.md) · [Switch:memoize API](../api/switch.md#switchmemoize-opts)

EasySwitch v2 has **no implicit cache**. Calling `:execute(value)` runs the full dispatch pipeline every time. To cache results, opt in with `:memoize()`.

```lua
local sw = EasySwitch.new():memoize()
    :when("expensive", function() return slow_compute() end)

sw:execute("expensive")  -- runs slow_compute()
sw:execute("expensive")  -- returns cached result, action does NOT re-run
```

---

## When should I use memoize ?

Memoize is the right tool when **all three** of these are true :

1. **Your action is deterministic** — same input always produces same output, no side effects.
2. **The same input gets dispatched repeatedly** — cache hit rate is meaningful (e.g. >20% of calls).
3. **The action is non-trivial** — at least a few microseconds of work, or it doesn't earn the cache cost.

If any of those is false, leave memoize off. v2's raw dispatch is already faster than v1's cache HIT path on most realistic workloads.

### Good fits for memoize

- **Config lookups** — `sw:execute(key)` returns a derived setting that's expensive to compute.
- **Pure parsing / formatting** — `sw:execute(rawString)` returns a parsed structure ; same string → same structure.
- **Pure mathematical mappings** — `sw:execute(n)` returns `expensive_math(n)`.

### Bad fits for memoize

- **Logging / metrics** — actions with side effects need to run on every dispatch.
- **Time-sensitive results** — if "now" matters, the cached result becomes stale.
- **Stateful actions** — actions that read or mutate external state.
- **Unique-input streams** — if every call has a fresh value, cache fills with one-shot entries that never hit. Memoize-OFF wins here.

---

## What gets cached

| Result | Cached ? | Why |
|---|---|---|
| Action returned a non-nil value | ✓ | Standard cache hit |
| Action returned `nil` | ✗ | Avoid shadowing future rules — see below |
| Default fired | ✓ | Default is a regular action |
| Action returned `EasySwitch.FALLTHROUGH` | depends on what next rule returned | The cache stores the **final** result of `:execute()` |
| Gate (`:before`) blocked | ✗ | `:execute()` returns nil, nothing to cache |
| Action errored (safe mode) | ✗ | `nil` is returned, not cached |

**Why `nil` results aren't cached** : if you dispatch `"foo"`, no rule matches, and you cache `nil`, then later add `:when("foo", ...)`, the cache would shadow your new rule. To avoid this footgun, cache misses are simply not stored.

---

## What can't be a cache key

Lua tables disallow `nil` and `NaN` as keys. EasySwitch detects these and skips caching for them — your `:execute(nil)` and `:execute(0/0)` calls always run the full pipeline.

```lua
sw:memoize()
sw:execute(nil)    -- runs pipeline, NOT cached
sw:execute(0/0)    -- runs pipeline, NOT cached
sw:execute("ok")   -- runs pipeline, cached
sw:execute("ok")   -- cache HIT
```

---

## Cache invalidation

Mutating the switch automatically wipes the cache so a new rule never runs against stale entries :

| Method called | Cache invalidated ? |
|---|---|
| `:when(...)` | ✓ |
| `:default(...)` | ✓ |
| `:use(middleware)` | ✓ |
| `:before(check)` | ✓ |
| `:on(event, cb)` | ✗ (events don't affect dispatch result) |
| `:clearEvents(...)` | ✗ (ditto) |

You can also clear manually :

```lua
sw:clearCache()       -- empties the cache, memoize stays enabled
```

> [!NOTE]
> `:clearCache()` is a no-op when memoize is disabled. Calling it on a non-memoized switch is safe and free.

---

## Verify mode (development)

If you're not 100% sure your action is deterministic, enable verify mode :

```lua
local sw = EasySwitch.new():memoize({ verify = true })
    :when("test", function() return os.time() end)  -- non-deterministic !

sw:execute("test")   -- caches the current time
sw:execute("test")   -- ⚠ ERROR : "Memoize verify failed for input test :
                     --   cached=1714828512, action returned 1714828513.
                     --   Your action is non-deterministic ; do not enable memoize."
```

In verify mode, every cache HIT re-runs the **full pipeline** (gate + middleware + dispatcher) and compares the fresh result against the cached one. If they differ, `:execute()` errors out with a descriptive message.

> [!IMPORTANT]
> Verify mode is **slow** by design — it does the work twice. **Do not ship `verify = true` to production**. Use it during development to catch non-deterministic actions, then disable it.

### Toggling verify

`:memoize({ verify = true })` and `:memoize({ verify = false })` (or `:memoize()`) can be called repeatedly to toggle the verify flag without recreating the cache.

```lua
sw:memoize({ verify = true })   -- dev
-- ... testing ...
sw:memoize()                    -- prod (verify off, memoize stays on)
```

---

## Weak references

The cache uses `__mode = "kv"` — both keys and values are weak. This means :

- If a value (the cached result) is a table that's no longer referenced anywhere else, the GC can reclaim it and remove the cache entry.
- If a key is a table that's no longer referenced anywhere else, the entry is also reclaimed.

Practical consequence : caching results of dispatch on **table inputs** rarely yields hits across calls (each new table has a different identity). For table-keyed memoization, you'd typically want a custom key (e.g. a serialised version), which is exactly the kind of thing the user-side wrapper handles better than us.

---

## Performance characteristics

From the [v1 vs v2 bench](../../test_bench/v1_vs_v2.lua) :

| Scenario | v1 cache HIT | v2 memoize OFF | v2 memoize HIT |
|---|---:|---:|---:|
| Repeated literal lookup | 118 ns | 134 ns | **74 ns** |
| Pattern dispatch, unique values | 539 ns *(cache miss × 2)* | **331 ns** | n/a (no hits) |

Memoize HIT in v2 is **1.6× faster than v1's cache HIT** because the lookup happens before the events / middleware / dispatcher, and the v2 cache uses direct table access rather than a method call.

For unique-value streams (the realistic case), memoize OFF beats v1's cache because v1's cache adds setup cost on every miss.

---

## When to memoize : decision tree

```
Is your action deterministic ?
├── No → Don't memoize.
└── Yes
    │
    └── Will the same input recur often ?
        ├── No → Don't memoize. v2's raw dispatch is already fast.
        └── Yes
            │
            └── Is the action expensive ?
                ├── No → Probably skip memoize. The cache cost is comparable to the action cost.
                └── Yes → Memoize.
                    │
                    └── In dev → :memoize({ verify = true })
                    └── In prod → :memoize()
```

---

## See also

- **[Switch:memoize API](../api/switch.md#switchmemoize-opts)** — full method signature
- **[Switch:clearCache API](../api/switch.md#switchclearcache)** — manual cache clear
- **[v1 → v2 migration : caching](../migration-v1-to-v2.md#caching--opt-in-memoize)** — what changed and why
