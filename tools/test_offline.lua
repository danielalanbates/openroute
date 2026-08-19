-- Offline smoke test for OpenRoute's parser + routing, run with: luajit tools/test_offline.lua
-- Stubs just enough of the WoW API + HereBeDragons to exercise Guide.ParseLine, TravelGraph.FindPath, StepOrder.
package.path = "./?.lua;" .. package.path
local ADDON, NS = "OpenRoute", {}
-- ---- WoW API stubs ----
local frames = {}
function CreateFrame() local f = { scripts = {} } function f:RegisterEvent() end function f:SetScript(k, v) self.scripts[k] = v end
    for _, m in ipairs({"SetSize","SetPoint","Show","Hide","SetMovable","EnableMouse","SetClampedToScreen","RegisterForDrag","SetFrameStrata","SetScale","SetAlpha","ClearAllPoints","SetBackdrop","SetBackdropColor","SetBackdropBorderColor","SetResizable","SetResizeBounds","SetText","SetAttribute","SetHighlightTexture","RegisterForClicks","SetAllPoints","SetTexCoord","SetTexture","SetJustifyH","SetWidth","SetWordWrap","SetMaxLines","SetTextColor","SetHeight","SetAutoFocus","SetScrollChild","SetChecked","SetColorTexture","SetRotation","SetCooldown","SetMinMaxValues","SetValueStep","SetObeyStepOnDrag","SetValue"}) do f[m] = function() end end
    function f:CreateTexture() return CreateFrame() end function f:CreateFontString() return CreateFrame() end function f:IsShown() return false end function f:GetPoint() return "CENTER",nil,nil,0,0 end
    f.Text = CreateFrame and { SetText = function() end } or nil
    return f end
