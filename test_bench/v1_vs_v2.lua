-- A/B bench : EasySwitch v1 (legacy bundle, with cacheManager + closures-per-instance)
-- vs EasySwitch v2 (matchigo-vendored, shared metatable, opt-in memoize).
--
-- Run from EasySwitchLua/ root :  lua test_bench/v1_vs_v2.lua
--
-- The bench framework (`bench.lua`) lives next to this file, vendored from
-- matchigo so EasySwitch's bench suite is self-contained.
package.path = "./?.lua;./?/init.lua;" .. package.path

local b = require("test_bench.bench")

-- v1 = the bundled dist captured before the v2 refactor (cacheManager,
-- actionManager, closures-per-instance). Kept around for comparison.
local v1 = dofile("test_bench/easyswitch_v1.lua")
local v2 = dofile("dist/easyswitch.lua")

local v1P, v2P = v1.P, v2.P

b.header("EasySwitch v1 vs v2 — dispatch microbench")

------------------------------------------------------------
-- 1. Cold dispatch — single literal hit
------------------------------------------------------------
do
    local sw1 = v1.new()
    sw1:when("hello", function() return "world" end)
    local sw2 = v2.new()
    sw2:when("hello", function() return "world" end)
    local sw2m = v2.new():memoize()
    sw2m:when("hello", function() return "world" end)

    b.group("literal hit : sw:execute('hello')", {
        b.run("v1  sw:execute (cache HIT after warmup)",   function() sw1:execute("hello") end),
        b.run("v2  sw:execute (no memoize, raw dispatch)", function() sw2:execute("hello") end),
        b.run("v2  sw:execute (:memoize() HIT)",           function() sw2m:execute("hello") end),
    })
end

------------------------------------------------------------
-- 2. Cold dispatch — value never seen before (forces v1 cache miss every time)
--    Simulates request streams where the cache value never repeats.
------------------------------------------------------------
do
    local sw1 = v1.new()
    sw1:when(v1P.string, function(v) return #v end)
    local sw2 = v2.new()
    sw2:when(v2P.string, function(v) return #v end)

    -- Use a different string each call : v1's cache becomes pure overhead.
    local i = 0
    b.group("pattern dispatch : unique string each call", {
        b.run("v1  sw:execute (unique values)", function()
            i = i + 1
            sw1:execute("v" .. i)
        end),
        b.run("v2  sw:execute (unique values)", function()
            i = i + 1
            sw2:execute("v" .. i)
        end),
    })
end

------------------------------------------------------------
-- 3. Map literal dispatch — 5 routes, hot value
------------------------------------------------------------
do
    local function ctor(es)
        local sw = es.new()
        sw:when("GET",     function() return "list"   end)
        sw:when("POST",    function() return "create" end)
        sw:when("PUT",     function() return "update" end)
        sw:when("DELETE",  function() return "remove" end)
        sw:when("PATCH",   function() return "patch"  end)
        sw:default(function() return "?" end)
        return sw
    end
    local sw1 = ctor(v1)
    local sw2 = ctor(v2)
    b.group("5 literal routes : POST hit", {
        b.run("v1  sw:execute('POST')", function() sw1:execute("POST") end),
        b.run("v2  sw:execute('POST')", function() sw2:execute("POST") end),
    })
    b.group("5 literal routes : PATCH hit (last)", {
        b.run("v1  sw:execute('PATCH')", function() sw1:execute("PATCH") end),
        b.run("v2  sw:execute('PATCH')", function() sw2:execute("PATCH") end),
    })
    b.group("5 literal routes : OPTIONS fallback", {
        b.run("v1  sw:execute('OPTIONS')", function() sw1:execute("OPTIONS") end),
        b.run("v2  sw:execute('OPTIONS')", function() sw2:execute("OPTIONS") end),
    })
end

------------------------------------------------------------
-- 4. Union pattern — v1 P.any_of (linear) vs v2 P.union (hash O(1))
------------------------------------------------------------
do
    local sw1 = v1.new()
    sw1:when(v1P.any_of("a", "b", "c", "d", "e"), function() return "letter" end)
    local sw2 = v2.new()
    sw2:when(v2P.union("a", "b", "c", "d", "e"), function() return "letter" end)
    b.group("union of 5 strings : last-element hit ('e')", {
        b.run("v1  P.any_of (linear walk)", function() sw1:execute("e") end),
        b.run("v2  P.union  (hash O(1))",   function() sw2:execute("e") end),
    })
    b.group("union of 5 strings : no match ('z')", {
        b.run("v1  P.any_of", function() sw1:execute("z") end),
        b.run("v2  P.union",  function() sw2:execute("z") end),
    })
end

------------------------------------------------------------
-- 5. Shape pattern — partial dict match
------------------------------------------------------------
do
    local sw1 = v1.new()
    sw1:when({ kind = "click", x = v1P.number }, function() return "click" end)
    local sw2 = v2.new()
    sw2:when({ kind = "click", x = v2P.number }, function() return "click" end)
    local v = { kind = "click", x = 42, extra = "ok" }
    b.group("partial shape (2 keys) : match", {
        b.run("v1  shape", function() sw1:execute(v) end),
        b.run("v2  shape", function() sw2:execute(v) end),
    })
end

------------------------------------------------------------
-- 6. Memory : 1000 instances — closures-per-instance (v1) vs shared metatable (v2)
--    Bench Switch.new() construction cost.
------------------------------------------------------------
do
    b.group("Switch.new() construction (1 instance)", {
        b.run("v1  EasySwitch.new() (8 closures)",       function() v1.new() end),
        b.run("v2  EasySwitch.new() (shared metatable)", function() v2.new() end),
    })
end

------------------------------------------------------------
-- 7. Realistic mixed dispatcher
--    3 literals + 2 patterns + default. Hits a literal in the middle.
------------------------------------------------------------
do
    local function ctor(es, P)
        local sw = es.new()
        sw:when("ping",  function() return "pong" end)
        sw:when("hello", function() return "world" end)
        sw:when("bye",   function() return "see ya" end)
        sw:when(P.number,  function(n)  return n * 2 end)
        sw:when(P.boolean, function(bv) return not bv end)
        sw:default(function() return "?" end)
        return sw
    end
    local sw1 = ctor(v1, v1P)
    local sw2 = ctor(v2, v2P)
    b.group("mixed 3 literals + 2 patterns : literal hit", {
        b.run("v1  hit 'hello'", function() sw1:execute("hello") end),
        b.run("v2  hit 'hello'", function() sw2:execute("hello") end),
    })
    b.group("mixed 3 literals + 2 patterns : pattern hit (number)", {
        b.run("v1  hit number", function() sw1:execute(42) end),
        b.run("v2  hit number", function() sw2:execute(42) end),
    })
end
