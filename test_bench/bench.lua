-- Mitata-like microbench framework. Adaptive iter count, statistical sampling,
-- markdown report generation with template substitution.

-- If version = luajit or lua < 5.3, we need to polyfill `//` (floor division)
if _VERSION == 'Lua 5.1' or _VERSION == 'Lua 5.2' or _VERSION == 'luajit' then
    return error([[Lua 5.3+ is required for this benchmark suite, due to the use of the `
    //` floor division operator in the patterns being tested. Please run with Lua >= 5.3]], 0)
end

local M = {}

local TARGET_BATCH = 0.05
local DEFAULT_WARMUP = 200
local DEFAULT_SAMPLES = 30
local MAX_ITERS = 1e9

local clock = os.clock
local sort = table.sort
local floor = math.floor

local _groups = {}

local function calibrate(fn)
    local iters = 100
    while iters < MAX_ITERS do
        local t0 = clock()
        for _ = 1, iters do fn() end
        local elapsed = clock() - t0
        if elapsed >= TARGET_BATCH then return iters, elapsed end
        iters = iters * 10
    end
    return iters, 0
end

local function median(sorted)
    local n = #sorted
    if n % 2 == 0 then
        return (sorted[n // 2] + sorted[n // 2 + 1]) / 2
    end
    return sorted[(n + 1) // 2]
end

---@param name string
---@param fn fun()
---@param opts? { warmup?: integer, samples?: integer, key?: string }
---@return table
function M.run(name, fn, opts)
    opts = opts or {}
    local warmup = opts.warmup or DEFAULT_WARMUP
    local samples = opts.samples or DEFAULT_SAMPLES

    for _ = 1, warmup do fn() end
    local iters = calibrate(fn)

    local times = {}
    for s = 1, samples do
        collectgarbage("collect")
        local t0 = clock()
        for _ = 1, iters do fn() end
        local t1 = clock()
        times[s] = (t1 - t0) / iters
    end
    sort(times)

    local sum = 0
    for i = 1, samples do sum = sum + times[i] end

    return {
        name    = name,
        key     = opts.key,
        iters   = iters,
        samples = samples,
        avg     = sum / samples,
        min     = times[1],
        max     = times[samples],
        p50     = median(times),
        p99     = times[math.max(1, floor(samples * 0.99))],
    }
end

local function fmtTime(s)
    if s < 1e-6 then return string.format("%6.1f ns", s * 1e9)
    elseif s < 1e-3 then return string.format("%6.2f us", s * 1e6)
    elseif s < 1     then return string.format("%6.2f ms", s * 1e3)
    else                  return string.format("%6.2f  s", s) end
end

local function fmtTimeMd(s)
    if s < 1e-6 then return string.format("%.0f ns", s * 1e9)
    elseif s < 1e-3 then return string.format("%.2f µs", s * 1e6)
    elseif s < 1     then return string.format("%.2f ms", s * 1e3)
    else                  return string.format("%.2f s",  s) end
end

local function fmtRate(opsPerSec)
    if opsPerSec >= 1e9 then return string.format("%6.2f G/s", opsPerSec / 1e9)
    elseif opsPerSec >= 1e6 then return string.format("%6.2f M/s", opsPerSec / 1e6)
    elseif opsPerSec >= 1e3 then return string.format("%6.2f K/s", opsPerSec / 1e3)
    else return string.format("%6.0f /s", opsPerSec) end
end

local function fmtRateMd(opsPerSec)
    if opsPerSec >= 1e9 then return string.format("%.2f G/s", opsPerSec / 1e9)
    elseif opsPerSec >= 1e6 then return string.format("%.2f M/s", opsPerSec / 1e6)
    elseif opsPerSec >= 1e3 then return string.format("%.2f K/s", opsPerSec / 1e3)
    else return string.format("%.0f /s", opsPerSec) end
end

local function fmtRel(rel)
    if rel >= 1 then return string.format("%5.2fx faster", rel)
    else return string.format("%5.2fx slower", 1 / rel) end
end

local function fmtRelFr(rel)
    if rel >= 1 then return string.format("%.2f× plus rapide", rel)
    else return string.format("%.2f× plus lent", 1 / rel) end
end

local NAME_W = 44
local function pad(s, w)
    if #s >= w then return s end
    return s .. string.rep(" ", w - #s)
end

function M.group(name, benches)
    print()
    print("── " .. name .. " ──")
    local baseline = benches[1].avg
    local header = string.format("%s  %9s   %9s   %18s   %19s   %s",
        pad("", NAME_W), "avg", "rate", "min .. max", "p50 / p99", "vs baseline")
    print(header)
    print(string.rep("-", #header))
    for i = 1, #benches do
        local b = benches[i]
        local rel = baseline / b.avg
        print(string.format("%s  %s   %s   %s .. %s   %s / %s   %s",
            pad(b.name, NAME_W),
            fmtTime(b.avg),
            fmtRate(1 / b.avg),
            fmtTime(b.min), fmtTime(b.max),
            fmtTime(b.p50), fmtTime(b.p99),
            i == 1 and "(baseline)" or fmtRel(rel)
        ))
    end
    _groups[#_groups + 1] = { name = name, benches = benches }
end

function M.header(title)
    print(string.rep("=", 100))
    print(title)
    print("Lua: " .. _VERSION .. (jit and ("  /  " .. jit.version) or "  (no JIT)"))
    print("samples=" .. DEFAULT_SAMPLES .. ", warmup=" .. DEFAULT_WARMUP
        .. ", calibration target=" .. (TARGET_BATCH * 1000) .. "ms/batch")
    print(string.rep("=", 100))
end

------------------------------------------------------------
-- Stats access + serialization
------------------------------------------------------------

---Returns the stats accumulated since the last reset(). Snapshot — caller
---can mutate it without affecting subsequent reports.
---@return { groups: table[], byKey: table<string, table> }
function M.getStats()
    local byKey = {}
    local groups = {}
    for _, g in ipairs(_groups) do
        local benches = {}
        for i, b in ipairs(g.benches) do
            benches[i] = {
                name    = b.name,
                key     = b.key,
                iters   = b.iters,
                samples = b.samples,
                avg     = b.avg,
                min     = b.min,
                max     = b.max,
                p50     = b.p50,
                p99     = b.p99,
            }
            if b.key then byKey[b.key] = benches[i] end
        end
        groups[#groups + 1] = { name = g.name, benches = benches }
    end
    return {
        groups   = groups,
        byKey    = byKey,
        meta     = {
            generated = os.date("%Y-%m-%d %H:%M"),
            lua       = _VERSION .. (jit and (" / " .. jit.version) or " (sans JIT)"),
            samples   = DEFAULT_SAMPLES,
            warmup    = DEFAULT_WARMUP,
            targetMs  = TARGET_BATCH * 1000,
        },
    }
end

---Serialize stats as a Lua-loadable file (`return { ... }`). Loaded back
---with `dofile(path)`. Used so the renderer can run without re-executing
---the whole bench suite.
---@param stats table
---@param path string
function M.saveStats(stats, path)
    local f = assert(io.open(path, "wb"), "Cannot write " .. path)
    local function write(x, indent)
        local t = type(x)
        if t == "string" then
            f:write(string.format("%q", x))
        elseif t == "number" or t == "boolean" or t == "nil" then
            f:write(tostring(x))
        elseif t == "table" then
            f:write("{\n")
            -- array part
            local n = #x
            for i = 1, n do
                f:write(indent .. "  ")
                write(x[i], indent .. "  ")
                f:write(",\n")
            end
            -- hash part (skip array indices already emitted)
            for k, v in pairs(x) do
                if not (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)) then
                    f:write(indent .. "  ")
                    if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                        f:write(k .. " = ")
                    else
                        f:write("[")
                        write(k, indent .. "  ")
                        f:write("] = ")
                    end
                    write(v, indent .. "  ")
                    f:write(",\n")
                end
            end
            f:write(indent .. "}")
        else
            error("cannot serialize " .. t)
        end
    end
    f:write("return ")
    write(stats, "")
    f:write("\n")
    f:close()
end

------------------------------------------------------------
-- Template substitution + markdown render
------------------------------------------------------------

local function classifyGroup(g)
    local bs = g.benches
    if #bs ~= 2 then return nil end
    local a, b = bs[1], bs[2]
    local ratio = a.avg / b.avg
    if ratio > 1.05 then
        return b.name, a.name, ratio
    elseif ratio < 0.95 then
        return a.name, b.name, 1 / ratio
    else
        return nil, nil, ratio
    end
end

local function isLikeForLikeGroup(g)
    if #g.benches ~= 2 then return false end
    local n1, n2 = g.benches[1].name:lower(), g.benches[2].name:lower()
    return (n1:find("matchigo", 1, true) and n2:find("easyswit", 1, true))
        or (n2:find("matchigo", 1, true) and n1:find("easyswit", 1, true))
end

-- Resolve `{{benchKey.field}}` placeholders. Supported fields :
--   .name        bench display name
--   .avg_ns      avg in ns, integer
--   .avg_us      avg in µs, 2 decimals
--   .min_ns      min in ns
--   .max_ns      max in ns
--   .ratio_vs(otherBenchKey)  ratio benchA.avg / benchB.avg, formatted "1.39×"
local function resolve(stats, key, field)
    local b = stats.byKey[key]
    if b == nil then return nil, ("unknown bench key '%s'"):format(key) end
    if field == "name"      then return b.name end
    if field == "avg_ns"    then return string.format("%.0f",  b.avg * 1e9) end
    if field == "avg_us"    then return string.format("%.2f",  b.avg * 1e6) end
    if field == "min_ns"    then return string.format("%.0f",  b.min * 1e9) end
    if field == "max_ns"    then return string.format("%.0f",  b.max * 1e9) end
    if field == "p50_ns"    then return string.format("%.0f",  b.p50 * 1e9) end
    if field == "p99_ns"    then return string.format("%.0f",  b.p99 * 1e9) end
    -- ratio_vs(other)
    local other = field:match("^ratio_vs%((.+)%)$")
    if other then
        local b2 = stats.byKey[other]
        if b2 == nil then return nil, ("unknown bench key '%s' in ratio_vs"):format(other) end
        local r = b2.avg / b.avg
        if r >= 1 then return string.format("%.2f×", r)
        else          return string.format("%.2f×", 1 / r) end
    end
    return nil, ("unknown field '%s' on bench '%s'"):format(field, key)
end

-- Placeholder syntax : {{benchKey:field}}. `:` separates the key from the
-- field formatter (key itself may contain `.`, e.g. "run_vs_es.matchigo_run").
local function substitute(text, stats)
    if text == nil then return nil end
    return (text:gsub("{{%s*([^:}]+)%s*:%s*([^{}]+)%s*}}", function(key, field)
        key = key:match("^%s*(.-)%s*$")
        field = field:match("^%s*(.-)%s*$")
        local v, e = resolve(stats, key, field)
        if v == nil then
            error(("template error at {{%s:%s}} : %s"):format(key, field, e), 0)
        end
        return v
    end))
end

---@param stats table
---@param opts { title?: string, tldr?: string, analyses?: table<string,string> }
---@return string  full markdown report
function M.renderReport(stats, opts)
    opts = opts or {}
    local lines = {}
    local function emit(s) lines[#lines + 1] = s or "" end

    emit("# " .. (opts.title or "matchigo-lua bench"))
    emit()
    emit("**Généré** : " .. stats.meta.generated)
    emit("**Lua** : " .. stats.meta.lua)
    emit(("**Configuration du bench** : %d échantillons, %d warmup, cible de calibration %.1f ms/batch")
        :format(stats.meta.samples, stats.meta.warmup, stats.meta.targetMs))
    emit()

    local mWins, esWins, ties = 0, 0, 0
    for _, g in ipairs(stats.groups) do
        if isLikeForLikeGroup(g) then
            local winner = classifyGroup(g)
            if winner == nil then
                ties = ties + 1
            elseif winner:lower():find("matchigo", 1, true) then
                mWins = mWins + 1
            else
                esWins = esWins + 1
            end
        end
    end

    emit("## Résumé")
    emit()
    emit(string.format("Sur **%d** comparaisons équivalentes (matchigo vs EasySwitch) :",
        mWins + esWins + ties))
    emit("")
    emit(string.format("- matchigo gagne : **%d**", mWins))
    emit(string.format("- EasySwitch gagne : **%d**", esWins))
    emit(string.format("- égalités (à 5%% près) : **%d**", ties))
    emit()
    if opts.tldr then
        emit(substitute(opts.tldr, stats))
        emit()
    end

    emit("## Résultats détaillés")
    emit()

    for _, g in ipairs(stats.groups) do
        emit("### " .. g.name)
        emit()
        emit("| benchmark | moyenne | débit | min .. max | p50 / p99 | vs base |")
        emit("|---|---:|---:|---:|---:|---:|")
        local baseline = g.benches[1].avg
        for i, r in ipairs(g.benches) do
            local rel = baseline / r.avg
            local relStr = i == 1 and "_(base)_" or fmtRelFr(rel)
            -- Escape `|` inside the bench name : even when wrapped in backticks,
            -- `|` is treated as a column separator by most markdown renderers.
            local safeName = r.name:gsub("|", "\\|")
            emit(string.format("| `%s` | %s | %s | %s .. %s | %s / %s | %s |",
                safeName, fmtTimeMd(r.avg), fmtRateMd(1 / r.avg),
                fmtTimeMd(r.min), fmtTimeMd(r.max),
                fmtTimeMd(r.p50), fmtTimeMd(r.p99), relStr))
        end
        emit()

        local winner, loser, ratio = classifyGroup(g)
        if winner then
            emit(string.format("**Verdict** : `%s` gagne de **%.2f×** sur `%s`.",
                winner, ratio, loser))
        elseif ratio then
            emit("**Verdict** : égalité (à 5% près).")
        end
        emit()

        if opts.analyses and opts.analyses[g.name] then
            emit("**Pourquoi** : " .. substitute(opts.analyses[g.name], stats))
            emit()
        end
    end

    emit("---")
    emit()
    emit("_Rapport généré automatiquement par `test_bench/bench.lua` "
       .. "(prose résolue contre les stats live, plus de chiffres en dur)._")

    return table.concat(lines, "\n")
end

---Convenience : runReport against the in-memory groups, write to `path`.
---Also writes `<path>.stats.lua` sidecar so render.lua can regenerate
---without re-running the bench suite.
---@param path string  output markdown path
---@param opts { title?: string, tldr?: string, analyses?: table<string,string> }
function M.writeReport(path, opts)
    local stats = M.getStats()
    -- Persist stats FIRST so a render-time template error doesn't lose
    -- the actual benchmark measurements (which take ~minutes to recompute).
    M.saveStats(stats, path .. ".stats.lua")
    print()
    print("Wrote " .. path .. ".stats.lua")

    local md = M.renderReport(stats, opts)
    local f = assert(io.open(path, "wb"), "Cannot write " .. path)
    f:write(md)
    f:close()
    print("Wrote " .. path)
end

function M.reset()
    _groups = {}
end

return M