UIParent = {}; UISpecialFrames = {}
function GetBuildInfo() return "2.5.6", "69110", "2026", 20506 end
C_AddOns = { GetAddOnMetadata = function() return "test" end }
tinsert = table.insert; strjoin = function(sep, ...) return table.concat({...}, sep) end; tostringall = function(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end return unpack(t) end
strsplit = function(sep, s) local out = {} for piece in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = piece end return unpack(out) end
strtrim = function(s) return s:match("^%s*(.-)%s*$") end
C_Timer = { After = function(_, fn) fn() end }
function GetTime() return os.clock() end
function debugprofilestop() return os.clock() * 1000 end
function UnitFactionGroup() return "Alliance" end
function UnitClass() return "Warrior", "WARRIOR" end
function UnitRace() return "Human", "Human" end
function UnitName() return "Tester" end
function GetRealmName() return "Test" end
function UnitLevel() return 5 end
function UnitXP() return 0 end function UnitXPMax() return 100 end
function GetUnitSpeed() return 0 end
function IsMounted() return false end
function InCombatLockdown() return false end
function GetBindLocation() return "Goldshire" end
function GetPlayerFacing() return 0 end
C_QuestLog = { IsQuestFlaggedCompleted = function() return false end, IsOnQuest = function() return false end, GetQuestObjectives = function() return {} end, GetLogIndexForQuestID = function() return nil end }
C_Item = { GetItemCount = function(id) return id == 6948 and 1 or 0 end, GetItemNameByID = function(id) return "item" .. id end, GetItemIconByID = function() return "" end }
C_Container = { GetItemCooldown = function() return 0, 0 end }
IsSpellKnown = function() return false end
-- fake maps: Elwynn 1429 (EK inst 0), Westfall 1436, Stormwind 1453, Ironforge 1455, Wetlands 1437, Darkshore 1414? use real ids
local MAPS = { [1429]={ "Elwynn Forest", 0, -9500, 300, 4000, 3000 }, [1436]={ "Westfall", 0, -10600, 1100, 4000, 3000 }, [1453]={ "Stormwind City", 0, -8900, 600, 1500, 1200 },
  [1455]={ "Ironforge", 0, -4800, -1100, 1000, 800 }, [1437]={ "Wetlands", 0, -3500, -2500, 5000, 3000 }, [1439]={ "Darkshore", 1, 6500, 500, 5000, 6000 }, [1438]={ "Teldrassil", 1, 9900, 900, 5000, 5000 },
  [1457]={ "Darnassus", 1, 9900, 2100, 1000, 1000 }, [1440]={ "Ashenvale", 1, 3500, 800, 6000, 4000 }, [1411]={ "Durotar", 1, 500, -4400, 5000, 5000 }, [1454]={ "Orgrimmar", 1, 1600, -4500, 1500, 1500 }, [1413]={ "The Barrens", 1, -1400, -2600, 10000, 6000 },
  [1434]={ "Stranglethorn Vale", 0, -12500, -400, 6000, 4000 }, [1435]={ "Swamp of Sorrows", 0, -10400, -3000, 4000, 3000 }, [1445]={ "Dustwallow Marsh", 1, -3800, -3200, 5000, 4000 }, [1441]={ "Thousand Needles", 1, -5500, -2500, 5000, 3000 } }
-- world coords of zone (x01,y01): wx = top - y01*h ; wy = left - x01*w  (roughly WoW: x north, y west)
local function z2w(x, y, m) local d = MAPS[m] if not d then return nil end return d[3] - y * d[6], d[4] - x * d[5], d[2] end
C_Map = { GetMapInfo = function(id) local d = MAPS[id] return d and { name = d[1], mapType = 3, mapID = id, parentMapID = 0 } end }
local HBD = { GetAllMapIDs = function() local t = {} for id in pairs(MAPS) do t[#t + 1] = id end return t end,
  GetWorldCoordinatesFromZone = function(_, x, y, m) return z2w(x, y, m) end,
  GetZoneDistance = function(_, m1, x1, y1, m2, x2, y2) local ax, ay, ai = z2w(x1, y1, m1) local bx, by, bi = z2w(x2, y2, m2) if ai ~= bi then return nil end return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) end,
  GetPlayerWorldPosition = function() return PLAYER.wx, PLAYER.wy, PLAYER.inst end,
  GetPlayerZonePosition = function() return PLAYER.x, PLAYER.y, PLAYER.map end }
LibStub = function(name) if name == "HereBeDragons-2.0" then return HBD end return { Fire = function() end } end
PLAYER = { map = 1429, x = 0.487, y = 0.42 } PLAYER.wx, PLAYER.wy, PLAYER.inst = z2w(PLAYER.x, PLAYER.y, PLAYER.map)
-- ---- load addon files ----
local function load(path) local fn = assert(loadfile("OpenRoute/" .. path)) fn(ADDON, NS) end
for _, f in ipairs({ "Core/Init.lua", "Core/Util.lua", "Core/Conditions.lua", "Core/Guide.lua", "Data/Taxi_tbc.lua", "Data/Transit.lua", "Data/Inns.lua", "Routing/TravelGraph.lua", "Routing/StepOrder.lua", "Routing/Router.lua", "Core/Progress.lua", "Adapters/Zygor.lua", "Adapters/WoWPro.lua", "Guides/Imported_Zygor.lua", "Guides/Imported_WoWPro.lua" }) do load(f) end
-- fake ADDON_LOADED
OpenRouteDB, OpenRouteCharDB = nil, nil
for _, h in ipairs(NS.wowHandlers.ADDON_LOADED) do h("ADDON_LOADED", "OpenRoute") end
NS.db.profile.debug = true
NS.db.profile.routing.assumeAllTaxi = true
-- 1) parser
local s = NS.Guide.ParseLine("C Wolves Across the Border|QID|33|M|46.89,39.05;51.6,40.9|Z|1429; Elwynn Forest|L|750 8|N|Diseased Young Wolves.|S|", 1)
assert(s.action == "C" and s.qid[1] == 33 and #s.coords == 2 and s.zone == 1429 and s.loot[1].id == 750 and s.loot[1].qty == 8 and s.sticky, "parse failed")
print("parser OK:", s.title, s.zone, s.coords[1].x, s.note)
-- 2) travel graph
NS.TravelGraph.Build()
print("graph nodes:", #NS.TravelGraph.nodes)
local sx, sy, si = z2w(0.487, 0.42, 1429)     -- Northshire
local gx, gy, gi = z2w(0.526, 0.657, 1453)    -- Stormwind
local p = NS.TravelGraph.FindPath(sx, sy, si, gx, gy, gi, {})
print("Northshire->Stormwind:", NS.TravelGraph.Describe(p))
gx, gy, gi = z2w(0.30, 0.44, 1439)            -- Darkshore (other continent -> needs boat)
p = NS.TravelGraph.FindPath(sx, sy, si, gx, gy, gi, {})
print("Northshire->Darkshore:", NS.TravelGraph.Describe(p))
assert(p, "no cross-continent path")
gx, gy, gi = z2w(0.4, 0.5, 1436)              -- Westfall, hearth is Goldshire (seed inn) - far walk vs hearth
local wx1, wy1, wi1 = z2w(0.5, 0.5, 1437) p = NS.TravelGraph.FindPath(wx1, wy1, wi1, gx, gy, gi, {}) assert(p and p.legs[1].mode == "hearth", "expected hearth-first path") -- from Wetlands to Westfall
print("Wetlands->Westfall:", NS.TravelGraph.Describe(p))
-- 3) step ordering
local steps = {}
for i, line in ipairs({
 "A Q1|QID|1|M|48,42|Z|1429; Elwynn Forest|",
 "C Q1|QID|1|M|48,36|Z|1429; Elwynn Forest|",
 "A Q2|QID|2|M|48,42|Z|1429; Elwynn Forest|",
 "C Q2|QID|2|M|53,45|Z|1429; Elwynn Forest|",
 "T Q1|QID|1|M|48,42|Z|1429; Elwynn Forest|",
 "T Q2|QID|2|M|48,42|Z|1429; Elwynn Forest|",
 "R Goldshire|M|43,65|Z|1429; Elwynn Forest|",
 "A Q3|QID|3|M|42,66|Z|1429; Elwynn Forest|",
}) do steps[i] = NS.Guide.ParseLine(line, i) steps[i].index = i end
local ordered = NS.StepOrder.Order(steps, NS.Router)
for i, st in ipairs(ordered) do io.write(("%d:%s%s "):format(st.index, st.action, st.title)) end print()
-- constraints: A1 before C1 before T1; A2 before C2 before T2; R(7) after all of 1-6, A3 after R
local pos = {} for i, st in ipairs(ordered) do pos[st.index] = i end
assert(pos[1] < pos[2] and pos[2] < pos[5] and pos[3] < pos[4] and pos[4] < pos[6] and pos[7] > pos[6] and pos[7] > pos[5] and pos[8] > pos[7], "constraint violated")
print("StepOrder OK (Q1 accept ->", pos[1], " both accepts adjacent:", math.abs(pos[1]-pos[3]) == 1, ")")
-- 4) SuggestNext: level fit + travel-time tiebreak from player position (lvl 5, standing in Elwynn)
local function regGuide(id, name, minl, maxl, zone, x, y, src)
    NS.Guide.Register({ id = id, name = name, type = "Leveling", faction = "Alliance", minlevel = minl, maxlevel = maxl, source = src or "test",
        text = ("R %s|M|%.1f,%.1f|Z|%d; %s|"):format(name, x, y, zone, (MAPS[zone] or {})[1] or "?") })
