-- CompletionRoute :: tools/export_guides.lua  (run with luajit on the Mac, NOT in WoW)
-- Bakes locally-installed Zygor + WoW-Pro guide files into CompletionRoute data files so the
-- addon is fully standalone (source addons can stay disabled).  Output files contain
-- proprietary (Zygor) / CC BY-NC-ND (WoW-Pro) text: they are gitignored, never committed.
-- Usage: luajit tools/export_guides.lua ["<WoW flavor dir>" ...]
--   default: every flavor installed under /Volumes/x10/Video Games/Mac/World of Warcraft
-- Every guide is tagged with the flavor whose install it came from, so retail gets Zygor's modern
-- expansions and each classic client keeps the guides that match its era.
local ROOT = "/Volumes/x10/Video Games/Mac/World of Warcraft"
local FLAVOR_OF = { _retail_ = "retail", _classic_ = "mop", _classic_era_ = "era", _anniversary_ = "tbc" }
local WP_TOC = { retail = "", mop = "_Mists", tbc = "_TBC", era = "_Vanilla" }   -- WoW-Pro TOC per era
local WP_DIR = { retail = "Retail", mop = "MoP", tbc = "TBC", era = "Vanilla" }  -- ...and guide folder

local targets = {}
if #arg > 0 then
    for _, a in ipairs(arg) do
        local base = a:match("([^/]+)/?$")
        targets[#targets + 1] = { dir = a:find("/") and a or (ROOT .. "/" .. a), flavor = FLAVOR_OF[base] or "retail" }
    end
else
    for _, base in ipairs({ "_classic_era_", "_anniversary_", "_classic_", "_retail_" }) do
        local probe = io.popen(('test -d %q && echo yes'):format(ROOT .. "/" .. base .. "/Interface/AddOns"))
        local yes = probe and probe:read("*l") == "yes"
        if probe then probe:close() end
        if yes then targets[#targets + 1] = { dir = ROOT .. "/" .. base, flavor = FLAVOR_OF[base] } end
    end
end
assert(#targets > 0, "no WoW flavor directories found under " .. ROOT)
local OUT = (arg[0]:match("^(.*)/tools/") or ".") .. "/CompletionRoute/Guides"
local CURFLAVOR   -- set per target while loading

local function listLua(dir)
    local out = {}
    local p = io.popen(('find %q -name "*.lua" 2>/dev/null | sort'):format(dir))
    if p then for l in p:lines() do out[#out + 1] = l end p:close() end
    return out
end
local function readAll(path) local f = io.open(path, "rb") if not f then return nil end local s = f:read("*a") f:close() return s end

-- a value that tolerates being indexed, called, assigned into — returns nil from calls
local function permissive()
    local t = {}
    setmetatable(t, { __index = function(_, k) local v = permissive() rawset(t, k, v) return v end, __call = function() return nil end })
    return t
end

-- ---------------- Zygor ----------------
local zygor = {}
local function loadZygorFile(path, factionPass)
    local src = readAll(path) if not src then return end
    local fn, err = loadstring(src, "@" .. path)
    if not fn and tostring(err):find("escape sequence") then
        -- WoW ships Lua 5.1, whose lexer silently keeps an unknown escape; LuaJIT makes it an error.
        -- Zygor's guide titles are Windows paths ("Leveling Guides\Shadowlands\..."), so a lone
        -- backslash is common and costs us whole leveling guides (Horde BfA/Cata/MoP/WoD) if skipped.
        -- Double any backslash that does not begin a real escape, then retry.
        -- match backslash + next char so a genuine "\\" pair is consumed whole; doubling with a
        -- plain character class turns "\\S" into "\\\\S", which is still invalid.
        local fixed = src:gsub("\\(.)", function(c)
            if c:match("[abfnrtv\\\"'\n]") or c:match("%d") then return "\\" .. c end
            return "\\\\" .. c
        end)
        fn, err = loadstring(fixed, "@" .. path)
    end
    if not fn then io.stderr:write("PARSE " .. path .. ": " .. tostring(err) .. "\n") return end
    local ZGV = permissive()
    ZGV.IMAGESDIR = "" ZGV.SKINSDIR = "" ZGV.DIR = ""
    ZGV.DoMutex = function() return false end
    ZGV.RegisterGuide = function(_, title, a, b)
        local header, text
        if type(a) == "string" then text = a header = type(b) == "table" and b or {}
        else header = type(a) == "table" and a or {} text = type(b) == "string" and b or nil end
        if type(title) == "string" and type(text) == "string" then
            zygor[#zygor + 1] = { title = title, raw = text, flavor = CURFLAVOR,
                                  next = type(header.next) == "string" and header.next or nil }
        end
        return permissive()
    end
    local env = permissive()
    env.ZGV = ZGV env.ZygorGuidesViewer = ZGV
    -- guide files gate themselves on faction at load: run once per faction (dedupe by title later)
    env.UnitFactionGroup = function() return factionPass end
    env.UnitRace = function() return factionPass == "Alliance" and "Human" or "Orc" end
    env.UnitClass = function() return "Warrior", "WARRIOR" end
    -- real basics so header closures compile/behave if touched at load
    for _, k in ipairs({ "pairs", "ipairs", "type", "tostring", "tonumber", "table", "string", "math", "select", "unpack", "print", "setmetatable", "rawset", "rawget" }) do env[k] = _G[k] end
    setfenv(fn, env)
    local ok, e = pcall(fn)
    if not ok then io.stderr:write("RUN " .. path .. ": " .. tostring(e) .. "\n") end
end
-- Every Zygor install under every flavor.  The retail install is where the modern expansions live
-- (Legion .. Midnight); the classic installs carry the era guides.  A guide is tagged with the
-- flavor it was found under and only registers on that client (Adapters/Zygor.lua ImportStatic),
-- so a Dragonflight guide never lands on an Era character that cannot resolve its zones.
for _, t in ipairs(targets) do
    CURFLAVOR = t.flavor
    local zd = io.popen(('ls -d %q/Interface/AddOns/ZygorGuidesViewer* 2>/dev/null'):format(t.dir))
    if zd then
        for dir in zd:lines() do
            local before = #zygor
            for _, f in ipairs(listLua(dir)) do
                if f:find("/Guides%-") or f:find("/Guides/") then loadZygorFile(f, "Alliance") loadZygorFile(f, "Horde") end
            end
            io.stderr:write(("zygor %-7s %-40s +%d\n"):format(t.flavor, dir:match("([^/]+)$"), #zygor - before))
        end
        zd:close()
    end
end
-- dedupe per flavor by title (a flavor with two installs, e.g. MoP's ZGV + ClassicTBC, keeps the first)
local seenTitle, dz = {}, {}
for _, g in ipairs(zygor) do
    local k = g.flavor .. "\0" .. g.title
    if not seenTitle[k] then seenTitle[k] = true dz[#dz + 1] = g end
end
zygor = dz

-- ---------------- WoW-Pro ----------------
local wowpro = {}
local function loadWoWProFile(path)
    local src = readAll(path) if not src then return end
    local fn = loadstring(src, "@" .. path) if not fn then return end
    local W = permissive()
    local guides = setmetatable({}, { __mode = "k" })
    W.RegisterGuide = function(_, gid, gtype, zone, author, faction)
        local g = { gid = gid, type = gtype, zone = zone, author = author, faction = faction, flavor = CURFLAVOR }
        guides[g] = true wowpro[#wowpro + 1] = g
        return g
    end
    W.GuideLevels = function(_, g, minl, maxl) if guides[g] then g.minl = tonumber(minl) g.maxl = tonumber(maxl) end end
    W.GuideName = function(_, g, name) if guides[g] then g.name = name end end
    W.GuideNickname = function(_, g, name) if guides[g] then g.name = g.name or name end end
    W.GuideNextGuide = function(_, g, nxt) if guides[g] then g.next = nxt end end
    W.GuideSteps = function(_, g, f) if guides[g] and type(f) == "function" then local ok, s = pcall(setfenv(f, permissive())) if ok and type(s) == "string" then g.text = s end end end
    local env = permissive()
    env.WoWPro = W
    for _, k in ipairs({ "pairs", "ipairs", "type", "tostring", "tonumber", "table", "string", "math", "select", "unpack", "print", "setmetatable" }) do env[k] = _G[k] end
    setfenv(fn, env)
    pcall(fn)
end
-- WoW-Pro ships one TOC and one guide folder per era; load the pair that matches each flavor, so
-- retail picks up the Legion/BfA/Shadowlands/Dragonflight/TWW guides the TBC-only pass never saw.
for _, t in ipairs(targets) do
    CURFLAVOR = t.flavor
    local before = #wowpro
    local mp = io.popen(('ls -d %q/Interface/AddOns/WoWPro_* 2>/dev/null'):format(t.dir))
    if mp then
        for mod in mp:lines() do
            local name = mod:match("([^/]+)$")
            local toc = readAll(("%s/%s%s.toc"):format(mod, name, WP_TOC[t.flavor])) or readAll(mod .. "/" .. name .. ".toc")
            if toc then
                for line in (toc .. "\n"):gmatch("([^\r\n]*)\r?\n") do
                    line = line:match("^%s*(.-)%s*$")
                    if line ~= "" and not line:find("^#") and line:find("%.lua$") then
                        loadWoWProFile(mod .. "/" .. line:gsub("\\", "/"))
                    end
                end
            end
            for _, f in ipairs(listLua(mod .. "/" .. (WP_DIR[t.flavor] or ""))) do loadWoWProFile(f) end
        end
        mp:close()
    end
    io.stderr:write(("wowpro %-7s +%d\n"):format(t.flavor, #wowpro - before))
end
-- dedupe per flavor by gid
local seenGid, dw = {}, {}
for _, g in ipairs(wowpro) do
    local k = (g.flavor or "?") .. "\0" .. tostring(g.gid)
    if g.gid and not seenGid[k] then seenGid[k] = true dw[#dw + 1] = g end
end
wowpro = dw

-- ---------------- emit ----------------
-- One file per flavor.  A single merged file is ~100 MB once retail's expansions are in it, and every
-- client would have to parse all of it to use its own era's slice; split, each client parses only its
-- own.  install.sh copies just the matching flavor's files into each game folder.
os.execute(('mkdir -p %q'):format(OUT))
local function openOut(name, flavor)
    local f = assert(io.open(OUT .. "/" .. name, "wb"))
    f:write("-- GENERATED by tools/export_guides.lua from guide addons installed on THIS machine.\n")
    f:write("-- Contains third-party guide text (Zygor: proprietary; WoW-Pro: CC BY-NC-ND). DO NOT COMMIT OR REDISTRIBUTE.\n")
    f:write("local ADDON, NS = ...\n")
    f:write(('if NS.flavor ~= %q then return end\n'):format(flavor))
    return f
end

local FLAVORS = { "era", "tbc", "mop", "retail" }
local counts = {}
for _, flavor in ipairs(FLAVORS) do
    local zf = openOut("Imported_Zygor_" .. flavor .. ".lua", flavor)
    zf:write("NS.ImportedZygor = {\n")
    local nz = 0
    for _, g in ipairs(zygor) do
        if g.flavor == flavor then
            nz = nz + 1
            zf:write(("{ title = %q, flavor = %q, next = %s, raw = %q },\n"):format(
                g.title, g.flavor, g.next and ("%q"):format(g.next) or "nil", g.raw))
        end
    end
    zf:write("}\n") zf:close()

    local wf = openOut("Imported_WoWPro_" .. flavor .. ".lua", flavor)
    wf:write("NS.ImportedWoWPro = {\n")
    local nw = 0
    for _, g in ipairs(wowpro) do
        if g.flavor == flavor and g.text and g.gid then
            nw = nw + 1
            wf:write(("{ gid = %q, flavor = %q, name = %q, type = %q, zone = %s, faction = %s, minl = %s, maxl = %s, next = %s, author = %s, text = %q },\n"):format(
                g.gid, g.flavor, g.name or g.zone or g.gid, g.type or "Leveling",
                g.zone and ("%q"):format(g.zone) or "nil", g.faction and ("%q"):format(g.faction) or "nil",
                tostring(g.minl), tostring(g.maxl), g.next and ("%q"):format(g.next) or "nil",
                g.author and ("%q"):format(g.author) or "nil", g.text))
        end
    end
    wf:write("}\n") wf:close()
    counts[#counts + 1] = ("%s: %d zygor / %d wowpro"):format(flavor, nz, nw)
end
-- the old single-file bake would now shadow the per-flavor ones
os.remove(OUT .. "/Imported_Zygor.lua")
os.remove(OUT .. "/Imported_WoWPro.lua")
print(("exported %d Zygor + %d WoW-Pro guides -> %s\n  %s"):format(#zygor, #wowpro, OUT, table.concat(counts, "\n  ")))
