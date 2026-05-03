-- Optional named registry — wraps Switch.new() and stores instances by name.
-- Kept separate so anonymous usage (EasySwitch.new) has zero registry overhead.
-- store is always mutated in-place so Registry.registered stays valid.

local Switch = require("src.switch")

local Registry = {}

local store = {}
Registry.registered = store

function Registry.create(name, options)
    if type(name) ~= "string" or name == "" then
        error("Registry name must be a non-empty string. Use EasySwitch.new() for anonymous switches.", 2)
    end
    if store[name] then
        error("Switch [" .. name .. "] is already registered", 2)
    end
    local instance = Switch.new(options)
    store[name] = instance
    return instance
end

function Registry.get(name)
    if name then
        return store[name]
    end
    if not next(store) then return nil, 0 end
    local result, count = {}, 0
    for k, v in pairs(store) do
        count = count + 1
        result[k] = v
    end
    return result, count
end

function Registry.clear(name)
    if name then
        store[name] = nil
    else
        for k in pairs(store) do store[k] = nil end
    end
end

return Registry
