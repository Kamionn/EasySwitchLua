-- Complex EasySwitch usage : registry + middleware + before-gate + events +
-- opt-in memoize. Run from project root :
--   lua examples/_switch_complex_example.lua

local EasySwitch = require("easyswitch")

-- Wipe the registry first so re-runs don't double-register the named switches.
EasySwitch.clear()

-- Example 1 : basic menu via the named registry.
local menuSwitch = EasySwitch("menu")
    :when("start", function() return "Game started" end)
    :when("quit",  function() return "Game ended"   end)
    :default(function(action) return "Unknown action: " .. action end)

-- Example 2 : game logic switch with the full pipeline. We do NOT enable
-- :memoize() here because actions log + mutate state — caching would
-- swallow the side effects on repeated calls.
local gameSwitch = EasySwitch("game")
    -- Middlewares run in declaration order before dispatch.
    :use(function(value)
        print("Middleware 1: Logging action:", value)
        return value
    end)
    :use(function(value)
        print("Middleware 2: Collecting stats:", value)
        return value
    end)
    -- Gate : block any value that isn't a known action up front.
    :before(function(value)
        print("Before check for value:", value)
        local allowedActions = { start = true, pause = true, resume = true, quit = true }
        return allowedActions[value] ~= nil
    end)
    -- Game actions.
    :when("start", function() return "Game started" end)
    :when({ "pause", "resume" }, function(state) return "Game state changed to: " .. state end)
    :when("quit",  function() return "Game ended" end)
    :default(function(state) return "Unknown action: " .. state end)

-- Events for debugging / monitoring. Skip if no listener is bound is
-- handled inside :execute, so attaching events doesn't slow the hot path
-- of switches that don't subscribe.
gameSwitch
    :on("beforeExecute", function(value)
        print("Before execution:", value)
    end)
    :on("afterExecute", function(value, result)
        print("After execution:", value, "->", result)
    end)
    :on("beforeCheckFailed", function(value)
        print("Gate blocked:", value)
    end)
    :on("error", function(stage, err)
        print("Error in", stage .. ":", err)
    end)

-- Example 3 : a switch where memoize is appropriate — pure compute,
-- no side effects. `:memoize({ verify = true })` would re-run on every
-- HIT to catch non-determinism (dev-only, slow).
local pure = EasySwitch.new():memoize()
    :when(EasySwitch.P.number, function(n) return n * n end)
    :default(function() return nil end)

print("\n=== Test Menu Switch ===")
print(menuSwitch:execute("start")) -- Game started
print(menuSwitch:execute("quit"))  -- Game ended
print(menuSwitch:execute("other")) -- Unknown action: other

print("\n=== Test Game Switch ===")
print(gameSwitch:execute("start"))  -- runs full pipeline + emits events
print(gameSwitch:execute("start"))  -- runs full pipeline AGAIN (no cache)
print(gameSwitch:execute("pause"))
print(gameSwitch:execute("resume"))
print(gameSwitch:execute("invalid")) -- gate blocks, beforeCheckFailed fires

print("\n=== Memoize demo ===")
print(pure:execute(7))  -- 49 (computed)
print(pure:execute(7))  -- 49 (cached HIT, action did not run)
pure:clearCache()
print(pure:execute(7))  -- 49 (cache cleared, computed again)

EasySwitch.clear() -- be a good citizen, leave the registry empty.
