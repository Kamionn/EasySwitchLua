# EasySwitchLua

An advanced switch helper for Lua with event hooks, middleware, optional result caching, and fluent method chaining.

## Installation

```lua
-- Copy the files into your project.
local Switch = require("easyswitch")
```

## Basic Usage

```lua
local Switch = require("easyswitch")

local menuSwitch = Switch("menu")
    :when("start", function()
        return "Game started"
    end)
    :when("quit", function()
        return "Game ended"
    end)
    :default(function(action)
        return "Unknown action: " .. action
    end)

print(menuSwitch:execute("start"))  -- "Game started"
print(menuSwitch:execute("quit"))   -- "Game ended"
print(menuSwitch:execute("other"))  -- "Unknown action: other"
```

## Multiple Cases

```lua
local commandSwitch = Switch("commands")
    :when({ "save", "backup" }, function(action)
        return "Saving game..."
    end)

print(commandSwitch:execute("save"))    -- "Saving game..."
print(commandSwitch:execute("backup"))  -- "Saving game..."
```

## Middleware

Middlewares run before dispatch and can transform the value used to find the action.

```lua
local authSwitch = Switch("auth")
    :use(function(action)
        return string.upper(action)
    end)
    :when("LOGIN", function()
        return "Logging in..."
    end)

print(authSwitch:execute("login"))  -- "Logging in..."
```

## Before Checks

```lua
local secureSwitch = Switch("secure")
    :before(function(action)
        local allowedActions = { start = true, stop = true }
        return allowedActions[action] ~= nil
    end)
    :when("start", function()
        return "Starting secure process..."
    end)
    :when("stop", function()
        return "Stopping secure process..."
    end)

print(secureSwitch:execute("start"))   -- "Starting secure process..."
print(secureSwitch:execute("invalid")) -- nil
```

## Events

```lua
local debugSwitch = Switch("debug")
    :on("beforeExecute", function(value)
        print("Executing:", value)
    end)
    :on("afterExecute", function(value, result, finalValue)
        print("Result:", result)
    end)
    :on("error", function(kind, err)
        print("Error in", kind .. ":", err)
    end)
    :when("test", function()
        return "test ok"
    end)

debugSwitch:execute("test")
```

Available events:

- `beforeExecute`: before validation, middleware, cache, and dispatch
- `afterExecute`: after execution, cache hit, failed before check, or handled error
- `error`: when a before check, middleware, action, or event callback fails
- `cacheHit`: cached result found
- `cacheMiss`: cached result not found
- `middlewareStart`: middleware chain starts
- `middlewareEnd`: middleware chain ends
- `beforeCheckFailed`: `before()` returned false or nil
- `noMatch`: no action and no default handler matched the final value

## Caching

Caching is enabled by default. The cache is checked after `before()` and middleware execution, so validation and transformations still run. Cache entries are cleared when actions, middleware, default action, or before checks are changed.

Disable caching for actions with side effects, such as state machines, counters, database writes, or game state mutations:

```lua
local stateSwitch = Switch("state", { cache = false })
```

You can opt into weak cache storage:

```lua
local switch = Switch("weak-cache", {
    weakCache = true
})
```

## Configuration

```lua
local switch = Switch("config", {
    maxCases = 1000, -- Case limit. Default: 100.
    cache = true,    -- Enable result caching. Default: true.
    weakCache = false
})
```

## Complete Example

```lua
local gameState = {
    score = 0,
    lives = 3
}

local gameSwitch = Switch("game", { cache = false })
    :use(function(action)
        print("Game action:", action)
        return action
    end)
    :on("beforeExecute", function(action)
        print("Current state - Score:", gameState.score, "Lives:", gameState.lives)
    end)
    :when("start", function()
        gameState.score = 0
        gameState.lives = 3
        return "PLAYING"
    end)
    :when("hit", function()
        gameState.lives = gameState.lives - 1
        return gameState.lives > 0 and "PLAYING" or "GAME_OVER"
    end)
    :when("score", function()
        gameState.score = gameState.score + 100
        return "PLAYING"
    end)
    :default(function()
        return "UNKNOWN_ACTION"
    end)

print(gameSwitch:execute("start"))
print(gameSwitch:execute("score"))
print(gameSwitch:execute("hit"))
```

## License

[MIT License](LICENSE)
