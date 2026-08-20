-- Offline smoke test for CompletionRoute's parser + routing, run with: luajit tools/test_offline.lua
-- Stubs just enough of the WoW API + HereBeDragons to exercise Guide.ParseLine, TravelGraph.FindPath, StepOrder.
package.path = "./?.lua;" .. package.path
local ADDON, NS = "CompletionRoute", {}
-- ---- WoW API stubs ----
local frames = {}
function CreateFrame() local f = { scripts = {} } function f:RegisterEvent() end function f:SetScript(k, v) self.scripts[k] = v end
    function f:Show() self.__shown = true end function f:Hide() self.__shown = false end
    for _, m in ipairs({"SetSize","SetPoint","SetMovable","EnableMouse","SetClampedToScreen","RegisterForDrag","SetFrameStrata","SetScale","SetAlpha","ClearAllPoints","SetBackdrop","SetBackdropColor","SetBackdropBorderColor","SetResizable","SetResizeBounds","SetText","SetAttribute","SetHighlightTexture","RegisterForClicks","SetAllPoints","SetTexCoord","SetTexture","SetJustifyH","SetWidth","SetWordWrap","SetMaxLines","SetTextColor","SetHeight","SetAutoFocus","SetScrollChild","SetChecked","SetColorTexture","SetRotation","SetCooldown","SetMinMaxValues","SetValueStep","SetObeyStepOnDrag","SetValue","SetBlendMode","SetLooping","SetOffset","SetDuration","SetSmoothing","Play","Stop","IsPlaying","SetVertexColor","SetFrameLevel","SetParent","SetShown","SetDrawLayer"}) do f[m] = function() end end
    function f:CreateTexture() return CreateFrame() end function f:CreateAnimationGroup() local g = CreateFrame() g.__playing = false function g:Play() self.__playing = true end function g:Stop() self.__playing = false end function g:IsPlaying() return self.__playing end return g end function f:CreateAnimation() return CreateFrame() end function f:CreateFontString() return CreateFrame() end function f:IsShown() return false end function f:GetPoint() return "CENTER",nil,nil,0,0 end
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
date = os.date
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
function UnitExists(u) return u == "target" end
NAMEPLATES = {}
WORLDFRAME_KIDS = {}
WorldFrame = { GetChildren = function() return unpack(WORLDFRAME_KIDS) end }
C_NamePlate = { GetNamePlates = function() return NAMEPLATES end,
    GetNamePlateForUnit = function(u) for _, pl in ipairs(NAMEPLATES) do if pl.namePlateUnitToken == u then return pl end end end }
HBD_PINS_WORLDMAP_SHOW_PARENT = 1
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
local function load(path)
    if path:match("^Guides/Imported_") and not io.open("CompletionRoute/" .. path, "r") then
        print("skip " .. path .. " (baked locally, gitignored)") return
    end
    local fn = assert(loadfile("CompletionRoute/" .. path)) fn(ADDON, NS)
end
for _, f in ipairs({ "Core/Init.lua", "Core/Util.lua", "Core/Conditions.lua", "Core/Guide.lua", "Data/Taxi_tbc.lua", "Data/Transit.lua", "Data/Inns.lua", "Routing/TravelGraph.lua", "Routing/StepOrder.lua", "Routing/Router.lua", "Core/Account.lua", "Core/Progress.lua", "Adapters/Zygor.lua", "Adapters/WoWPro.lua", "Guides/Imported_Zygor.lua", "Guides/Imported_WoWPro.lua" }) do load(f) end
-- fake ADDON_LOADED
CompletionRouteDB, CompletionRouteCharDB = nil, nil
for _, h in ipairs(NS.wowHandlers.ADDON_LOADED) do h("ADDON_LOADED", "CompletionRoute") end
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
local BAKED = io.open("CompletionRoute/Guides/Imported_Zygor.lua", "r") ~= nil
local nz = NS.Adapters.Zygor.ImportStatic()
local nw = NS.Adapters.WoWPro.ImportStatic()
print(("baked import: %d zygor, %d wowpro"):format(nz, nw))
if BAKED then
    assert(nz > 500, "expected >500 baked Zygor guides, got " .. nz)
    assert(nw > 50, "expected >50 baked WoW-Pro guides, got " .. nw)
