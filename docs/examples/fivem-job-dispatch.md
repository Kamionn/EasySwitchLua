# Example — FiveM job dispatch

[← Docs index](../README.md)

A FiveM-style dispatcher : map players' job names to roles. Demonstrates `P.luaPattern` for prefix matching, `P.union` for finite enums, and the named registry (so the same dispatcher is reachable from any client/server script).

---

## Goal

```
Job name pattern         Role
-------------------------+--------------
police, police_lspd, ...  → "PD"
mechanic_*                → "Garage"
ambulance, doctor         → "EMS"
any non-empty string      → "Civilian — <name>"
anything else             → "No job"
```

---

## Setup

```lua
-- shared/dispatcher.lua : load order in fxmanifest.lua should put this BEFORE
-- any client.lua / server.lua that references the registry.

local EasySwitch = require("easyswitch")  -- or just `EasySwitch`
                                          -- if loaded via shared_scripts as a global.
local P = EasySwitch.P

EasySwitch("job-roles")
    -- Police : any name starting with "police"
    :when(P.luaPattern("^police"), function(job) return "PD — " .. job end)

    -- Mechanic : any name starting with "mechanic_"
    :when(P.luaPattern("^mechanic_"), function(job) return "Garage — " .. job end)

    -- EMS : finite enum
    :when(P.union("ambulance", "doctor"), function() return "EMS" end)

    -- Civilian : any non-empty string
    :when(P.intersection(P.string, P.minLengthStr(1)),
          function(job) return "Civilian — " .. job end)

    -- Catch nil, empty string, non-string
    :default(function() return "No job" end)
```

---

## Use it from a client / server script

```lua
-- somewhere_else.lua
local roles = EasySwitch.get("job-roles")

print(roles:execute("police_lspd"))     -- "PD — police_lspd"
print(roles:execute("mechanic_bennys"))  -- "Garage — mechanic_bennys"
print(roles:execute("ambulance"))        -- "EMS"
print(roles:execute("baker"))            -- "Civilian — baker"
print(roles:execute(""))                  -- "No job"
print(roles:execute(nil))                 -- "No job"
```

---

## What this example demonstrates

| Technique | Where | Why |
|---|---|---|
| Named registry | `EasySwitch("job-roles")` | Share the dispatcher across `client.lua` / `server.lua` without exporting it from a module |
| `P.luaPattern("^prefix")` | police, mechanic | Prefix matching with built-in Lua patterns |
| `P.union` | ambulance, doctor | Finite enum, hash O(1) |
| `P.intersection(P.string, P.minLengthStr(1))` | civilian | Multi-condition match — must be a string AND non-empty |
| `:default` | "No job" | Catches `nil`, `""`, numbers, etc. |
| Rule ordering | most specific first | Police prefix before civilian fallback |

> [!IMPORTANT]
> `P.luaPattern("^police")` matches `police_lspd` AND `police_bcso` AND `police` itself. If you need exact match, use the literal `"police"` instead — it's faster (Map fast-path) and unambiguous.

---

## Adding events for moderation

```lua
local roles = EasySwitch.get("job-roles")

roles:on("noMatch", function(job)
    -- This fires only when both rules and default fail to produce a result.
    -- With our dispatcher, the default always handles it, so noMatch never fires.
    -- But if you remove the default, this becomes useful.
    print("[mod] unhandled job name:", job)
end)
```

For audit logs, `afterExecute` is more useful :

```lua
roles:on("afterExecute", function(job, role)
    -- Log every dispatch
    log_audit("job dispatched", { job = job, role = role })
end)
```

---

## Memoize this dispatcher ?

Job-to-role mapping is **deterministic** (same job name always produces same role) and the same names recur often (a server with 100 players probably has only ~20 distinct jobs). Memoize is a fit :

```lua
EasySwitch("job-roles"):memoize()
    :when(P.luaPattern("^police"), ...)
    -- ...
```

The cache uses weak refs, so memory pressure self-regulates. After the first dispatch per unique job name, subsequent dispatches are cache HITs (~74 ns each).

> [!NOTE]
> If your handlers ever fire side effects (logging the dispatch, incrementing a counter), memoize would suppress them on cache HITs. Leave memoize off in that case, or move the side effects to a `:on("afterExecute")` listener that runs even for cache hits.

---

## Hot-reload safety

If your FiveM resource gets `restart`'d, the registry persists across the restart in the same shared Lua VM (depending on the runtime). To avoid double-registration errors :

```lua
-- shared/dispatcher.lua
EasySwitch.clear("job-roles")    -- idempotent — no-op if not present

EasySwitch("job-roles")
    :when(P.luaPattern("^police"), ...)
    -- ...
```

`EasySwitch.clear(name)` is safe to call even when nothing is registered under that name.

See **[Named registry guide](../guides/named-registry.md#hot-reload-pattern)**.

---

## Variations

### Different dispatchers per role group

You can register multiple named switches and look them up independently :

```lua
EasySwitch("job-roles"):when(...)              -- the dispatcher above
EasySwitch("permissions"):when(...)            -- another, for command perms
EasySwitch("vehicle-spawning"):when(...)       -- yet another, for vehicle access

-- Anywhere in the codebase :
local role = EasySwitch.get("job-roles"):execute(player.job)
local can  = EasySwitch.get("permissions"):execute({ role = role, cmd = "/kick" })
```

### DSL strings for compact rules

```lua
EasySwitch("job-roles")
    :when("'ambulance' | 'doctor'",  function() return "EMS" end)
    :when(P.luaPattern("^police"),   function(j) return "PD — " .. j end)
    :when(P.luaPattern("^mechanic_"), function(j) return "Garage — " .. j end)
    :default(function(j)
        if type(j) == "string" and #j > 0 then
            return "Civilian — " .. j
        end
        return "No job"
    end)
```

The first rule uses the DSL union syntax — equivalent to `P.union("ambulance", "doctor")`. Pure cosmetic preference.

---

## See also

- **[Named registry guide](../guides/named-registry.md)** — when to use the registry
- **[Patterns reference](../api/patterns.md)** — `P.luaPattern`, `P.union`, `P.intersection`
- **[Memoize guide](../guides/memoize.md)** — when caching is appropriate
