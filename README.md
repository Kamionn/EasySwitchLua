# EasySwitchLua

[![CI](https://github.com/Kamionn/EasySwitchLua/actions/workflows/ci.yml/badge.svg)](https://github.com/Kamionn/EasySwitchLua/actions/workflows/ci.yml) [![version](https://img.shields.io/github/v/tag/Kamionn/EasySwitchLua?label=version&color=orange&sort=semver)](https://github.com/Kamionn/EasySwitchLua/tags) [![focus](https://img.shields.io/badge/focus-Switch%20%2F%20Dispatcher-purple)](https://img.shields.io/badge/focus-Switch%20%2F%20Dispatcher-purple) [![lang](https://img.shields.io/badge/lang-Lua%205.1%2B%20%2F%20LuaJIT%20%2F%20Luau-green)](https://img.shields.io/badge/lang-Lua%205.1%2B%20%2F%20LuaJIT%20%2F%20Luau-green) [![license](https://img.shields.io/badge/license-MIT-blue)](./LICENSE)

A builder-style switch / pattern-matching library for Lua with middleware, events, opt-in memoize, and structural dispatch. Built on top of [matchigo-lua](https://github.com/SUP2Ak/matchigo-lua) (vendored in the bundle) for pattern-test logic and the optional Rust-style DSL.

Works on standard Lua 5.1+, LuaJIT, FiveM, Roblox (Luau), and LÖVE2D.

📖 **[Full documentation in `docs/`](docs/README.md)** — installation, API reference, guides, examples, v1→v2 migration.

---


## Install

> [!WARNING]
> **Download the named release asset, not "Source code (zip)"** — the source archive does not include the bundled dist (`dist/` is gitignored).

Grab `EasySwitchLua-vX.Y.Z.zip` from the [Releases page](https://github.com/Kamionn/EasySwitchLua/releases), extract `easyswitch.lua`, then :

```lua
local EasySwitch = require("easyswitch")
```

FiveM / Roblox / LÖVE2D specifics — see **[docs/installation.md](docs/installation.md)**.

---

## Quickstart

```lua
local EasySwitch = require("easyswitch")
local P = EasySwitch.P

local router = EasySwitch.new()
    :when("GET",                       function()  return "list"          end)
    :when({"POST", "PUT"},             function(m) return "write:" .. m   end)
    :when(P.union("DELETE", "PATCH"),  function(m) return "modify:" .. m  end)
    :when(P.string,                    function(v) return "str:"  .. v    end)
    :default(function(v)               return "unhandled: " .. tostring(v) end)

print(router:execute("GET"))    -- list
print(router:execute("POST"))   -- write:POST
print(router:execute("hello"))  -- str:hello
print(router:execute(42))       -- unhandled: 42
```

→ **[Getting started](docs/getting-started.md)** for a 5-minute walkthrough, **[API reference](docs/api/)** for the full surface.

---

## Features

- **[Pattern matching](docs/guides/pattern-matching.md)** — type sentinels, unions, intersections, shapes, ranges, predicates
- **[DSL strings](docs/guides/dsl-strings.md)** — Rust-style match arms inside `:when()`, parsed once at construction
- **[Middleware](docs/guides/middleware.md)** — chain transforms before dispatch with `:use(fn)`
- **[Events](docs/api/events.md)** — 7 hooks (`beforeExecute`, `afterExecute`, `noMatch`, `error`, ...)
- **[Memoize](docs/guides/memoize.md)** — opt-in result caching with optional verify mode
- **[Fallthrough](docs/guides/fallthrough.md)** — `EasySwitch.FALLTHROUGH` sentinel for layered rules
- **[Named registry](docs/guides/named-registry.md)** — `EasySwitch("name")` for cross-module dispatchers

Coming from EasySwitchLua v1 (cache + actionManager era) ? See **[Migration v1 → v2](docs/migration-v1-to-v2.md)**.

---

## License

[MIT](LICENSE)
