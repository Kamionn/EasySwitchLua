-- Run from project root: lua tests/test_all.lua
package.path = "./?.lua;./src/?.lua;" .. package.path

local EasySwitch = require("easyswitch")
local P = EasySwitch.P

-- ── Runner ────────────────────────────────────────────────────────────────────

local pass, fail, total = 0, 0, 0

local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        pass = pass + 1
        print(string.format("  [PASS] %s", name))
    else
        fail = fail + 1
        print(string.format("  [FAIL] %s\n         %s", name, tostring(err)))
    end
end

local function eq(a, b, msg)
    if a ~= b then
        error((msg or "assert_eq") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
    end
end

local function is_true(v, msg)
    if not v then error((msg or "expected true, got false"), 2) end
end

local function is_nil(v, msg)
    if v ~= nil then error((msg or "expected nil") .. ", got " .. tostring(v), 2) end
end

local function section(name)
    print("\n── " .. name .. " " .. string.rep("─", 50 - #name))
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function new_sw(opts)
    return EasySwitch.new(opts)
end

local function cleanup()
    EasySwitch.clear()
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 1. Literal dispatch
-- ══════════════════════════════════════════════════════════════════════════════

section("Literal dispatch")

test("single string literal", function()
    local sw = new_sw()
    sw:when("hello", function() return "world" end)
    eq(sw:execute("hello"), "world")
end)

test("single number literal", function()
    local sw = new_sw()
    sw:when(42, function() return "forty-two" end)
    eq(sw:execute(42), "forty-two")
end)

test("array of literals share one action", function()
    local sw = new_sw()
    sw:when({"a", "b", "c"}, function(v) return "letter:" .. v end)
    eq(sw:execute("a"), "letter:a")
    eq(sw:execute("b"), "letter:b")
    eq(sw:execute("c"), "letter:c")
end)

test("default fires on no match", function()
    local sw = new_sw()
    sw:when("x", function() return "x" end)
    sw:default(function(v) return "default:" .. v end)
    eq(sw:execute("z"), "default:z")
end)

test("nil returned when no match and no default", function()
    local sw = new_sw()
    sw:when("x", function() return "x" end)
    is_nil(sw:execute("missing"))
end)

test("literal takes priority over pattern", function()
    local sw = new_sw()
    sw:when("hello", function() return "literal" end)
    sw:when(P.string, function() return "pattern" end)
    eq(sw:execute("hello"), "literal")
    eq(sw:execute("world"), "pattern")
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- 2. Pattern matching — type sentinels
-- ══════════════════════════════════════════════════════════════════════════════

section("Pattern: type sentinels")

test("P.string matches strings", function()
    local sw = new_sw()
    sw:when(P.string, function() return "str" end)
    eq(sw:execute("hello"), "str")
    is_nil(sw:execute(42))
end)

test("P.number matches numbers", function()
    local sw = new_sw()
    sw:when(P.number, function() return "num" end)
    eq(sw:execute(3.14), "num")
    is_nil(sw:execute("3.14"))
end)

test("P.boolean matches booleans", function()
    local sw = new_sw()
    sw:when(P.boolean, function() return "bool" end)
    eq(sw:execute(true), "bool")
    eq(sw:execute(false), "bool")
    is_nil(sw:execute(1))
end)

test("P.any matches everything", function()
    local sw = new_sw()
    sw:when(P.any, function() return "any" end)
    eq(sw:execute("x"), "any")
    eq(sw:execute(42), "any")
    eq(sw:execute(true), "any")
end)

test("P.integer matches whole numbers", function()
    local sw = new_sw()
    sw:when(P.integer, function() return "int" end)
    sw:when(P.float,   function() return "float" end)
    eq(sw:execute(1),   "int")
    eq(sw:execute(1.5), "float")
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- 3. Pattern matching — combinators
-- ══════════════════════════════════════════════════════════════════════════════

section("Pattern: combinators")

test("P.when(fn) — predicate", function()
    local sw = new_sw()
    sw:when(P.when(function(v) return type(v) == "number" and v > 0 end),
            function() return "positive" end)
    eq(sw:execute(5),  "positive")
    is_nil(sw:execute(-1))
    is_nil(sw:execute("5"))
end)

test("P.any_of — literal union", function()
    local sw = new_sw()
    sw:when(P.any_of("red", "green", "blue"), function(v) return "color:" .. v end)
    eq(sw:execute("red"),   "color:red")
    eq(sw:execute("blue"),  "color:blue")
    is_nil(sw:execute("yellow"))
end)

test("P.any_of — mixed pattern union", function()
    local sw = new_sw()
    sw:when(P.any_of(P.integer, P.string), function() return "int-or-str" end)
    eq(sw:execute(1),     "int-or-str")
    eq(sw:execute("hi"),  "int-or-str")
    is_nil(sw:execute(1.5))
end)

test("P.not_ — negation", function()
    local sw = new_sw()
    sw:when(P.not_(P.string), function() return "not-string" end)
    eq(sw:execute(42),  "not-string")
    is_nil(sw:execute("x"))
end)

test("P.array(item) — homogeneous array", function()
    local sw = new_sw()
    sw:when(P.array(P.number), function() return "nums" end)
    eq(sw:execute({1, 2, 3}), "nums")
    is_nil(sw:execute({1, "x", 3}))
    is_nil(sw:execute({}))  -- empty arrays don't match
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- 4. Partial table matching
-- ══════════════════════════════════════════════════════════════════════════════

section("Pattern: partial table matching")

test("plain dict pattern — exact key match", function()
    local sw = new_sw()
    sw:when({ kind = "circle" }, function(s) return math.pi * s.r ^ 2 end)
    sw:when({ kind = "square" }, function(s) return s.s ^ 2 end)
    local area = sw:execute({ kind = "circle", r = 2 })
    is_true(math.abs(area - 12.566) < 0.01, "circle area")
    eq(sw:execute({ kind = "square", s = 4 }), 16)
end)

test("partial match ignores extra keys", function()
    local sw = new_sw()
    sw:when({ active = true }, function() return "active" end)
    eq(sw:execute({ active = true, score = 100, name = "x" }), "active")
end)

test("nested table pattern", function()
    local sw = new_sw()
    sw:when({ pos = { x = P.number, y = P.number } }, function() return "vec2" end)
    eq(sw:execute({ pos = { x = 1, y = 2 } }), "vec2")
    is_nil(sw:execute({ pos = { x = "a", y = 2 } }))
end)

test("mixed literal value in table pattern", function()
    local sw = new_sw()
    sw:when({ status = "ok", code = 200 }, function() return "success" end)
    eq(sw:execute({ status = "ok", code = 200, body = "..." }), "success")
    is_nil(sw:execute({ status = "ok", code = 404 }))
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- 5. Middleware
-- ══════════════════════════════════════════════════════════════════════════════

section("Middleware")

test("middleware transforms value", function()
    local sw = new_sw()
    sw:use(function(v) return string.upper(v) end)
    sw:when("HELLO", function() return "matched-upper" end)
    eq(sw:execute("hello"), "matched-upper")
end)

test("multiple middlewares chain", function()
    local sw = new_sw()
    sw:use(function(v) return v .. "!" end)
    sw:use(function(v) return v .. "?" end)
    sw:when("hi!?", function() return "chained" end)
    eq(sw:execute("hi"), "chained")
end)

test("middleware error reverts to original value", function()
    local sw = new_sw()
    sw:use(function(_) error("boom") end)
    sw:when("raw", function() return "ok" end)
    eq(sw:execute("raw"), "ok")
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- 6. Before check
-- ══════════════════════════════════════════════════════════════════════════════

section("Before check")

test(":before gate blocks when false", function()
    local sw = new_sw()
    sw:before(function(v) return v ~= "blocked" end)
    sw:when("blocked", function() return "should-not-reach" end)
    sw:default(function() return "default" end)
    is_nil(sw:execute("blocked"))
end)

test(":before gate allows when true", function()
    local sw = new_sw()
    sw:before(function(v) return type(v) == "string" end)
    sw:when("ok", function() return "passed" end)
    eq(sw:execute("ok"), "passed")
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- 7. Events
-- ══════════════════════════════════════════════════════════════════════════════

section("Events")

test("beforeExecute fires", function()
    local fired = false
    local sw = new_sw()
    sw:on("beforeExecute", function() fired = true end)
    sw:when("x", function() return "y" end)
    sw:execute("x")
    is_true(fired)
end)

test("afterExecute fires with result", function()
    local got
    local sw = new_sw()
    sw:on("afterExecute", function(_, result) got = result end)
    sw:when("x", function() return "y" end)
    sw:execute("x")
    eq(got, "y")
end)

test("cacheHit fires on second call", function()
    local hits = 0
    local sw = new_sw()
    sw:on("cacheHit", function() hits = hits + 1 end)
    sw:when("x", function() return "y" end)
    sw:execute("x")
    sw:execute("x")
    eq(hits, 1)
end)

test("cacheMiss fires on first call", function()
    local misses = 0
    local sw = new_sw()
    sw:on("cacheMiss", function() misses = misses + 1 end)
    sw:when("x", function() return "y" end)
    sw:execute("x")
    eq(misses, 1)
end)

test("noMatch fires when nothing handles value", function()
    local fired = false
    local sw = new_sw()
    sw:on("noMatch", function() fired = true end)
    sw:when("x", function() return "y" end)
    sw:execute("z")
    is_true(fired)
end)

test("beforeCheckFailed fires when :before returns false", function()
    local fired = false
    local sw = new_sw()
    sw:on("beforeCheckFailed", function() fired = true end)
    sw:before(function() return false end)
    sw:when("x", function() return "y" end)
    sw:execute("x")
    is_true(fired)
end)

test("error event fires on action error", function()
    local got_err = false
    local sw = new_sw()
    sw:on("error", function() got_err = true end)
    sw:when("x", function() error("action failed") end)
    sw:execute("x")
    is_true(got_err)
end)

test("on() errors on unknown event", function()
    local sw = new_sw()
    local ok, err = pcall(function()
        sw:on("nonexistent", function() end)
    end)
    is_true(not ok, "should have errored")
    is_true(err:find("Unknown event") ~= nil, "error message")
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- 8. Cache
-- ══════════════════════════════════════════════════════════════════════════════

section("Cache")

test("result cached after first call", function()
    local calls = 0
    local sw = new_sw()
    sw:when("x", function() calls = calls + 1; return "y" end)
    sw:execute("x")
    sw:execute("x")
    eq(calls, 1, "action call count")
end)

test("clearCache forces re-execution", function()
    local calls = 0
    local sw = new_sw()
    sw:when("x", function() calls = calls + 1; return "y" end)
    sw:execute("x")
    sw:clearCache()
    sw:execute("x")
    eq(calls, 2, "action call count after clear")
end)

test("false result is cached and returned correctly", function()
    local calls = 0
    local sw = new_sw()
    sw:when("x", function() calls = calls + 1; return false end)
    local r1 = sw:execute("x")
    local r2 = sw:execute("x")
    eq(calls, 1, "action should only run once")
    eq(r1, false)
    eq(r2, false)
end)

test("pattern results are NOT cached", function()
    local calls = 0
    local sw = new_sw()
    sw:when(P.string, function() calls = calls + 1; return "s" end)
    local t = "hello"
    sw:execute(t)
    sw:execute(t)
    eq(calls, 2, "pattern results must not be cached")
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- 9. Named registry
-- ══════════════════════════════════════════════════════════════════════════════

section("Named registry")

test("EasySwitch('name') creates and stores switch", function()
    cleanup()
    local sw = EasySwitch("mySwitch")
    sw:when("x", function() return "y" end)
    eq(sw:execute("x"), "y")
    is_true(EasySwitch.get("mySwitch") == sw)
    cleanup()
end)

test("duplicate name errors", function()
    cleanup()
    EasySwitch("dup")
    local ok, err = pcall(function() EasySwitch("dup") end)
    is_true(not ok)
    is_true(err:find("already registered") ~= nil)
    cleanup()
end)

test("get() with no name returns all switches", function()
    cleanup()
    EasySwitch("a")
    EasySwitch("b")
    local all, count = EasySwitch.get()
    eq(count, 2)
    is_true(all["a"] ~= nil)
    is_true(all["b"] ~= nil)
    cleanup()
end)

test("clear(name) removes one switch", function()
    cleanup()
    EasySwitch("x1")
    EasySwitch("x2")
    EasySwitch.clear("x1")
    is_nil(EasySwitch.get("x1"))
    is_true(EasySwitch.get("x2") ~= nil)
    cleanup()
end)

test("clear() removes all switches", function()
    cleanup()
    EasySwitch("p")
    EasySwitch("q")
    EasySwitch.clear()
    local all, count = EasySwitch.get()
    eq(count, 0)
    cleanup()
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- 10. P.and_ / P.all_of
-- ══════════════════════════════════════════════════════════════════════════════

section("Pattern: P.and_ / P.all_of")

test("P.and_ requires all patterns to match", function()
    local sw = new_sw()
    sw:when(P.and_(P.number, P.when(function(v) return v > 0 end)),
            function() return "positive-number" end)
    eq(sw:execute(5),   "positive-number")
    is_nil(sw:execute(-1))
    is_nil(sw:execute("5"))
end)

test("P.all_of is an alias for P.and_", function()
    local sw = new_sw()
    sw:when(P.all_of(P.integer, P.between(1, 10)), function() return "1-10" end)
    eq(sw:execute(7),  "1-10")
    is_nil(sw:execute(11))
    is_nil(sw:execute(1.5))
end)

test("P.and_ with a literal value", function()
    local sw = new_sw()
    sw:when(P.and_("hello", P.when(function(v) return #v == 5 end)),
            function() return "five-letter-hello" end)
    eq(sw:execute("hello"), "five-letter-hello")
    is_nil(sw:execute("world"))
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- 11. P.between
-- ══════════════════════════════════════════════════════════════════════════════

section("Pattern: P.between")

test("P.between matches inclusive range", function()
    local sw = new_sw()
    sw:when(P.between(1, 10), function() return "low" end)
    sw:when(P.between(11, 20), function() return "high" end)
    eq(sw:execute(1),  "low")
    eq(sw:execute(10), "low")
    eq(sw:execute(11), "high")
    eq(sw:execute(20), "high")
    is_nil(sw:execute(0))
    is_nil(sw:execute(21))
end)

test("P.between rejects non-numbers", function()
    local sw = new_sw()
    sw:when(P.between(1, 10), function() return "ok" end)
    is_nil(sw:execute("5"))
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- 12. P.shape (strict table match)
-- ══════════════════════════════════════════════════════════════════════════════

section("Pattern: P.shape")

test("P.shape rejects extra keys", function()
    local sw = new_sw()
    sw:when(P.shape({ kind = "circle", r = P.number }), function() return "strict-circle" end)
    is_nil(sw:execute({ kind = "circle", r = 2, extra = true }))
    eq(sw:execute({ kind = "circle", r = 2 }), "strict-circle")
end)

test("P.shape rejects missing keys", function()
    local sw = new_sw()
    sw:when(P.shape({ x = P.number, y = P.number }), function() return "point" end)
    is_nil(sw:execute({ x = 1 }))
end)

test("P.shape vs partial match difference", function()
    local sw_strict = new_sw()
    sw_strict:when(P.shape({ active = true }), function() return "strict" end)
    is_nil(sw_strict:execute({ active = true, extra = 1 }))
    eq(sw_strict:execute({ active = true }), "strict")

    local sw_partial = new_sw()
    sw_partial:when({ active = true }, function() return "partial" end)
    eq(sw_partial:execute({ active = true, extra = 1 }), "partial")
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- 13. P.string_match
-- ══════════════════════════════════════════════════════════════════════════════

section("Pattern: P.string_match")

test("P.string_match matches Lua pattern", function()
    local sw = new_sw()
    sw:when(P.string_match("^hello"), function() return "starts-hello" end)
    eq(sw:execute("hello world"), "starts-hello")
    is_nil(sw:execute("say hello"))
end)

test("P.string_match rejects non-strings", function()
    local sw = new_sw()
    sw:when(P.string_match("%d+"), function() return "digits" end)
    is_nil(sw:execute(42))
end)

test("P.string_match — route-style matching", function()
    local sw = new_sw()
    sw:when(P.string_match("^/api/"), function() return "api" end)
    sw:when(P.string_match("^/web/"), function() return "web" end)
    eq(sw:execute("/api/users"), "api")
    eq(sw:execute("/web/home"),  "web")
    is_nil(sw:execute("/other"))
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- 14. Guards inline (:when 3-arg form)
-- ══════════════════════════════════════════════════════════════════════════════

section("Guards inline")

test("3-arg :when blocks when guard returns false", function()
    local sw = new_sw()
    sw:when(P.number, function(v) return v > 0 end, function() return "positive" end)
    sw:when(P.number,                               function() return "other"    end)
    eq(sw:execute(5),  "positive")
    eq(sw:execute(-1), "other")
end)

test("guard on a literal value", function()
    local sw = new_sw()
    sw:when("hello", function(v) return #v == 5 end, function() return "five" end)
    eq(sw:execute("hello"), "five")
end)

test("guard does not affect unrelated cases", function()
    local sw = new_sw()
    sw:when("x", function() return false end, function() return "guarded-x" end)
    sw:when("y",                              function() return "y"         end)
    is_nil(sw:execute("x"))
    eq(sw:execute("y"), "y")
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- 15. Fallthrough
-- ══════════════════════════════════════════════════════════════════════════════

section("Fallthrough")

test("FALLTHROUGH continues to next matching case", function()
    local log = {}
    local sw = new_sw()
    sw:when("hello", function()
        log[#log + 1] = "literal"
        return EasySwitch.FALLTHROUGH
    end)
    sw:when(P.string, function()
        log[#log + 1] = "pattern"
        return "done"
    end)
    local result = sw:execute("hello")
    eq(result, "done")
    eq(#log, 2)
    eq(log[1], "literal")
    eq(log[2], "pattern")
end)

test("FALLTHROUGH skips non-matching patterns", function()
    local sw = new_sw()
    sw:when(P.string, function()
        return EasySwitch.FALLTHROUGH
    end)
    sw:when(P.number, function() return "num" end)
    sw:default(function() return "default" end)
    eq(sw:execute("hi"), "default")
end)

test("FALLTHROUGH reaches default", function()
    local sw = new_sw()
    sw:when("x", function() return EasySwitch.FALLTHROUGH end)
    sw:default(function() return "fell-to-default" end)
    eq(sw:execute("x"), "fell-to-default")
end)

test("noMatch does NOT fire when all cases fallthrough but something matched", function()
    local no_match_fired = false
    local sw = new_sw()
    sw:on("noMatch", function() no_match_fired = true end)
    sw:when("x", function() return EasySwitch.FALLTHROUGH end)
    sw:execute("x")
    is_true(not no_match_fired)
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- 16. Fluent chaining
-- ══════════════════════════════════════════════════════════════════════════════

section("Fluent chaining")

test("all builder methods return self", function()
    local sw = new_sw()
    local result = sw
        :when("x", function() return "x" end)
        :default(function() return "d" end)
        :use(function(v) return v end)
        :before(function() return true end)
        :on("beforeExecute", function() end)
    is_true(result == sw)
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- Report
-- ══════════════════════════════════════════════════════════════════════════════

print(string.format("\n%s\n%d/%d passed", string.rep("─", 60), pass, total))
if fail > 0 then
    print(fail .. " FAILED")
    os.exit(1)
else
    print("All tests passed!")
end