else
    print("baked-count assertions SKIPPED (guides not baked; run tools/install.sh)")
end
-- a baked Zygor guide must parse into real steps
if BAKED then
    local lv = 0
    for _, id in ipairs(NS.Guide.list) do
        local g = NS.Guide.registry[id]
        if g.source == "Zygor" and (g.type or ""):lower() == "leveling" then local st = NS.Guide.Steps(id) if st and #st > 10 then lv = lv + 1 end if lv > 3 then break end end
    end
    assert(lv > 3, "baked Zygor leveling guides did not parse")
    print("baked guides parse OK")
end
-- 5b) generated quest DB guides (flavor-gated: harness reports TBC 2.5.6 -> only _tbc loads)
local fq = io.open("CompletionRoute/Guides/Imported_Quests_tbc.lua")
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
local fn = assert(loadfile("CompletionRoute/UI/GuideMenu.lua")) fn(ADDON, NS)
local T = NS.GuideMenu._test
local root = T.buildTree()
assert(#root.kids >= 1, "tree has no top-level categories")
if BAKED then assert(#root.kids > 1, "tree has only " .. #root.kids .. " top-level categories") end
-- "Next Step" is the synthetic level-matched bucket and always sorts first when non-empty;
-- Leveling is the first real category after it.
local firstReal = root.kids[1].name == "Next Step" and root.kids[2] or root.kids[1]
assert(firstReal and firstReal.name == "Leveling", "first real category is " .. tostring(firstReal and firstReal.name))
local total = #NS.Guide.Available()
local nextN = #NS.GuideMenu.NextStepGuides(true)
assert(root.count == total + nextN, ("tree count %d ~= available %d + next %d"):format(root.count, total, nextN))
assert(root.kids[1].name == "Next Step" or nextN == 0, "Next Step is not the first category")
-- every Next Step guide must actually contain the player's level (or be level-agnostic)
UnitLevel = function() return 8 end
for _, g in ipairs(NS.GuideMenu.NextStepGuides(true)) do
    if g.minlevel or g.maxlevel then
        assert((not g.minlevel or 8 >= g.minlevel) and (not g.maxlevel or 8 <= g.maxlevel + 0.99),
            ("Next Step offered %s [%s-%s] at level 8"):format(g.id, tostring(g.minlevel), tostring(g.maxlevel)))
    end
end
print(("Next Step OK: %d level-matched guides at level 8"):format(#NS.GuideMenu.NextStepGuides(true)))
-- expand everything: every guide must appear exactly once as a row
local function expandAll(n) for _, k in ipairs(n.kids) do T.expanded[k.path] = true expandAll(k) end end
expandAll(root)
local rows = T.visibleRows()
local guideRows = 0 for _, r in ipairs(rows) do if r.kind == "guide" then guideRows = guideRows + 1 end end
assert(guideRows == total + nextN, ("expanded rows %d ~= available %d + next %d"):format(guideRows, total, nextN))
for k in pairs(T.expanded) do T.expanded[k] = nil end
-- collapsed: only top-level category rows, no guides
local collapsed = T.visibleRows()
for _, r in ipairs(collapsed) do assert(r.kind == "node" and r.depth == 0, "collapsed view leaked a non-root row") end
assert(#collapsed == #root.kids, "collapsed row count")
-- zygor guides keep their folder structure (a Leveling subfolder exists)
if BAKED then
    local lev = root.kidByName["Leveling"]
    assert(lev and #lev.kids > 0, "Leveling category has no subfolders")
end
-- search returns only matching guide rows
local sr = T.searchRows("elwynn")
if BAKED then assert(#sr > 0, "search 'elwynn' found nothing") end
for _, r in ipairs(sr) do assert(r.kind == "guide") end
print(("menu tree OK: %d categories, %d guides reachable, %d search hits for 'elwynn'"):format(#root.kids, guideRows, #sr))

-- 7) account-wide progression
NS.Account.Init()
local AK = NS.Account.key
assert(AK == "Tester-Test", "account key " .. tostring(AK))
NS.Guide.Register({ id = "t:acct", name = "Acct Test", faction = "Alliance", minlevel = 1, maxlevel = 5, source = "test",
    text = "A One|QID|901|M|48,42|Z|1429; Elwynn Forest|\nA Two|QID|902|M|49,42|Z|1429; Elwynn Forest|\nA Three|QID|903|M|50,42|Z|1429; Elwynn Forest|\nA Four|QID|904|M|51,42|Z|1429; Elwynn Forest|" })
local ast = NS.Guide.Steps("t:acct")
assert(#ast == 4, "acct guide steps " .. #ast)
NS.Progress.Load("t:acct")
NS.Progress.MarkDone(ast[1])
local cn, cp = NS.Account.GuideProgress("t:acct", 4, "char")
assert(cn == 1 and cp == 25, ("char progress %d/%d%%"):format(cn, cp))
-- a second character on the account finished steps 2 and 3
NS.db.global.chars["Alt-Test"] = { name = "Alt", realm = "Test", class = "MAGE", faction = "Alliance",
    done = { ["t:acct"] = { [2] = true, [3] = true } }, skipped = {} }
local an, ap = NS.Account.GuideProgress("t:acct", 4, "account")
assert(an == 3 and ap == 75, ("account progress %d/%d%%"):format(an, ap))
-- opt-in OFF: the alt's work must not affect this character
NS.db.profile.accountWide = false
assert(NS.Progress.IsDone(ast[2]) == false, "accountWide OFF leaked the alt's progress")
assert(NS.Account.OtherDid("t:acct", 2) == false, "OtherDid must respect the opt-in")
-- opt-in ON: it does
NS.db.profile.accountWide = true
assert(NS.Progress.IsDone(ast[2]) == true, "accountWide ON did not honour the alt's progress")
assert(NS.Account.OtherDid("t:acct", 2) == "Alt-Test")
assert(NS.Progress.IsDone(ast[4]) == false, "step nobody did came back done")
-- pending list shrinks to the one step no character has done
NS.Progress.Refresh()
local pend = NS.Progress.Pending(10)
assert(#pend == 1 and pend[1].index == 4, "pending = " .. #pend)
assert(#NS.Account.Characters() == 2, "character roster")
-- quest-level union: an alt that turned in a quest clears the matching step in ANOTHER guide
NS.Guide.Register({ id = "t:acct2", name = "Acct Test B", faction = "Alliance", minlevel = 1, maxlevel = 5, source = "test",
    text = "T One|QID|901|M|48,42|Z|1429; Elwynn Forest|\nT Nine|QID|909|M|48,42|Z|1429; Elwynn Forest|" })
local bst = NS.Guide.Steps("t:acct2")
NS.db.global.chars["Alt-Test"].quests = { [901] = true }
NS.db.profile.accountWide = true
NS.Progress.Load("t:acct2")
assert(NS.Progress.IsDone(bst[1]) == true, "quest 901 done on an alt did not clear the step in another guide")
assert(NS.Progress.IsDone(bst[2]) == false, "quest nobody did came back done")
NS.db.profile.accountQuests = false
assert(NS.Progress.IsDone(bst[1]) == false, "accountQuests=false still unioned by quest id")
NS.db.profile.accountQuests = true
NS.db.profile.accountWide = false
assert(NS.Progress.IsDone(bst[1]) == false, "accountWide=false still unioned by quest id")
NS.db.profile.accountWide = true
NS.Progress.Load("t:acct")
assert(NS.Account.Forget("Alt-Test") == true and NS.Account.Forget(AK) == false, "forget rules")
NS.db.global.chars["Alt-Test"] = { name = "Alt", done = { ["t:acct"] = { [2] = true, [3] = true } } }
NS.db.profile.accountWide = false
-- a bulk sweep must not write into the character's real progress
do
    local before = 0
    for _ in pairs(NS.Account.me.done) do before = before + 1 end
    NS.Account.BeginScratch()
    NS.Progress.Load("t:acct")
    NS.Progress.MarkDone(NS.Guide.Steps("t:acct")[2])
    NS.Account.Done("t:sweep-noise")[99] = true
    NS.Account.EndScratch()
    local after = 0
    for _ in pairs(NS.Account.me.done) do after = after + 1 end
    assert(after == before, ("sweep polluted progress: %d -> %d guides"):format(before, after))
    assert(NS.Account.me.done["t:sweep-noise"] == nil, "scratch write leaked")
end
print("account-wide progression OK: char 25%, account 75%, opt-in gate honoured both ways")

-- 8) target beacon
local Bfn = assert(loadfile("CompletionRoute/UI/Beacon.lua")) Bfn(ADDON, NS)
local BT = NS.Beacon
assert(BT._test.cleanName("Marshal McBride ") == "Marshal McBride")
assert(BT._test.cleanName("Kobold Vermin (x8)") == "Kobold Vermin")
assert(BT._test.cleanName("12") == nil, "numeric fragment accepted as a name")
local function wantsFor(line)
    local st = NS.Guide.ParseLine(line, 1) st.index = 1
    NS.Progress.current = st
    NS.Progress.order = { st }
    return NS.Beacon.WantedNames()
end
local w = wantsFor("A Kobold Camp Cleanup|QID|11|M|48,42|Z|1429; Elwynn Forest|N|from Marshal McBride|T|Marshal McBride|")
assert(w["marshal mcbride"] == "Marshal McBride", "|T| target not picked up")
w = wantsFor("T A Threat Within|QID|12|M|48,42|Z|1429; Elwynn Forest|")
assert(w["a threat within"] == nil, "turn-in with no 'to' should not invent a name")
w = wantsFor("T Report to Goldshire to Marshal Dughan|QID|13|M|43,65|Z|1429; Elwynn Forest|")
assert(w["marshal dughan"] == "Marshal Dughan", "turn-in NPC not mined from title: " .. tostring(next(w)))
w = wantsFor("K Kill Hogger|QID|14|M|30,50|Z|1429; Elwynn Forest|")
assert(w["hogger"] == "Hogger", "kill target not mined")
w = wantsFor("N Talk to Shadow Hunter Denjai|M|48,42|Z|1429; Elwynn Forest|")
assert(w["shadow hunter denjai"] == "Shadow Hunter Denjai", "note 'Talk to X' not mined: " .. tostring(next(w)))
w = wantsFor("C Kill 6 Cavern Crawler|QID|16|M|48,42|Z|1429; Elwynn Forest|")
assert(next(w) == nil or w["cavern crawler"] ~= nil, "C step invented a bad name: " .. tostring(next(w)))
w = wantsFor("A Bounty on Murlocs from Guard Thomas|QID|15|M|43,65|Z|1429; Elwynn Forest|")
assert(w["guard thomas"] == "Guard Thomas", "accept NPC not mined")
-- nameplate marker attaches only for wanted units, and clears when the step moves on
NAMEPLATES = { { namePlateUnitToken = "nameplate1" }, { namePlateUnitToken = "nameplate2" } }
UnitName = function(u) return u == "nameplate1" and "Guard Thomas" or "Random Critter" end
NS.Beacon.RescanPlates()
assert(NS.Beacon.count == 1, "wanted-name count " .. tostring(NS.Beacon.count))
-- the marker must actually attach to the wanted plate (and only that one)
do
    local shown = 0
    for _, m in pairs(NS.Beacon._test.plateMarks) do if m.__shown then shown = shown + 1 end end
    assert(shown == 1, "expected exactly 1 nameplate marker, got " .. shown)
end
-- classic clients return an EMPTY C_NamePlate list even with nameplates on screen; the
-- WorldFrame fallback has to pick them up or the over-head marker never appears there
do
    NAMEPLATES = {}
    local function mkplate(nm)
        local f = CreateFrame()
        f.__name = nm
        function f:IsObjectType(t) return t == "Frame" end
        function f:IsShown() return true end
        function f:GetName() return nil end
        function f:GetRegions()
            local fs = CreateFrame()
            function fs:GetObjectType() return "FontString" end
            function fs:GetText() return nm end
            return fs
        end
        function f:GetChildren() return end
        return f
    end
    WORLDFRAME_KIDS = { mkplate("Guard Thomas"), mkplate("Random Critter") }
    NS.Beacon.RescanPlates()
    assert(NS.Beacon.legacyPlateCount == 2, "legacy scan found " .. tostring(NS.Beacon.legacyPlateCount))
    assert(NS.Beacon.legacyMarked == 1, "legacy marked " .. tostring(NS.Beacon.legacyMarked) .. " (want 1)")
    -- re-anchoring on every rescan is what made the marker stutter; parking must be idempotent
    WORLDFRAME_KIDS = { mkplate("Guard Thomas") }
    NS.Beacon.RescanPlates()
    local mark
    for _, m in pairs(NS.Beacon._test.plateMarks) do if m.__shown then mark = m end end
    assert(mark and mark.__parked, "marker not parked")
    local parked = mark.__parked
    mark.__setpoints = 0
    local realSetPoint = mark.SetPoint
    mark.SetPoint = function(self, ...) self.__setpoints = self.__setpoints + 1 return realSetPoint(self, ...) end
    for _ = 1, 5 do NS.Beacon.RescanPlates() end
    assert(mark.__setpoints == 0, "marker re-anchored " .. mark.__setpoints .. " times while already parked")
    assert(mark.__parked == parked, "marker changed anchor without moving plates")
    WORLDFRAME_KIDS = {}
end
-- an unplaced HereBeDragons pin that we Show() ourselves floats in the middle of the screen
do
    local f = assert(io.open("CompletionRoute/UI/Beacon.lua"))
    local src = f:read("*a") f:close()
    assert(not src:find("pins%[i%]:Show%(%)"), "Beacon shows pin frames itself; let HereBeDragons place them")
end
-- C_NamePlate.GetNamePlates(isSecure=true) returns nothing for insecure addon code; passing it
-- silently disabled the over-head marker on live clients. Never pass it.
do
    local f = assert(io.open("CompletionRoute/UI/Beacon.lua"))
    local src = f:read("*a") f:close()
    assert(not src:find("GetNamePlates%(true%)"), "Beacon passes isSecure to GetNamePlates")
    assert(not src:find("GetNamePlateForUnit%([%w_]+,%s*true%)"), "Beacon passes isSecure to GetNamePlateForUnit")
end
NS.db.profile.beacon.enabled = false
NS.Beacon.RescanPlates()
NS.db.profile.beacon.enabled = true
NS.Beacon.UpdateTargetButton()
assert(NS.Beacon.targetButton.targetName == "Guard Thomas", "target button macro name = " .. tostring(NS.Beacon.targetButton.targetName))
UnitName = function() return "Tester" end
-- the over-head icon must come from the game's own art, and follow the step's action
do
    NS.db.profile.beacon.icon = "action"
    NS.Progress.current = { action = "A", title = "x", index = 1 }
    local t = NS.Beacon.MarkerTexture(NS.Progress.current)
    assert(t == NS.Guide.ACTION_ICON.A, "accept step icon = " .. tostring(t))
    NS.Progress.current = { action = "K", title = "x", index = 1 }
    assert(NS.Beacon.MarkerTexture(NS.Progress.current):find("RaidTargetingIcon"), "kill step should use the raid skull")
    NS.Progress.current = { action = "T", title = "x", index = 1 }
    assert(NS.Beacon.MarkerTexture(NS.Progress.current) == NS.Guide.ACTION_ICON.T, "turn-in icon")
    NS.db.profile.beacon.icon = "arrow"
    local t2, rot = NS.Beacon.MarkerTexture(NS.Progress.current)
    assert(t2:find("arrow_green") and rot, "arrow style should rotate the arrow")
    NS.db.profile.beacon.icon = "action"
    print("over-head icon OK: uses Blizzard step art, skull for kill steps, arrow style still available")
end
-- the arrow's item button must never paint an empty ring
do
    local f = assert(io.open("CompletionRoute/UI/Arrow.lua"))
    local src = f:read("*a") f:close()
    assert(src:find('mode == "hide" or %(not itemID and not spellID%)'),
        "Arrow.applyButton must hide when there is no item and no spell")
    assert(src:find('and %(rec%.item or rec%.spell%)'),
        "Arrow.Update must not enter item/hearth mode without an item or spell")
end
print("target beacon OK: names mined from |T| and titles, nameplate marker + /target button wired")


-- a step with no |M| coords must still resolve a location (quest objective, else zone centre)
do
    local noloc = NS.Guide.ParseLine("C Kill things|QID|55|Z|1429; Elwynn Forest|", 1)
    noloc.index = 1
    assert(not noloc.coords, "test step should have no coords")
    local wx = NS.Router.StepWorld(noloc)
    assert(wx, "step with a zone but no coords resolved nowhere")
    assert(noloc._locSource == "zone", "expected zone fallback, got " .. tostring(noloc._locSource))
    local nozone = NS.Guide.ParseLine("C Kill things|QID|55|", 1)
    nozone.index = 1
    assert(NS.Router.StepWorld(nozone) == nil, "step with nothing should resolve nowhere")
    print("location fallback OK: zone centre used when a guide line has no coordinates")
end

-- flight paths must be learnable without visiting a flight master, and by name on classic
do
    NS.db.char.knownTaxi = {}
    local named = 0
    for _, n in ipairs(NS.TravelGraph.nodes) do if n.taxiID and n.name then named = named + 1 end end
    assert(named > 0, "graph has no named taxi nodes to learn")
    local sample
    for _, n in ipairs(NS.TravelGraph.nodes) do if n.taxiID and n.name then sample = n break end end
    local byname = NS.TravelGraph.NodeByName(sample.name)
    assert(byname and byname.taxiID == sample.taxiID, "NodeByName failed for " .. tostring(sample.name))
    assert(NS.TravelGraph.NodeByName(sample.name:match("^([^,]+)")), "NodeByName failed on the short name")
    -- with nothing known, a known-only route must not claim a flight
    NS.db.profile.routing.assumeAllTaxi = false
    assert(NS.TravelGraph.IsTaxiKnown(sample) == false, "unknown node reported as known")
    NS.db.char.knownTaxi[sample.taxiID] = true
    assert(NS.TravelGraph.IsTaxiKnown(sample) == true, "learned node not reported as known")
    NS.db.profile.routing.assumeAllTaxi = true
    print("taxi learning OK: NodeByName resolves classic flight-master names")
end

-- picking a guide must SHOW the guide window (it read as "the guide was deleted" when hidden)
do
    local f = assert(io.open("CompletionRoute/UI/GuideFrame.lua"))
    local src = f:read("*a") f:close()
    assert(src:find('NS:On%("GUIDE_LOADED", function%(%)%s*\n%s*%-%-'), "GUIDE_LOADED handler shape changed")
    assert(src:find("if not f:IsShown%(%) then f:Show%(%) end"), "loading a guide must show the guide window")
    assert(src:find("function GF.ShowDetail"), "no step detail popup")
    assert(src:find("else GF.ShowDetail%(self.step%) end"), "left-clicking a step must open its details")
    print("guide selection UX OK: window opens on load, rows open a detail popup")
end

-- 9) every documented slash subcommand is actually handled.
-- A refactor once deleted a whole run of elseif branches (chars/accountwide/forget/beacon/
-- verifyfeatures) and nothing caught it, because those commands are only reachable by typing.
do
    local f = assert(io.open("CompletionRoute/Core/Slash.lua"))
    local src = f:read("*a") f:close()
    local handled = {}
    for name in src:gmatch('cmd%s*==%s*"([%w_]+)"') do handled[name] = true end
    local required = { "guides", "load", "icon", "why", "next", "skip", "undo", "reset", "arrow", "beacon", "demo",
                       "chars", "accountwide", "forget", "options", "route", "order", "taxi",
                       "hearth", "import", "switch", "scan", "verify", "verifyfeatures",
                       "verifyall", "autoverify", "log", "stats", "debug", "test" }
    local missing = {}
    for _, c in ipairs(required) do if not handled[c] then missing[#missing + 1] = c end end
    assert(#missing == 0, "slash commands not handled: " .. table.concat(missing, ", "))
    -- and the help line must advertise them
    local help = src:match('NS:Print%("Commands: ([^"]+)"%)')
    assert(help, "no help line")
    local advertised = {}
    for w in help:gmatch("[%w_]+") do advertised[w] = true end
    local unlisted = {}
    for _, c in ipairs(required) do if not advertised[c] then unlisted[#unlisted + 1] = c end end
    assert(#unlisted == 0, "commands missing from the help line: " .. table.concat(unlisted, ", "))
    print(("slash commands OK: %d handled and advertised"):format(#required))
end

print("ALL OFFLINE TESTS PASSED")
