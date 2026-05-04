# Example — HTTP router

[← Docs index](../README.md)

A small HTTP router built with EasySwitch. Dispatches on `(method, path)` tuples, uses `P.luaPattern` for path patterns, `P.union` for method groups, and `:on("noMatch")` to log unhandled routes.

---

## Goal

```
GET    /api/users      → list users
GET    /api/users/123  → get user 123
POST   /api/users      → create user
PUT    /api/users/123  → update user 123
DELETE /api/users/123  → delete user 123
*      /health         → ok (any method)
*      *               → 405 method not allowed
```

---

## Setup

```lua
local EasySwitch = require("easyswitch")
local P = EasySwitch.P

-- Each request is a table { method = "...", path = "..." }
```

---

## Build the router

```lua
local function ok(body)         return { status = 200, body = body } end
local function notAllowed()     return { status = 405, body = "Method Not Allowed" } end
local function notFound()       return { status = 404, body = "Not Found"          } end

local router = EasySwitch.new()
    -- Health check : any method, exact path
    :when({ method = P.any, path = "/health" }, function()
        return ok("alive")
    end)

    -- GET /api/users — list
    :when({ method = "GET", path = "/api/users" }, function()
        return ok({ user1 = "Alice", user2 = "Bob" })
    end)

    -- GET /api/users/<id> — read one
    :when({ method = "GET", path = P.luaPattern("^/api/users/%d+$") }, function(req)
        local id = req.path:match("^/api/users/(%d+)$")
        return ok({ id = tonumber(id), name = "User #" .. id })
    end)

    -- POST /api/users — create
    :when({ method = "POST", path = "/api/users" }, function()
        return ok("created")
    end)

    -- PUT/PATCH /api/users/<id> — update
    :when({ method = P.union("PUT", "PATCH"), path = P.luaPattern("^/api/users/%d+$") },
          function(req)
              local id = req.path:match("^/api/users/(%d+)$")
              return ok("updated " .. id)
          end)

    -- DELETE /api/users/<id> — delete
    :when({ method = "DELETE", path = P.luaPattern("^/api/users/%d+$") },
          function(req)
              local id = req.path:match("^/api/users/(%d+)$")
              return ok("deleted " .. id)
          end)

    -- Path matched but method didn't
    :when({ path = P.luaPattern("^/api/") }, function()
        return notAllowed()
    end)

    -- Catch-all
    :default(function() return notFound() end)

    -- Logging
    :on("afterExecute", function(req, resp)
        print(("%s %s → %d"):format(req.method, req.path, resp.status))
    end)
```

---

## Use it

```lua
router:execute({ method = "GET",    path = "/health" })             -- 200 alive
router:execute({ method = "GET",    path = "/api/users" })          -- 200 user list
router:execute({ method = "GET",    path = "/api/users/42" })       -- 200 user 42
router:execute({ method = "POST",   path = "/api/users" })          -- 200 created
router:execute({ method = "PUT",    path = "/api/users/42" })       -- 200 updated 42
router:execute({ method = "PATCH",  path = "/api/users/42" })       -- 200 updated 42
router:execute({ method = "DELETE", path = "/api/users/42" })       -- 200 deleted 42

router:execute({ method = "POST",   path = "/api/users/42" })       -- 405 not allowed
router:execute({ method = "GET",    path = "/something-else" })     -- 404 not found
```

Console output (from the `afterExecute` listener) :

```
GET /health → 200
GET /api/users → 200
GET /api/users/42 → 200
POST /api/users → 200
PUT /api/users/42 → 200
PATCH /api/users/42 → 200
DELETE /api/users/42 → 200
POST /api/users/42 → 405
GET /something-else → 404
```

---

## What this example demonstrates

| Technique | Where | Why |
|---|---|---|
| Partial table pattern | `{ method = ..., path = ... }` | Matches against multiple fields without strict shape ; extra fields on `req` are ignored |
| `P.luaPattern` | path matching | Lua patterns are familiar and built-in |
| `P.union` | method groups | `PUT` + `PATCH` share a handler |
| `P.any` | `/health` | Match any method |
| Rule order | catch-all at end | More specific rules first, broader rules after |
| `:default` | `notFound()` | Fallback when no rule matched |
| `:on("afterExecute")` | logging | Observe every dispatch without polluting handlers |

---

## Variations

### Add memoize for static endpoints

If `/health` is hit thousands of times per minute and always returns the same response, memoize it... but only that switch :

```lua
local healthCheck = EasySwitch.new():memoize()
    :when({ method = P.any, path = "/health" }, function() return ok("alive") end)
    :default(function() return router:execute(...) end)  -- delegate
```

Better : memoize **the action's output cache** rather than the dispatch result, so different methods on `/health` don't collide. In practice : keep the router non-memoized, cache at the application layer.

### Pre-compile path patterns

If the same path pattern is used in multiple rules, pre-parse it once :

```lua
local userIdPath = P.luaPattern("^/api/users/%d+$")

router
    :when({ method = "GET",    path = userIdPath }, get_user)
    :when({ method = "PUT",    path = userIdPath }, update_user)
    :when({ method = "DELETE", path = userIdPath }, delete_user)
```

### DSL strings for dense route tables

```lua
router
    :when("{| method: 'GET',  path: '/health' |}",       function() return ok("alive") end)
    :when("{| method: 'GET',  path: '/api/users' |}",    list_users)
    :when("{| method: 'POST', path: '/api/users' |}",    create_user)
    :when("{| method: 'PUT', path: PathId |}", { PathId = userIdPath }, update_user)
```

`{| ... |}` is the strict shape syntax (refuses extras), exactly equivalent to `P.shape(...)`.

---

## See also

- **[Pattern matching guide](../guides/pattern-matching.md)** — partial vs strict shape
- **[Patterns reference](../api/patterns.md)** — `P.luaPattern`, `P.union`, `P.any`
- **[Events API](../api/events.md)** — `afterExecute` payload
