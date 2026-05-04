-- Bundles EasySwitch v2 into dist/easyswitch.lua.
-- Run from project root :  lua build.lua
--
-- Strategy : copies matchigo's `do ... end` scope discipline. Each src/
-- module becomes a `do` block with its trailing `return M` rewritten as
-- an assignment to a chunk-local. Internal `require("src.X")` calls
-- become direct local references — zero closure / hash overhead at load.
--
-- The vendored matchigo bundle is a special case : its body ends with
-- `return { ... }` at the chunk's top level (the value `require("matchigo")`
-- yields). Wrapping it in a bare `do ... end` would be a Lua syntax
-- error (`return` is only valid as the last statement of a chunk or
-- function), so we wrap it in a one-shot IIFE — one call at bundle load,
-- amortised across the lifetime of the program.
--
-- Output : dist/easyswitch.lua, comments stripped, indentation kept.

local OUT_DIR  = "dist"
local OUT_FILE = OUT_DIR .. "/easyswitch.lua"
local OUT_MIN  = OUT_DIR .. "/easyswitch.min.lua"
local ENTRY    = "src/init.lua"

local VENDOR_MATCHIGO = "vendor/matchigo.lua"

-- Topological order : deps first.
local MODULES = {
    { req = "src.dispatcher",         file = "src/dispatcher.lua",         var = "_M_dispatcher"  },
    { req = "src.eventManager",       file = "src/eventManager.lua",       var = "_M_eventManager" },
    { req = "src.middlewareManager",  file = "src/middlewareManager.lua",  var = "_M_middlewareManager" },
    { req = "src.switch",             file = "src/switch.lua",             var = "_M_switch"      },
    { req = "src.registry",           file = "src/registry.lua",           var = "_M_registry"    },
}

-- Vendor is its own pseudo-module — handled separately because its body
-- ends with `return { ... }` and can't live in a bare `do` block.
local VENDOR_VAR = "_M_matchigo"

local reqToVar = { ["vendor.matchigo"] = VENDOR_VAR }
for i = 1, #MODULES do reqToVar[MODULES[i].req] = MODULES[i].var end

local function readFile(path)
    local f = assert(io.open(path, "rb"), "Cannot open " .. path)
    local s = f:read("*a")
    f:close()
    return s
end

local function writeFile(path, content)
    local f = assert(io.open(path, "wb"), "Cannot write " .. path)
    f:write(content)
    f:close()
end

local function ensureDir(path)
    local sep = package.config:sub(1, 1)
    if sep == "\\" then
        local winPath = path:gsub("/", "\\")
        os.execute(string.format([[if not exist "%s" mkdir "%s"]], winPath, winPath))
    else
        os.execute(string.format([[mkdir -p "%s"]], path))
    end
end

