-- OpenRoute :: tools/export_guides.lua  (run with luajit on the Mac, NOT in WoW)
-- Bakes locally-installed Zygor + WoW-Pro guide files into OpenRoute data files so the
-- addon is fully standalone (source addons can stay disabled).  Output files contain
-- proprietary (Zygor) / CC BY-NC-ND (WoW-Pro) text: they are gitignored, never committed.
-- Usage: luajit tools/export_guides.lua "<WoW _anniversary_ dir>"
local WOW = arg[1] or "/Volumes/x10/Video Games/Mac/World of Warcraft/_anniversary_"
local AD = WOW .. "/Interface/AddOns"
local OUT = (arg[0]:match("^(.*)/tools/") or ".") .. "/OpenRoute/Guides"

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
    if not fn then io.stderr:write("PARSE " .. path .. ": " .. tostring(err) .. "\n") return end
    local ZGV = permissive()
    ZGV.IMAGESDIR = "" ZGV.SKINSDIR = "" ZGV.DIR = ""
    ZGV.DoMutex = function() return false end
    ZGV.RegisterGuide = function(_, title, a, b)
        local header, text
        if type(a) == "string" then text = a header = type(b) == "table" and b or {}
        else header = type(a) == "table" and a or {} text = type(b) == "string" and b or nil end
        if type(title) == "string" and type(text) == "string" then
            zygor[#zygor + 1] = { title = title, raw = text, next = type(header.next) == "string" and header.next or nil }
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
local zdirs = {}
local p = io.popen(('ls -d %q/ZygorGuidesViewer* 2>/dev/null'):format(AD))
if p then for l in p:lines() do zdirs[#zdirs + 1] = l end p:close() end
-- prefer the Anniversary (TBC) flavor; fall back to any
table.sort(zdirs, function(a, b) return (a:find("Anniv") and 1 or 0) > (b:find("Anniv") and 1 or 0) end)
local seenTitle = {}
-- only the client-matching install (Anniv/TBC): guides from other-era installs reference zones this client can't resolve
for _, zd in ipairs({ zdirs[1] }) do
    for _, f in ipairs(listLua(zd)) do
        if f:find("/Guides%-") or f:find("/Guides/") then loadZygorFile(f, "Alliance") loadZygorFile(f, "Horde") end
    end
end
-- dedupe by title (Anniv dir loads first, wins)
local dz = {}
for _, g in ipairs(zygor) do if not seenTitle[g.title] then seenTitle[g.title] = true dz[#dz + 1] = g end end
zygor = dz

-- ---------------- WoW-Pro ----------------
local wowpro = {}
local function loadWoWProFile(path)
    local src = readAll(path) if not src then return end
    local fn = loadstring(src, "@" .. path) if not fn then return end
    local W = permissive()
    local guides = setmetatable({}, { __mode = "k" })
    W.RegisterGuide = function(_, gid, gtype, zone, author, faction)
        local g = { gid = gid, type = gtype, zone = zone, author = author, faction = faction }
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
-- TBC client: load the file lists from the *_TBC TOCs of every WoWPro module present
local mp = io.popen(('ls -d %q/WoWPro_* 2>/dev/null'):format(AD))
if mp then
    for mod in mp:lines() do
        local toc = readAll(mod .. "/" .. mod:match("([^/]+)$") .. "_TBC.toc") or readAll(mod .. "/" .. mod:match("([^/]+)$") .. ".toc")
        if toc then
            for line in (toc .. "\n"):gmatch("([^\r\n]*)\r?\n") do
                line = line:match("^%s*(.-)%s*$")
                if line ~= "" and not line:find("^#") and line:find("%.lua$") then
                    loadWoWProFile(mod .. "/" .. line:gsub("\\", "/"))
                end
            end
        end
    end
    mp:close()
end
local mp2 = io.popen(('ls -d %q/WoWPro_* 2>/dev/null'):format(AD))
if mp2 then
    for mod in mp2:lines() do
        for _, era in ipairs({ "Vanilla", "TBC", "BCC", "Classic" }) do
            for _, f in ipairs(listLua(mod .. "/" .. era)) do loadWoWProFile(f) end
        end
    end
    mp2:close()
end
-- dedupe by gid
local seenGid, dw = {}, {}
for _, g in ipairs(wowpro) do if g.gid and not seenGid[g.gid] then seenGid[g.gid] = true dw[#dw + 1] = g end end
wowpro = dw

-- ---------------- emit ----------------
os.execute(('mkdir -p %q'):format(OUT))
local function openOut(name)
    local f = assert(io.open(OUT .. "/" .. name, "wb"))
    f:write("-- GENERATED by tools/export_guides.lua from guide addons installed on THIS machine.\n")
    f:write("-- Contains third-party guide text (Zygor: proprietary; WoW-Pro: CC BY-NC-ND). DO NOT COMMIT OR REDISTRIBUTE.\n")
    f:write("local ADDON, NS = ...\n")
    return f
end
local f = openOut("Imported_Zygor.lua")
f:write("NS.ImportedZygor = {\n")
for _, g in ipairs(zygor) do
    f:write(("{ title = %q, next = %s, raw = %q },\n"):format(g.title, g.next and ("%q"):format(g.next) or "nil", g.raw))
end
f:write("}\n") f:close()
f = openOut("Imported_WoWPro.lua")
f:write("NS.ImportedWoWPro = {\n")
for _, g in ipairs(wowpro) do
    if g.text and g.gid then
        f:write(("{ gid = %q, name = %q, type = %q, zone = %s, faction = %s, minl = %s, maxl = %s, next = %s, author = %s, text = %q },\n"):format(
            g.gid, g.name or g.zone or g.gid, g.type or "Leveling",
            g.zone and ("%q"):format(g.zone) or "nil", g.faction and ("%q"):format(g.faction) or "nil",
            tostring(g.minl), tostring(g.maxl), g.next and ("%q"):format(g.next) or "nil", g.author and ("%q"):format(g.author) or "nil", g.text))
    end
end
f:write("}\n") f:close()
print(("exported: %d Zygor guides, %d WoW-Pro guides -> %s"):format(#zygor, #wowpro, OUT))
