-- Named registry for EasySwitch v2. Backed by matchigo's Map so insertion
-- order is preserved (useful when dumping `EasySwitch.get()` for inspection)
-- and `:size` is O(1) — v1 walked `pairs(store)` to count.

local Switch   = require("src.switch")
local matchigo = require("vendor.matchigo")

local Map = matchigo.Map

local M = {}

local store = Map.new()
M.store = store

function M.create(name, options)
    if type(name) ~= "string" or name == "" then
        error("Registry name must be a non-empty string. Use EasySwitch.new() for anonymous switches.", 2)
    end
    if store:has(name) then
        error("Switch [" .. name .. "] is already registered", 2)
    end
    local instance = Switch.new(options)
    store:set(name, instance)
    return instance
end

function M.get(name)
    if name then
        return store:get(name)
    end
    if store.size == 0 then return nil, 0 end
    local result = {}
    for k, v in store:pairs() do
        result[k] = v
    end
    return result, store.size
end

function M.clear(name)
    if name then
        store:delete(name)
    else
        store:clear()
    end
end

return M
