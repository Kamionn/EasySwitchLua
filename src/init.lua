-- Main entry point: combines anonymous factory, named registry, and pattern vocabulary.
--
-- Usage:
--   local EasySwitch = require("easyswitch")
--
--   -- Anonymous (recommended, fully portable)
--   local sw = EasySwitch.new()
--
--   -- Named registry (backward-compatible)
--   local sw = EasySwitch("menu")
--
--   -- Patterns
--   local P = EasySwitch.P

local Switch   = require("src.switch")
local Registry = require("src.registry")
local P        = require("src.patterns")

local EasySwitch = setmetatable({
    new         = Switch.new,
    P           = P,
    FALLTHROUGH = Switch.FALLTHROUGH,
    get         = Registry.get,
    clear       = Registry.clear,
    registered  = Registry.registered,
}, {
    -- EasySwitch("name", opts) → named registry mode (backward-compat)
    __call = function(_, name, options)
        return Registry.create(name, options)
    end,
})

return EasySwitch
