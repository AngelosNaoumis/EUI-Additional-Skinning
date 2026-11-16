-- Menus.lua on dropdowns this addon does not own (Blizzard's, other addons'): 100 menus of 30
-- rows each, (a) with no skin having bound a menu, (b) with one bound owner whose menu is closed,
-- (c) with a separately bound pooled list also closed.
-- Prints: MEASURE idle_reads idle_seconds bound_reads bound_seconds list_reads list_seconds, where reads counts menu-frame
-- IsShown/GetAlpha reads made by the hooks (the work done for menus that are not ours).
local root = BENCH_ROOT or '.'
local reads = 0
geterrorhandler = function() return function(e) error(e) end end
InCombatLockdown = function() return false end
C_Timer = {After = function(_, fn) fn() end}
hooksecurefunc = function(object, key, callback)
    local original = object[key]
    object[key] = function(...) local a, b, c = original(...); callback(...); return a, b, c end
end
local Frame = {}
Frame.__index = Frame
function Frame:IsShown() reads = reads + 1; return self.shown end
function Frame:GetAlpha() reads = reads + 1; return 1 end
function Frame:SetAlpha() end
function Frame:GetObjectType() return 'Frame' end
function Frame:IsForbidden() return false end
function Frame:IsProtected() return false end
function Frame:HookScript() end
function Frame:RegisterEvent() end
function Frame:SetScript() end
function Frame:GetRegions() end
function Frame:GetChildren() end
CreateFrame = function() return setmetatable({}, Frame) end
for level = 1, 8 do _G['DropDownList' .. level] = setmetatable({shown = level == 1, dropdown = {}}, Frame) end
ToggleDropDownMenu = function() end
UIDropDownMenu_AddButton = function() end

local ns = {IsEnabled = function() return true end, AttachAccent = function() end}
assert(loadfile(root .. '/Menus.lua'))('EUIAdditionalSkinning', ns)
local function Workload()
    reads = 0
    local started = os.clock()
    for _ = 1, 100 do
        ToggleDropDownMenu()
        for _ = 1, 30 do UIDropDownMenu_AddButton() end
    end
    return reads, os.clock() - started
end
local idleReads, idleTime = Workload()
-- A skin binds its own dropdown (closed); the open Blizzard menu belongs to someone else.
local S = {GetFont = function() return 'eui', '' end, GetAccentColor = function() return 1, 1, 1 end}
local module, owner = {enabled = true}, setmetatable({}, Frame)
ns.BindPopupOwner(S, module, owner)
local boundReads, boundTime = Workload()
local list = setmetatable({shown = false, dropdown = owner}, Frame)
function list:Toggle() end
ns.BindPopupList(S, module, owner, list)
local listReads, listTime = Workload()
print(string.format('MEASURE idle %d %.6f bound %d %.6f list %d %.6f',
    idleReads, idleTime, boundReads, boundTime, listReads, listTime))
