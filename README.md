# EasySwitchLua

An advanced and performant switch system for Lua with event handling, middleware, and optimized caching.

## ⚡ Installation

```lua
-- Copy files into your project
local Switch = require("easyswitch")
```

## 🚀 Basic Usage

```lua
local Switch = require("easyswitch")

-- Creating a basic switch
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

-- Usage
print(menuSwitch:execute("start"))  -- "Game started"
print(menuSwitch:execute("quit"))   -- "Game ended"
print(menuSwitch:execute("other"))  -- "Unknown action: other"

-- Multiple cases
local commandSwitch = Switch("commands")
    :when({"save", "backup"}, function(action)
        return "Saving game..."
    end)

print(commandSwitch:execute("save"))    -- "Saving game..."
print(commandSwitch:execute("backup"))  -- "Saving game..."
```

## 🔥 Advanced Features

### Middleware
```lua
local authSwitch = Switch("auth")
    -- Input transformation
    :use(function(action)
        return string.upper(action)
    end)
    :when("LOGIN", function()
        return "Logging in..."
    end)

print(authSwitch:execute("login"))  -- "Logging in..."
```

### Before Execution Checks
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

print(secureSwitch:execute("start")) -- "Starting secure process..."
print(secureSwitch:execute("invalid")) -- nil, before check fails
```


### Events (Debug/Logging)
```lua
local debugSwitch = Switch("debug")
    -- Before execution
    :on("beforeExecute", function(value)
        print("Executing:", value)
    end)
    -- After execution
    :on("afterExecute", function(value, result)
        print("Result:", result)
    end)
    -- On error
    :on("error", function(type, err)
        print("Error in", type .. ":", err)
    end)
    :when("test", function()
        return "test ok"
    end)

debugSwitch:execute("test")
```

### Automatic Caching
The system automatically caches results with intelligent memory management using pairs.

```lua
local expensiveSwitch = Switch("expensive")
    :when("calc", function()
        -- Expensive operation
        local result = 0
        for i = 1, 1000000 do
            result = result + i
        end
        return result
    end)

-- First call: calculates
print(expensiveSwitch:execute("calc"))
-- Second call: uses cache
print(expensiveSwitch:execute("calc"))
```

## ⚙️ Configuration

```lua
local switch = Switch("config", {
    maxCases = 1000  -- Case limit (default: 100)
})
```

## 📋 Available Events

- `beforeExecute`: Before execution
- `afterExecute`: After execution
- `error`: On error
- `cacheHit`: Cache found
- `cacheMiss`: Cache not found
- `middlewareStart`: Middleware start
- `middlewareEnd`: Middleware end
- `noMatch`: No match found

## 🎮 Complete Example (State Machine)

```lua
local gameState = {
    score = 0,
    lives = 3
}

local gameSwitch = Switch("game")
    -- Middleware for logging
    :use(function(action)
        print("Game action:", action)
        return action
    end)
    -- Events for debug
    :on("beforeExecute", function(action)
        print("Current state - Score:", gameState.score, "Lives:", gameState.lives)
    end)
    -- Game actions
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
    :default(function(action)
        return "UNKNOWN_ACTION"
    end)

-- Game simulation
print(gameSwitch:execute("start"))    -- Reset and start
print(gameSwitch:execute("score"))    -- Score +100
print(gameSwitch:execute("hit"))      -- Lose a life
```

## 🔧 Performance

The system uses several optimizations:
- Cache with pairs for automatic memory management
- Middleware compilation
- Lookup minimization
- Fluent method chaining

## 🤝 Contributing

Contributions are welcome! Feel free to open an issue or submit a pull request.

## 📄 License

[MIT License](LICENSE.md)
