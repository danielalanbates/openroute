-- CompletionRoute :: Adapters/Zygor.lua
-- If a Zygor Guides Viewer addon is installed and enabled, translate its registered guides (in memory,
-- from the user's own installation) into CompletionRoute steps so the routing engine and arrow can drive them.
-- Nothing is copied to disk or redistributed.  Zygor's guide text is proprietary; this is interop only.
-- Translation is best-effort: accept/turnin/kill/collect/goto/talk/use/fly/hearth/home/level, |goto coords,
-- ##questid, |q qid, |tip notes, |only if <class/race> conditions.  Complex script conditions are ignored.
local ADDON, NS = ...
local G, U = NS.Guide, NS.Util
NS.Adapters = NS.Adapters or {}
local A = {}
NS.Adapters.Zygor = A

local CLASSES = { warrior=1, paladin=1, hunter=1, rogue=1, priest=1, shaman=1, mage=1, warlock=1, druid=1, deathknight=1, monk=1, demonhunter=1, evoker=1 }
local RACES = { human=1, dwarf=1, gnome=1, nightelf=1, draenei=1, worgen=1, orc=1, troll=1, tauren=1, undead=1, scourge=1, bloodelf=1, goblin=1, pandaren=1 }

local function esc(s) return (s or ""):gsub("|", "/") end

-- parse "|goto Zone/0 12.3,45.6" or "|goto Zone 12.3,45.6"
local function parseGoto(line)
    local zone, x, y = line:match("|goto%s+([^|]-)/?%d*%s+([%d%.]+),([%d%.]+)")
    if not zone then zone, x, y = line:match("|goto%s+([^|]-)%s+([%d%.]+),([%d%.]+)") end
    if zone then zone = U.trim(zone:gsub("/%d+$", "")) return zone, tonumber(x), tonumber(y) end
    local z2 = line:match("|goto%s+([^|,%d]+)%s*$")
    if z2 then return U.trim(z2) end
    return nil
end

-- Convert one Zygor step block (array of lines) into native lines
local function convertStep(lines, ctx)
    local out = {}
    local tips, gotoZone, gx, gy, only, onlyClass, onlyRace, qidGlobal = {}, nil, nil, nil, nil, nil, nil, nil
    local actions = {}
    for _, raw in ipairs(lines) do
        local line = U.trim(raw)
        if line ~= "" then
            local z, x, y = parseGoto(line)
            if z then gotoZone, gx, gy = z, x, y end
            local q = line:match("|q%s+(%d+)")
            if q and not line:match("|future") then qidGlobal = qidGlobal or tonumber(q) end
            local onlyif = line:match("|only%s+if%s+(.-)%s*$") or line:match("|only%s+([%w%s]+)%s*$")
            if onlyif then
                local neg = onlyif:match("^not%s+(.*)")
                local subj = (neg or onlyif):lower():gsub("%s+", "")
                if CLASSES[subj] then onlyClass = (neg and "-" or "") .. subj
                elseif RACES[subj] then onlyRace = (neg and "-" or "") .. subj end
            end
            if line:sub(1, 4) == "|tip" then tips[#tips + 1] = U.trim(line:sub(5))
            else
                local cmd, rest = line:match("^(%a+)%s+(.*)$")
                if not cmd then cmd = line:match("^(%a+)$") rest = "" end
                cmd = cmd and cmd:lower()
                if cmd == "accept" or cmd == "turnin" or cmd == "kill" or cmd == "collect" or cmd == "talk" or cmd == "use" or cmd == "fly" or cmd == "hearth" or cmd == "home" or cmd == "level" or cmd == "goto" or cmd == "click" or cmd == "buy" or cmd == "learn" or cmd == "trash" or cmd == "get" or cmd == "kill" or cmd == "destroy" or cmd == "invehicle" or cmd == "clicknpc" or cmd == "achieve" or cmd == "skill" or cmd == "learnspell" or cmd == "learnpet" or cmd == "earn" or cmd == "cast" or cmd == "confirm" then
                    local body = rest:gsub("|.*$", "")
                    body = U.trim(body)
                    local name, id = body:match("^(.-)##(%d+)")
                    local qid = line:match("|q%s+(%d+)")
                    actions[#actions + 1] = { cmd = cmd, name = U.trim(name or body), id = tonumber(id), qid = tonumber(qid), raw = line }
                elseif line:sub(1, 1) ~= "|" then
                    -- free text
                    local body = U.trim(line:gsub("|.*$", ""))
                    if body ~= "" then tips[#tips + 1] = body end
                end
            end
        end
    end
    local note = table.concat(tips, " ")
    local suffix = ""
    if gotoZone then suffix = suffix .. "|Z|" .. esc(gotoZone) end
    if gx then suffix = suffix .. ("|M|%.2f,%.2f"):format(gx, gy) end
    if onlyClass then suffix = suffix .. "|C|" .. onlyClass end
    if onlyRace then suffix = suffix .. "|R|" .. onlyRace end
    if note ~= "" then suffix = suffix .. "|N|" .. esc(note) end
    local emitted = false
    for _, a in ipairs(actions) do
        local act, title, qid, extra = nil, a.name, a.qid or nil, ""
        if a.cmd == "accept" then act = "A" qid = a.id or qid
        elseif a.cmd == "turnin" then act = "T" qid = a.id or qid
        elseif a.cmd == "kill" then act = "C" title = "Kill " .. a.name qid = a.qid or qidGlobal
        elseif a.cmd == "collect" or a.cmd == "get" then act = "C" title = "Collect " .. a.name qid = a.qid or qidGlobal if a.id then extra = extra .. "|L|" .. a.id .. " " .. (a.name:match("^(%d+)") or 1) end
        elseif a.cmd == "goto" then act = "R" title = "Go to " .. (gotoZone or a.name)
        elseif a.cmd == "fly" then act = "F" title = a.name
        elseif a.cmd == "hearth" then act = "H" title = a.name
        elseif a.cmd == "home" then act = "h" title = a.name
        elseif a.cmd == "level" then act = "L" title = "Level " .. a.name
        elseif a.cmd == "use" then act = "U" title = "Use " .. a.name if a.id then extra = extra .. "|U|" .. a.id end qid = a.qid or qidGlobal
        elseif a.cmd == "buy" then act = "B" title = "Buy " .. a.name
        elseif a.cmd == "talk" or a.cmd == "clicknpc" or a.cmd == "click" or a.cmd == "confirm" then act = "N" title = (a.cmd == "talk" and "Talk to " or "") .. a.name
        else act = "N" title = a.cmd .. " " .. a.name end
        if act then
            local q = qid and ("|QID|" .. qid) or ""
            out[#out + 1] = ("%s %s%s%s%s|"):format(act, esc(title), q, extra, suffix)
            emitted = true
        end
    end
    if not emitted and (gotoZone or note ~= "") then
        out[#out + 1] = ("R %s%s|"):format(esc(gotoZone and ("Go to " .. gotoZone) or "Note"), suffix)
    end
    return out
end

function A.ConvertText(raw)
    local steps, cur = {}, nil
    for line in (raw .. "\n"):gmatch("([^\r\n]*)\r?\n") do
        local t = U.trim(line)
        if t:match("^step%s*$") or t:match("^step%s") then
            if cur then steps[#steps + 1] = cur end
            cur = {}
        elseif cur then cur[#cur + 1] = line end
    end
    if cur then steps[#steps + 1] = cur end
    local out = {}
    for _, s in ipairs(steps) do for _, l in ipairs(convertStep(s)) do out[#out + 1] = l end end
    return table.concat(out, "\n")
end

-- Register one guide given its Zygor title + raw text (shared by live + baked import)
local function registerZ(title, rawOrFn, nextTitle)
    if G.registry["zygor:" .. title] then return false end
    local short = title:match("([^\\]+)$") or title
    local minl, maxl = short:match("%((%d+)%-(%d+)%)")
    local faction = title:find("Alliance") and "Alliance" or (title:find("Horde") and "Horde") or nil
    local gtype = (title:match("^([^\\]+)") or "Guide"):gsub("%s+Guides$", "")
    return G.Register({
        id = "zygor:" .. title,
        name = short,
        type = gtype,
        zone = short:gsub("%s*%(.-%)%s*$", ""),
        faction = faction,
        minlevel = tonumber(minl), maxlevel = tonumber(maxl),
        next = nextTitle and ("zygor:" .. nextTitle) or nil,
        author = "Zygor (local install)",
        source = "Zygor",
        text = type(rawOrFn) == "function" and function() local raw = rawOrFn() return raw and A.ConvertText(raw) or "" end
            or function() return A.ConvertText(rawOrFn) end,
    }) and true or false
end

-- Import from the baked Guides/Imported_Zygor.lua (generated by tools/export_guides.lua);
-- works with the Zygor addon disabled or uninstalled.
function A.ImportStatic()
    local n = 0
    for _, g in ipairs(NS.ImportedZygor or {}) do
        if registerZ(g.title, g.raw, g.next) then n = n + 1 end
    end
    if n > 0 then NS:Print(("Loaded %d baked Zygor guide(s)."):format(n)) end
    return n
end

local imported = 0
function A.Import(verbose)
    local ZGV = _G.ZGV or _G.ZygorGuidesViewer
    if not ZGV or not ZGV.registeredguides then if verbose then NS:Print("Zygor addon not loaded; using baked guides only.") end return 0 end
    local n = 0
    for _, g in ipairs(ZGV.registeredguides) do
        if g.title and (g.rawdata or g.rawdata_full) then
            local gg = g
            if registerZ(g.title, function()
                local raw = gg.rawdata_full or gg.rawdata
                if not raw and gg.Parse then pcall(gg.Parse, gg) raw = gg.rawdata end
                return raw
            end, (g.headerdata or {}).next) then n = n + 1 end
        end
    end
    imported = imported + n
    if verbose or n > 0 then NS:Print(("Imported %d Zygor guide(s) from your local install (%d total)."):format(n, imported)) end
    return n
end

NS:On("PLAYER_READY", function()
    A.ImportStatic()
    A.Import(false)
    NS:After(8, function() A.Import(false) end)
end)
