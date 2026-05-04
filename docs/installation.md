# Installation

[← Docs index](README.md)

EasySwitchLua works out of the box on standard Lua 5.1+, LuaJIT, FiveM, Roblox (Luau), and LÖVE2D.

---

## Standard Lua / LuaJIT

Drop the source tree (or the bundled `dist/easyswitch.lua`) anywhere on your `package.path` :

```lua
local EasySwitch = require("easyswitch")
```

If `package.path` is awkward in your context, load directly :

```lua
local EasySwitch = dofile("path/to/easyswitch.lua")
```

The bundled file has zero `require()` calls (everything is inlined including the matchigo runtime), so it runs in any sandbox without `package` configuration.

---

## FiveM

Build the bundle once :

```bash
lua build.lua
# → generates dist/easyswitch.lua + dist/easyswitch.min.lua
```

Copy `dist/easyswitch.lua` (or `.min.lua` for shipped builds) into your resource and reference it in `fxmanifest.lua` :

```lua
shared_scripts {
    'easyswitch.lua',
    'client.lua',
    'server.lua',
}
```

`EasySwitch` is then available globally in every script of the resource. No `require` needed.

---

## Roblox (Luau)

1. Run `lua build.lua` from your dev machine to generate `dist/easyswitch.lua`.
2. In Roblox Studio, create a `ModuleScript` named `EasySwitch` under `ReplicatedStorage`.
3. Paste the full contents of `dist/easyswitch.lua` into it.
4. Use it from any script :

```lua
local EasySwitch = require(game.ReplicatedStorage.EasySwitch)

local sw = EasySwitch.new()
    :when("attack", function() print("attacking!") end)
    :when("defend", function() print("defending!") end)
    :default(function(v) print("unknown action:", v) end)

sw:execute("attack")
```

The bundled file has no external `require()` calls and is fully compatible with Luau's sandbox.

---

## LÖVE2D

LÖVE runs on LuaJIT (Lua 5.1 compatibility) — no setup needed. Drop the bundled `dist/easyswitch.lua` into your project :

```lua
-- main.lua
local EasySwitch = require("easyswitch")

local gameState = EasySwitch.new()
    :when("menu",  function() -- draw menu
    end)
    :when("game",  function() -- draw game
    end)
    :when("pause", function() -- draw pause
    end)

function love.keypressed(key)
    if key == "escape" then gameState:execute("pause") end
end
```

---

## Type definitions (LuaLS / EmmyLua)

If you use [`lua-language-server`](https://github.com/LuaLS/lua-language-server) (the engine behind `sumneko.lua` in VSCode), drop the `types/` folder anywhere in your workspace :

```
your-project/
├── easyswitch.lua          ← runtime
└── easyswitch-type/        ← copy of EasySwitchLua/types/ — pick any name
    ├── easyswitch.d.lua
    └── Switch.d.lua
```

The language server picks up `---@meta` files automatically for completion, hover, and type checks. No runtime impact — these files contain definitions only.

For VSCode, place the folder at workspace root (auto-detected) or add it to your `Lua.workspace.library` setting.

---

## Verifying the install

```lua
local EasySwitch = require("easyswitch")
print(EasySwitch.new():when("ping", function() return "pong" end):execute("ping"))
-- expected output : pong
```

If you see `pong`, you're ready. Continue to **[Getting started](getting-started.md)**.
