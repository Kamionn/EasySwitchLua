-- EasySwitch v2 entry point. Combines :
--   • the anonymous `Switch.new()` factory
--   • the named registry (`EasySwitch("name")` or `EasySwitch("name", opts)`)
--   • matchigo's pattern vocabulary (`P`, `parsePattern`, `Map`, `Set`, `BigInt`)
--
-- v2 is a thin builder around matchigo : pattern-test logic, the DSL, and
-- the supporting types all come from matchigo. EasySwitch contributes the
-- builder-style API, events, middleware, gate, and named registry.
--
-- Usage :
--   local EasySwitch = require("easyswitch")
--   local P  = EasySwitch.P
--
--   -- Anonymous (recommended)
--   local sw = EasySwitch.new()
--
--   -- Named (registry mode)
--   local sw = EasySwitch("menu")
--
--   -- DSL strings work directly in :when()
--   sw:when("{| kind: 'click', x: Num |}", { Num = P.number }, action)

local Switch   = require("src.switch")
local Registry = require("src.registry")
local matchigo = require("vendor.matchigo")

local EasySwitch = setmetatable({
    new          = Switch.new,
    P            = matchigo.P,
    parsePattern = matchigo.parsePattern,
    Map          = matchigo.Map,
    Set          = matchigo.Set,
    BigInt       = matchigo.BigInt,
    FALLTHROUGH  = Switch.FALLTHROUGH,
    get          = Registry.get,
    clear        = Registry.clear,
}, {
    __call = function(_, name, options)
        return Registry.create(name, options)
    end,
})

return EasySwitch
