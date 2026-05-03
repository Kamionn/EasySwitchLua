-- Pattern matching example — run from project root: lua examples/switch_pattern_example.lua
local EasySwitch = require("easyswitch")
local P = EasySwitch.P

-- ── Shape area calculator ─────────────────────────────────────────────────────

local area = EasySwitch.new()
    :when({ kind = "circle" }, function(s)
        return math.pi * s.r ^ 2
    end)
    :when({ kind = "square" }, function(s)
        return s.s ^ 2
    end)
    :when({ kind = "rect" }, function(s)
        return s.w * s.h
    end)
    :default(function(v)
        error("Unknown shape: " .. tostring(v.kind))
    end)

print("=== Shape areas ===")
print(string.format("circle r=2  : %.4f", area:execute({ kind = "circle", r = 2 })))
print(string.format("square s=4  : %.4f", area:execute({ kind = "square", s = 4 })))
print(string.format("rect 3x5    : %.4f", area:execute({ kind = "rect", w = 3, h = 5 })))

-- ── Type-based coercion ───────────────────────────────────────────────────────

local coerce = EasySwitch.new()
    :when(P.number,  function(v) return tostring(v) end)
    :when(P.boolean, function(v) return v and "yes" or "no" end)
    :when(P.string,  function(v) return v end)
    :default(function() return "(nil)" end)

print("\n=== Coerce to string ===")
print(coerce:execute(42))       -- "42"
print(coerce:execute(true))     -- "yes"
print(coerce:execute("hello"))  -- "hello"
print(coerce:execute(nil))      -- "(nil)"

-- ── Guard with P.when ─────────────────────────────────────────────────────────

local classify = EasySwitch.new()
    :when(P.when(function(n) return n < 0    end), function() return "negative" end)
    :when(P.when(function(n) return n == 0   end), function() return "zero"     end)
    :when(P.when(function(n) return n > 0    end), function() return "positive" end)
    :default(function() return "not a number" end)

print("\n=== Classify numbers ===")
print(classify:execute(-5))   -- negative
print(classify:execute(0))    -- zero
print(classify:execute(10))   -- positive
print(classify:execute("x"))  -- not a number

-- ── Union and negation ────────────────────────────────────────────────────────

local role = EasySwitch.new()
    :when(P.any_of("admin", "moderator"), function() return "privileged" end)
    :when(P.not_(P.string),               function() return "invalid role" end)
    :default(function(v) return "user: " .. v end)

print("\n=== Role check ===")
print(role:execute("admin"))      -- privileged
print(role:execute("moderator"))  -- privileged
print(role:execute("guest"))      -- user: guest
print(role:execute(42))           -- invalid role

-- ── Homogeneous array ─────────────────────────────────────────────────────────

local sum_ints = EasySwitch.new()
    :when(P.array(P.integer), function(arr)
        local s = 0
        for _, v in ipairs(arr) do s = s + v end
        return s
    end)
    :default(function() return "not an int array" end)

print("\n=== Sum int arrays ===")
print(sum_ints:execute({ 1, 2, 3, 4 }))       -- 10
print(sum_ints:execute({ 1, 2.5, 3 }))         -- not an int array
print(sum_ints:execute("hello"))               -- not an int array

-- ── Nested table pattern + middleware + events ────────────────────────────────

print("\n=== HTTP-like response handler ===")

local handle = EasySwitch.new()
    :use(function(resp)
        resp.status = resp.status or 0
        return resp
    end)
    :on("noMatch", function(v)
        print("  [event] noMatch for status:", v.status)
    end)
    :when({ status = 200 }, function(r) return "OK: " .. (r.body or "") end)
    :when({ status = 404 }, function()  return "Not Found" end)
    :when({ status = P.when(function(s) return s >= 500 end) },
          function(r) return "Server Error " .. r.status end)
    :default(function(r) return "Unhandled status: " .. r.status end)

print(handle:execute({ status = 200, body = "hello" }))  -- OK: hello
print(handle:execute({ status = 404 }))                  -- Not Found
print(handle:execute({ status = 503 }))                  -- Server Error 503
print(handle:execute({ status = 301 }))                  -- Unhandled status: 301
