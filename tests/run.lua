-- Run from the project root: `lua tests/run.lua`
package.path = package.path .. ";./?.lua;./?/init.lua"

local Switch = require("easyswitch")
local P = Switch.P

local passed, failed = 0, 0

local function test(name, fn)
    Switch:clear()
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("PASS  " .. name)
    else
        failed = failed + 1
        print("FAIL  " .. name .. ": " .. tostring(err))
    end
end

local function assertEq(actual, expected, msg)
    if actual ~= expected then
        error((msg or "values differ") ..
            " — expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertTrue(value, msg)
    if not value then error(msg or "expected truthy", 2) end
end

local function assertFalse(value, msg)
    if value then error(msg or "expected falsy", 2) end
end

test("basic literal dispatch", function()
    local s = Switch("t"):when("a", function() return "A" end)
                        :when("b", function() return "B" end)
    assertEq(s:execute("a"), "A")
    assertEq(s:execute("b"), "B")
end)

test("default action runs when no match", function()
    local s = Switch("t"):when("a", function() return "A" end)
                        :default(function(v) return "?" .. v end)
    assertEq(s:execute("z"), "?z")
end)

test("multiple cases via array", function()
    local s = Switch("t"):when({ "a", "b" }, function(v) return v:upper() end)
    assertEq(s:execute("a"), "A")
    assertEq(s:execute("b"), "B")
end)

test("middleware transforms value before dispatch", function()
    local s = Switch("t"):use(function(v) return v:upper() end)
                        :when("HELLO", function() return "ok" end)
    assertEq(s:execute("hello"), "ok")
end)

test("middleware error preserves prior transformation (#2)", function()
    local s = Switch("t")
        :use(function(v) return v .. "-x" end)
        :use(function() error("boom") end)
        :use(function(v) return v .. "-y" end)
        :when("hi-x-y", function() return "ok" end)
    assertEq(s:execute("hi"), "ok")
end)

test("before(nil) restores default check (#3)", function()
    local s = Switch("t")
        :before(function() return false end)
        :when("a", function() return "A" end)
    assertEq(s:execute("a"), nil)
    s:before(nil)
    assertEq(s:execute("a"), "A")
end)

test("pattern matching basics", function()
    local s = Switch("t")
        :when(P.string, function(v) return "s" end)
        :when(P.integer, function(v) return "i" end)
    assertEq(s:execute("x"), "s")
    assertEq(s:execute(3), "i")
end)

test("pattern array matches arrays only", function()
    local s = Switch("t"):when(P.array(P.number), function() return "arr" end)
                        :default(function() return "no" end)
    assertEq(s:execute({ 1, 2, 3 }), "arr")
    assertEq(s:execute({ 1, "x" }), "no")
end)

test("pattern results are not cached", function()
    local calls = 0
    local s = Switch("t"):when(P.string, function(v)
        calls = calls + 1
        return v
    end)
    s:execute("hi")
    s:execute("hi")
    assertEq(calls, 2)
end)

test("literal results are cached", function()
    local calls = 0
    local s = Switch("t"):when("hi", function()
        calls = calls + 1
        return "ok"
    end)
    s:execute("hi")
    s:execute("hi")
    assertEq(calls, 1)
end)

test("noMatch event fires when nothing matches", function()
    local fired = false
    local s = Switch("t"):on("noMatch", function() fired = true end)
                        :when("a", function() return "A" end)
    s:execute("z")
    assertTrue(fired)
end)

test("sparse table is not classified as array (#4)", function()
    assertFalse(P.isCaseList({ [1] = 1, [3] = 3 }))
    assertTrue(P.isCaseList({ 1, 2, 3 }))
end)

test("frozen pattern singletons cannot be mutated (#10)", function()
    local ok = pcall(function() P.string.name = "x" end)
    assertFalse(ok)
end)

test("cyclic table pattern does not infinite loop (#11)", function()
    local p = { kind = "x" }
    p.self = p
    local v = { kind = "x" }
    v.self = v
    local s = Switch("t"):when(p, function() return "ok" end)
                        :default(function() return "no" end)
    assertEq(s:execute(v), "ok")
end)

test("Switch:get is silent when empty (#8)", function()
    local result = Switch:get("missing")
    assertEq(result, nil)
end)

test("afterExecute always receives 3 args (#7)", function()
    local args
    local s = Switch("t")
        :on("afterExecute", function(...) args = { select("#", ...), ... } end)
        :before(function() return false end)
        :when("a", function() return "A" end)
    s:execute("a")
    assertEq(args[1], 3, "argc")
end)

test("maxCases validates non-numeric input (#9)", function()
    local ok = pcall(function() Switch("t", { maxCases = "abc" }) end)
    assertFalse(ok)
end)

test("maxCases validates negative input (#9)", function()
    local ok = pcall(function() Switch("t", { maxCases = -1 }) end)
    assertFalse(ok)
end)

test("partial table pattern matches recursively", function()
    local s = Switch("t"):when({ kind = "circle" }, function(v) return v.r end)
                        :default(function() return nil end)
    assertEq(s:execute({ kind = "circle", r = 5 }), 5)
    assertEq(s:execute({ kind = "square", s = 4 }), nil)
end)

test("any_of and not_ work as expected", function()
    local s = Switch("t")
        :when(P.any_of("yes", "y"), function() return "Y" end)
        :when(P.not_(P.string), function() return "non-string" end)
    assertEq(s:execute("y"), "Y")
    assertEq(s:execute("yes"), "Y")
    assertEq(s:execute(42), "non-string")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