-- ── Comment / whitespace stripping (string-aware) ─────────────────────────
-- State machine that respects string literals so `"-- not a comment"`
-- survives intact.
local function stripComments(src)
    local out, n = {}, 0
    local function add(s) n = n + 1; out[n] = s end
    local i, len = 1, #src

    while i <= len do
        local c = src:sub(i, i)

        if c == "'" or c == '"' then
            local quote = c
            local j = i + 1
            while j <= len do
                local cc = src:sub(j, j)
                if cc == "\\" then j = j + 2
                elseif cc == quote then j = j + 1; break
                elseif cc == "\n" then break
                else j = j + 1 end
            end
            add(src:sub(i, j - 1))
            i = j

        elseif c == "[" then
            local k = i + 1
            local level = 0
            while src:sub(k, k) == "=" do level = level + 1; k = k + 1 end
            if src:sub(k, k) == "[" then
                local close = "]" .. string.rep("=", level) .. "]"
                local endIdx = src:find(close, k + 1, true)
                if endIdx then
                    add(src:sub(i, endIdx + #close - 1))
                    i = endIdx + #close
                else
                    add(c); i = i + 1
                end
            else
                add(c); i = i + 1
            end

        elseif c == "-" and src:sub(i + 1, i + 1) == "-" then
            i = i + 2
            if src:sub(i, i) == "[" then
                local k = i + 1
                local level = 0
                while src:sub(k, k) == "=" do level = level + 1; k = k + 1 end
                if src:sub(k, k) == "[" then
                    local close = "]" .. string.rep("=", level) .. "]"
                    local endIdx = src:find(close, k + 1, true)
                    i = endIdx and (endIdx + #close) or (len + 1)
                else
                    while i <= len and src:sub(i, i) ~= "\n" do i = i + 1 end
                end
            else
                while i <= len and src:sub(i, i) ~= "\n" do i = i + 1 end
            end

        else
            add(c); i = i + 1
        end
    end

    return table.concat(out)
end

-- ── Token-aware minifier (single-line output) ────────────────────────────
-- Tokenises the source then re-emits each token with the minimum whitespace
-- needed to preserve lexical boundaries :
--   • two adjacent word-like tokens (id/keyword/number) need a space
--   • a number followed by `.` would form an ambiguous `1..2` → space
--   • two adjacent `-` would form a `--` line comment → space
-- Comments are dropped entirely. String literals containing newlines keep
-- them as-is.
local function tokenize(src)
    local tokens, n = {}, 0
    local i, len = 1, #src
    local function push(text) n = n + 1; tokens[n] = text end

    while i <= len do
        local c = src:sub(i, i)
        local b = c:byte() or 0

        if b == 32 or b == 9 or b == 10 or b == 13 then
            i = i + 1

        elseif c == "-" and src:sub(i + 1, i + 1) == "-" then
            i = i + 2
            if src:sub(i, i) == "[" then
                local k = i + 1
                local level = 0
                while src:sub(k, k) == "=" do level = level + 1; k = k + 1 end
                if src:sub(k, k) == "[" then
                    local close = "]" .. string.rep("=", level) .. "]"
                    local endIdx = src:find(close, k + 1, true)
                    i = endIdx and (endIdx + #close) or (len + 1)
                else
                    while i <= len and src:sub(i, i) ~= "\n" do i = i + 1 end
                end
            else
                while i <= len and src:sub(i, i) ~= "\n" do i = i + 1 end
            end

        elseif c == "'" or c == '"' then
            local quote = c
            local j = i + 1
            while j <= len do
                local cc = src:sub(j, j)
                if cc == "\\" then j = j + 2
                elseif cc == quote then j = j + 1; break
                elseif cc == "\n" then break
                else j = j + 1 end
            end
            push(src:sub(i, j - 1))
            i = j

        elseif c == "[" then
            local k = i + 1
            local level = 0
            while src:sub(k, k) == "=" do level = level + 1; k = k + 1 end
            if src:sub(k, k) == "[" then
                local close = "]" .. string.rep("=", level) .. "]"
                local endIdx = src:find(close, k + 1, true)
                if endIdx then
                    push(src:sub(i, endIdx + #close - 1))
                    i = endIdx + #close
                else
                    push("["); i = i + 1
                end
            else
                push("["); i = i + 1
            end

        elseif (b >= 48 and b <= 57)
            or (c == "." and src:sub(i + 1, i + 1):match("%d")) then
            local j = i
            if c == "0" and (src:sub(i + 1, i + 1) == "x" or src:sub(i + 1, i + 1) == "X") then
                j = i + 2
                while j <= len and src:sub(j, j):match("[%x.]") do j = j + 1 end
                local cc = src:sub(j, j)
                if cc == "p" or cc == "P" then
                    j = j + 1
                    if src:sub(j, j) == "+" or src:sub(j, j) == "-" then j = j + 1 end
                    while j <= len and src:sub(j, j):match("%d") do j = j + 1 end
                end
            else
                while j <= len and src:sub(j, j):match("[%d.]") do j = j + 1 end
                local cc = src:sub(j, j)
                if cc == "e" or cc == "E" then
                    j = j + 1
                    if src:sub(j, j) == "+" or src:sub(j, j) == "-" then j = j + 1 end
                    while j <= len and src:sub(j, j):match("%d") do j = j + 1 end
                end
            end
            push(src:sub(i, j - 1))
            i = j

        elseif c:match("[%a_]") then
            local j = i + 1
            while j <= len and src:sub(j, j):match("[%w_]") do j = j + 1 end
            push(src:sub(i, j - 1))
            i = j

        else
            local s3 = src:sub(i, i + 2)
            if s3 == "..." then
                push("..."); i = i + 3
            else
                local s2 = src:sub(i, i + 1)
                if s2 == ".." or s2 == "==" or s2 == "~=" or s2 == "<="
                    or s2 == ">=" or s2 == "::" or s2 == "//"
                    or s2 == "<<" or s2 == ">>" then
                    push(s2); i = i + 2
                else
                    push(c); i = i + 1
                end
            end
        end
    end

    return tokens
end

local function minify(src)
    local tokens = tokenize(src)
    local out, m = {}, 0
    for i = 1, #tokens do
        local t = tokens[i]
        if i > 1 then
            local prev = tokens[i - 1]
            local pl = prev:sub(-1)
            local cf = t:sub(1, 1)
            local needSep =
                (pl:match("[%w_]") and cf:match("[%w_]"))     -- word-word
                or (pl:match("%d") and cf == ".")              -- 1..2 ambiguity
                or (pl == "-" and cf == "-")                   -- forms `--` comment
            if needSep then m = m + 1; out[m] = " " end
        end
        m = m + 1; out[m] = t
    end
    return table.concat(out)
end

local function stripCommentsKeepLayout(src)
    src = stripComments(src)
    local out, m = {}, 0
    local prevBlank = false
    for line in (src .. "\n"):gmatch("([^\n]*)\n") do
        local trimmed = line:gsub("%s+$", "")
        if trimmed:match("%S") then
            m = m + 1; out[m] = trimmed
            prevBlank = false
        elseif not prevBlank then
            m = m + 1; out[m] = ""
            prevBlank = true
        end
    end
    return table.concat(out, "\n") .. "\n"
end

-- Replace every `require("X")` whose name is in reqToVar with the corresponding
-- local. Unknown require()s are an error — easier to catch typos at build time.
local function rewriteRequires(body)
    local result = body:gsub('require%s*%(%s*"([^"]+)"%s*%)', function(req)
        local var = reqToVar[req]
        if not var then error("Unknown require in source: " .. req) end
        return var
    end)
    return result
end

-- Tree-shakes the vendored matchigo dist : drops `do ... end` blocks for
-- modules EasySwitch never references, plus their forward declarations,
-- their tail aliases (`local matchMod = _M_match`), and their fields in
-- the final `return { ... }` table.
--
-- Targets : `walk`, `match`, `matcher`. They're only reached via the
-- public `match`, `compile`, `matcher`, `isMatching` functions of matchigo,
-- none of which EasySwitch calls — we use our own dispatcher that adds
-- FALLTHROUGH semantics matchigo's match/compile lack.
--
-- Robustness : the matchigo dist is generated by `build.lua` upstream
-- with a stable shape (one forward-decl line, then a sequence of
-- `do\n...\n    _M_x = M\nend` blocks, then tail aliases + return). We
-- match that shape literally. If matchigo ever changes its bundling
-- discipline, this function silently no-ops and EasySwitch's bundle
-- just stays the original size — no correctness risk.
local function shakeMatchigo(src)
    -- Modules whose `do ... end` block must disappear. Their public
    -- exports go too (see DROPPED_FIELDS below).
    local DROPPED_BLOCKS = {
        _M_walk    = true,
        _M_match   = true,
        _M_matcher = true,
    }

    -- 1. Walk the source line-by-line, tracking `do ... end` blocks at
    --    the chunk level (matchigo's build emits each module as one such
    --    block, opener `do` and closer `end` flush-left, body indented).
    --    For each block, peek at its assignment line `    _M_x = NAME`
    --    just before `end` ; if `_M_x` is targeted, drop the whole block
    --    plus any trailing blank lines.
    local lines = {}
    for line in (src .. "\n"):gmatch("([^\n]*)\n") do
        lines[#lines + 1] = line
    end
    if lines[#lines] == "" then lines[#lines] = nil end

    local out, i = {}, 1
    while i <= #lines do
        if lines[i] == "do" then
            -- Find the matching flush-left `end`. Top-level only :
            -- nested blocks inside matchigo modules are always indented,
            -- so we don't need depth tracking here.
            local startI, j = i, i + 1
            while j <= #lines and lines[j] ~= "end" do j = j + 1 end
            -- Inspect the line just before `end` for the assignee.
            local assignee
            for k = j - 1, startI + 1, -1 do
                local m = lines[k]:match("^%s+(_M_[%w_]+)%s*=")
                if m then assignee = m; break end
            end
            if assignee and DROPPED_BLOCKS[assignee] then
                -- Drop this block + trailing blank line(s).
                i = j + 1
                while i <= #lines and lines[i] == "" do i = i + 1 end
            else
                for k = startI, j do out[#out + 1] = lines[k] end
                i = j + 1
            end
        else
            out[#out + 1] = lines[i]
            i = i + 1
        end
    end
    src = table.concat(out, "\n") .. "\n"

    -- 2. Rebuild the forward-decl line without the dropped names.
    --    Patterns use literal spaces (not %s) to stay within ONE line —
    --    `%s` would let `[%w_,%s]+` walk across the blank line and eat
    --    the `do` of the next block as if it were an identifier. Only
    --    the first match is performed (the forward decl line is unique).
    src = src:gsub("(local +)([_%w, ]+)\n", function(prefix, names)
        if not names:find("_M_", 1, true) then return nil end
        local kept = {}
        for ident in names:gmatch("[%w_]+") do
            if not DROPPED_BLOCKS[ident] then
                kept[#kept + 1] = ident
            end
        end
        if #kept == 0 then return "" end
        return prefix .. table.concat(kept, ", ") .. "\n"
    end, 1)

    -- 3. Drop tail aliases : `local <name> = _M_<dropped>\n`.
    for varname in pairs(DROPPED_BLOCKS) do
        src = src:gsub("local +[%w_]+ *= *" .. varname .. "\n", "")
    end

    -- 4. Drop the corresponding fields from the final return table.
    local DROPPED_FIELDS = { "match", "compile", "matcher", "isMatching" }
    for _, field in ipairs(DROPPED_FIELDS) do
        src = src:gsub("    " .. field .. " *= *[%w_]+%.[%w_]+,?\n", "")
    end

    -- 5. Collapse runs of three-or-more blank lines created by the drops.
    src = src:gsub("\n\n\n+", "\n\n")

    return src
end

local function splitTrailingReturn(body)
    local trimmed = body:gsub("%s+$", "")
    local before, name = trimmed:match("^(.-)\n?return%s+([%w_]+)$")
    if not before then
        error("Could not find trailing `return <ident>` in module body")
    end
    before = before:gsub("\n+$", "")
    return before, name
end

local function indentBlock(s, prefix)
    local out, n = {}, 0
    for line in (s .. "\n"):gmatch("([^\n]*)\n") do
        n = n + 1
        if line == "" then out[n] = "" else out[n] = prefix .. line end
    end
    if out[n] == "" then out[n] = nil end
    return table.concat(out, "\n")
end

local HEADER = string.format([[
-- EasySwitchLua v2 — bundled distribution, generated by build.lua.
-- License: MIT
-- Generated: %s
-- Source: https://github.com/SUP2Ak/EasySwitchLua
--
-- This file ships the matchigo runtime vendored in. Do not edit — edit
-- the sources under src/ (and refresh vendor/matchigo.lua from upstream
-- when needed) and rebuild via `lua build.lua`.
]], os.date("%Y-%m-%d"))

local parts, pn = {}, 0
local function emit(line) pn = pn + 1; parts[pn] = line end

emit(HEADER)

-- Forward-declare every module local in one statement.
local fwdNames = { VENDOR_VAR }
for i = 1, #MODULES do fwdNames[#fwdNames + 1] = MODULES[i].var end
emit("local " .. table.concat(fwdNames, ", "))
emit("")

-- Vendor matchigo : IIFE wrap because it ends in `return { ... }`.
-- Tree-shake unused matchigo modules (walk / match / matcher) before
-- inlining — saves a few KB without touching the vendored file on disk.
local vendorBodyRaw = readFile(VENDOR_MATCHIGO)
local vendorBody    = shakeMatchigo(vendorBodyRaw)
print(string.format("matchigo tree-shake : %d → %d bytes (-%d, %.1f%% saved)",
    #vendorBodyRaw, #vendorBody,
    #vendorBodyRaw - #vendorBody,
    100 * (#vendorBodyRaw - #vendorBody) / #vendorBodyRaw))
emit(VENDOR_VAR .. " = (function()")
emit(indentBlock(vendorBody, "    "))
emit("end)()")
emit("")

-- Each EasySwitch module : `do <body> _M_x = M end`. Comments are
-- stripped before rewriting requires so docstring examples like
-- `-- local EasySwitch = require("easyswitch")` don't fool the rewriter.
for i = 1, #MODULES do
    local mod = MODULES[i]
    local body = rewriteRequires(stripComments(readFile(mod.file)))
    local before, retName = splitTrailingReturn(body)
    emit("do")
    emit(indentBlock(before, "    "))
    emit("    " .. mod.var .. " = " .. retName)
    emit("end")
    emit("")
end

-- Entry stays at chunk top-level so its `return ...` is the bundle's value.
local entry = rewriteRequires(stripComments(readFile(ENTRY))):gsub("%s+$", "")
emit(entry)

ensureDir(OUT_DIR)

local raw = table.concat(parts, "\n") .. "\n"
local readable = stripCommentsKeepLayout(raw)
local minified = minify(raw)
writeFile(OUT_FILE, readable)
writeFile(OUT_MIN, minified)

print(string.format("Wrote %s (%d bytes)", OUT_FILE, #readable))
print(string.format("Wrote %s (%d bytes, %.0f%% of readable)",
    OUT_MIN, #minified, 100 * #minified / #readable))