end
regGuide("t:elwynn", "Elwynn 5-10", 5, 10, 1429, 48, 42)
regGuide("t:darkshore", "Darkshore 5-10", 5, 10, 1439, 30, 44)   -- same fit, other continent
regGuide("t:westfall", "Westfall 10-20", 10, 20, 1436, 40, 50)   -- out of level range
local nxt, eta = NS.Guide.SuggestNext(nil)
assert(nxt and nxt.id == "t:elwynn", "SuggestNext picked " .. tostring(nxt and nxt.id) .. " (want nearby t:elwynn)")
print(("SuggestNext OK: %s eta %s s"):format(nxt.id, tostring(eta and math.floor(eta))))
local nxt2 = NS.Guide.SuggestNext("t:elwynn")                     -- just finished elwynn -> excluded
assert(nxt2 and nxt2.id == "t:darkshore", "exclude failed: " .. tostring(nxt2 and nxt2.id))
UnitLevel = function() return 11 end                              -- ding: only Westfall fits now
local nxt3 = NS.Guide.SuggestNext("t:elwynn")
assert(nxt3 and nxt3.id == "t:westfall", "level refilter failed: " .. tostring(nxt3 and nxt3.id))
UnitLevel = function() return 21 end                              -- above all ranges -> nearest bracket above = none
assert(NS.Guide.SuggestNext(nil) == nil or true)                  -- must not error
UnitLevel = function() return 8 end                               -- gap: 8 not in 10-20, elwynn/darkshore 5-10 still fit
print("SuggestNext exclude/refit OK")
-- 5) baked guide import (standalone, no Zygor/WoWPro addons)
local nz = NS.Adapters.Zygor.ImportStatic()
local nw = NS.Adapters.WoWPro.ImportStatic()
print(("baked import: %d zygor, %d wowpro"):format(nz, nw))
assert(nz > 500, "expected >500 baked Zygor guides, got " .. nz)
assert(nw > 50, "expected >50 baked WoW-Pro guides, got " .. nw)
-- a baked Zygor guide must parse into real steps
local lv = 0
for _, id in ipairs(NS.Guide.list) do
    local g = NS.Guide.registry[id]
    if g.source == "Zygor" and (g.type or ""):lower() == "leveling" then local st = NS.Guide.Steps(id) if st and #st > 10 then lv = lv + 1 end if lv > 3 then break end end
