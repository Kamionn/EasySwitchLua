-- Example usage of EasySwitchLua
local Switch = require("easyswitch")  -- Capitalized Switch because it's the constructor

local switch = Switch("menu")
    :when("hello", function() return "Hello world!" end)
    :default(function(value) return "Command not found: " .. value end)

print(switch:execute("hello"))  -- Hello world!
print(switch:execute("test"))   -- Command not found: test