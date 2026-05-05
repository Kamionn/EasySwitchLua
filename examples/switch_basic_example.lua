-- Basic EasySwitch usage. Run from project root :
--   lua examples/switch_basic_example.lua

local EasySwitch = require("easyswitch")

-- Anonymous switch — recommended.
local switch = EasySwitch.new()
    :when("hello", function() return "Hello world!" end)
    :default(function(value) return "Command not found: " .. value end)

print(switch:execute("hello")) -- Hello world!
print(switch:execute("test"))  -- Command not found: test

-- Named registry — persists in `EasySwitch.get(name)` until :clear()'d.
local menu = EasySwitch("menu")
    :when({"start", "quit"}, function(v) return "menu:" .. v end)
    :default(function() return "menu:?" end)

print(menu:execute("start")) -- menu:start
print(menu:execute("foo"))   -- menu:?

-- Look it up later from anywhere — same instance.
assert(EasySwitch.get("menu") == menu)

EasySwitch.clear() -- wipe the registry so re-runs of this script don't double-register.
