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
for _, f in ipairs({ "Core/Init.lua", "Core/Util.lua", "Core/Conditions.lua", "Core/Guide.lua", "Data/Taxi_tbc.lua", "Data/Transit.lua", "Data/Inns.lua", "Routing/TravelGraph.lua", "Routing/StepOrder.lua", "Routing/Router.lua", "Core/Progress.lua" }) do load(f) end
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
print("ALL OFFLINE TESTS PASSED")
