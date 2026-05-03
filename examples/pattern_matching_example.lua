-- Pattern matching example for EasySwitchLua.
local Switch = require("easyswitch")
local P = Switch.P

local shapes = Switch("pattern-shapes")
    :when({ kind = "circle" }, function(shape)
        return math.pi * shape.r ^ 2
    end)
    :when({ kind = "square" }, function(shape)
        return shape.s ^ 2
    end)
    :when(P.string, function(value)
        return tonumber(value)
    end)
    :when(P.array(P.number), function(values)
        local total = 0
        for i = 1, #values do
            total = total + values[i]
        end
        return total
    end)
    :default(function()
        return nil
    end)

print(shapes:execute({ kind = "circle", r = 2 }))
print(shapes:execute({ kind = "square", s = 4 }))
print(shapes:execute("42"))
print(shapes:execute({ 1, 2, 3 }))