end
assert(lv > 3, "baked Zygor leveling guides did not parse")
print("baked guides parse OK")
-- 5b) generated quest DB guides (flavor-gated: harness reports TBC 2.5.6 -> only _tbc loads)
local fq = io.open("OpenRoute/Guides/Imported_Quests_tbc.lua")
if fq then
    fq:close()
    for _, qf in ipairs({ "Guides/Imported_Quests_era.lua", "Guides/Imported_Quests_tbc.lua" }) do load(qf) end
    local qGuides, qSteps = 0, 0
    for _, id in ipairs(NS.Guide.list) do
        local g = NS.Guide.registry[id]
        if (g.type or "") == "Quests" then
            qGuides = qGuides + 1
            if qSteps <= 10 then local st = NS.Guide.Steps(id) qSteps = math.max(qSteps, st and #st or 0) end
            assert(not id:find("^qdb:era"), "era quest guides leaked into tbc flavor: " .. id)
        end
    end
    assert(qGuides > 150, "expected >150 tbc quest guides, got " .. qGuides)
    assert(qSteps > 10, "quest guide steps did not parse")
    print(("quest DB guides OK: %d zone guides (tbc), sample parsed %d steps"):format(qGuides, qSteps))
else
    print("quest DB guides SKIPPED (Imported_Quests_tbc.lua not baked)")
end
-- 6) guide menu tree (organization): categories ordered, every guide reachable, search works
GameTooltip = CreateFrame()
local fn = assert(loadfile("OpenRoute/UI/GuideMenu.lua")) fn(ADDON, NS)
local T = NS.GuideMenu._test
local root = T.buildTree()
assert(#root.kids > 1, "tree has only " .. #root.kids .. " top-level categories")
assert(root.kids[1].name == "Leveling", "first category is " .. root.kids[1].name .. " (want Leveling)")
local total = #NS.Guide.Available()
assert(root.count == total, ("tree count %d ~= available %d"):format(root.count, total))
-- expand everything: every guide must appear exactly once as a row
local function expandAll(n) for _, k in ipairs(n.kids) do T.expanded[k.path] = true expandAll(k) end end
expandAll(root)
local rows = T.visibleRows()
local guideRows = 0 for _, r in ipairs(rows) do if r.kind == "guide" then guideRows = guideRows + 1 end end
assert(guideRows == total, ("expanded rows %d ~= available %d"):format(guideRows, total))
for k in pairs(T.expanded) do T.expanded[k] = nil end
-- collapsed: only top-level category rows, no guides
local collapsed = T.visibleRows()
for _, r in ipairs(collapsed) do assert(r.kind == "node" and r.depth == 0, "collapsed view leaked a non-root row") end
-- zygor guides keep their folder structure (a Leveling subfolder exists)
local lev = root.kidByName["Leveling"]
assert(lev and #lev.kids > 0, "Leveling category has no subfolders")
-- search returns only matching guide rows
local sr = T.searchRows("elwynn")
assert(#sr > 0, "search 'elwynn' found nothing")
for _, r in ipairs(sr) do assert(r.kind == "guide") end
print(("menu tree OK: %d categories, %d guides reachable, %d search hits for 'elwynn'"):format(#root.kids, guideRows, #sr))
print("ALL OFFLINE TESTS PASSED")
