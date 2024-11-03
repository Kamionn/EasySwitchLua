-- Example usage of EasySwitchLua
local Switch = require("easyswitch")  -- Capitalized Switch because it's the constructor

-- Example 1: Basic switch for a menu
local menuSwitch = Switch("menu")     -- No need for :new(), Switch is already a constructor
    :when("start", function() 
        return "Game started" 
    end)
    :when("quit", function() 
        return "Game ended" 
    end)
    :default(function(action)
        return "Unknown action: " .. action
    end)

-- Example 2: Advanced switch for game logic
local gameSwitch = Switch("game", { maxCases = 50 })
    -- Middleware for processing
    :use(function(value)
        print("Middleware 1: Logging action:", value)
        return value
    end)
    :use(function(value)
        print("Middleware 2: Collecting stats:", value)
        return value
    end)
    -- Before
    :before(function(value)
        print("Before check for value:", value)
        local allowedActions = { start = true, pause = true, resume = true, quit = true }
        return allowedActions[value] ~= nil
    end)
    -- Game actions
    :when("start", function()
        return "Game started"
    end)
    :when({"pause", "resume"}, function(state)
        return "Game state changed to: " .. state
    end)
    :when("quit", function()
        return "Game ended"
    end)
    :default(function(state)
        return "Unknown action: " .. state
    end)

-- Events for debugging and monitoring
gameSwitch
    :on("beforeExecute", function(value)
        print("Before execution:", value)
    end)
    :on("afterExecute", function(value, result)
        print("After execution:", value, "->", result)
    end)
    :on("error", function(type, err)
        print("Error in", type .. ":", err)
    end)
    :on("cacheHit", function(value, cached)
        print("Cache hit for:", value)
    end)

-- Tests and demonstration
print("\n=== Test Menu Switch ===")
print(menuSwitch:execute("start"))  -- "Game started"
print(menuSwitch:execute("quit"))   -- "Game ended"
print(menuSwitch:execute("other"))  -- "Unknown action: other"

print("\n=== Test Game Switch ===")
-- First call (without cache)
print(gameSwitch:execute("start"))

-- Second call (with cache)
print(gameSwitch:execute("start"))

-- Test multiple cases
print(gameSwitch:execute("pause"))
print(gameSwitch:execute("resume"))

-- Clear cache and test
gameSwitch:clearCache()
print("\n=== After Cache Clear ===")
print(gameSwitch:execute("start"))
