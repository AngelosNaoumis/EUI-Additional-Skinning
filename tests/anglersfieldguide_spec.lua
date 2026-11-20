-- Angler's Field Guide: journal/export shells; dark singleton toast, configured border and native
-- suppression; preserved entries, tabs, map/page controls, movement, notification lifecycle and gates.
local T = dofile('tests/support.lua')
local BasePanel = T.S.Panel
local panelCalls = setmetatable({}, {__mode = 'k'})
T.S.Panel = function(frame, options)
    panelCalls[frame] = (panelCalls[frame] or 0) + 1
    BasePanel(frame, options)
    for _, region in ipairs(frame.regions) do
        if region:GetObjectType() == 'Texture' then region:SetAlpha(0) end
    end
    if not frame.euiasTestPanelBackground then
        local background = T.Texture(frame, 'BACKGROUND')
        background:SetAllPoints(frame)
        background:SetColorTexture(T.S.GetPanelColor())
        frame.euiasTestPanelBackground = background
    end
end

local applied = setmetatable({}, {__mode = 'k'})
EllesmereUI.ApplyBorderStyle = function(frame, ...)
    applied[frame] = {calls = applied[frame] and applied[frame].calls + 1 or 1, args = {...}}
    EllesmereUI._bdBorderData = EllesmereUI._bdBorderData or setmetatable({}, {__mode = 'k'})
    if not EllesmereUI._bdBorderData[frame] then
        local border = T.Frame('Frame', frame)
        border.backdrop = {edgeFile = 'test-border', edgeSize = select(1, ...)}
        border.Center = T.Texture(border, 'BACKGROUND')
        EllesmereUI._bdBorderData[frame] = border
    end
    frame:Show()
end

local ns = T.Load('Skins/AnglersFieldGuide.lua')
ns.SetConfiguredBorderStyleProvider(function()
    return {size = 3, px = 4, texture = 'test-border', r = 0.1, g = 0.2, b = 0.3, a = 0.4,
        offX = 5, offY = 6, shiftX = 7, shiftY = 8, sizeKey = 'heavy'}
end)

local nativeBorder = {'TopEdge', 'BottomEdge', 'LeftEdge', 'RightEdge', 'TopLeftCorner',
    'TopRightCorner', 'BottomLeftCorner', 'BottomRightCorner'}
local function ToastFrame()
    local panel = T.Frame('Frame', nil, 'AnglerGuideToast')
    panel.backdrop = {bgFile = 'Interface\\Buttons\\WHITE8x8',
        edgeFile = 'Interface\\DialogFrame\\UI-DialogBox-Border', edgeSize = 16}
    panel.Center = T.Texture(panel, 'BACKGROUND'); panel.Center:SetAlpha(0.97)
    for _, key in ipairs(nativeBorder) do panel[key] = T.Texture(panel, 'BORDER') end
    panel.slot = T.Frame('Frame', panel)
    panel.slot.backdrop = {bgFile = 'Interface\\Buttons\\WHITE8x8',
        edgeFile = 'Interface\\Buttons\\WHITE8x8', edgeSize = 2}
    panel.head = T.FontString(panel, 'NEW CATCH RECORDED')
    panel.nameText = T.FontString(panel, 'Stonescale Eel')
    panel:Hide()
    return panel
end

local calls, window, export, toast = {}, nil, nil, nil
local guide = {}
for _, name in ipairs({'CreateUI', 'RefreshUI', 'ToggleUI', 'OpenZone', 'OpenJournalSettings',
    'UpdateFilterButton'}) do
    guide[name] = function() calls[name] = (calls[name] or 0) + 1 end
end
guide.OpenCatch = function(_, id) calls.OpenCatch = id end
guide.CreateToast = function()
    calls.CreateToast = (calls.CreateToast or 0) + 1
    toast = ToastFrame()
    toast:SetScript('OnUpdate', function(self) if self.expired then self:Hide() end end)
    toast:SetScript('OnMouseUp', function(self, button)
        if button == 'LeftButton' and self.catch then self:Hide(); guide:OpenCatch(self.catch) end
    end)
    toast:SetScript('OnEnter', function(self) self.hovered = true end)
    toast:SetScript('OnLeave', function(self) self.hovered = false end)
end
guide.Toast = function(_, id)
    toast.catch = id; toast.expired = nil; toast:SetAlpha(1); toast:Show()
end
guide.ShowExport = function()
    calls.ShowExport = (calls.ShowExport or 0) + 1
    if not export then
        export = T.Frame('Frame', nil, 'AnglerGuideExport')
        export.backdrop = {bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background',
            edgeFile = 'Interface\\DialogFrame\\UI-DialogBox-Border', edgeSize = 32}
        export.CloseButton = T.Frame('Button', export)
        export:SetScript('OnDragStart', function(self) self.dragging = true end)
        export:SetScript('OnDragStop', function(self) self.dragging = false end)
    end
    export:Show()
    return 'exported'
end
_G.AnglersFieldGuide = guide

-- AnglerGuideFrame in the Forever look.
window = T.Frame('Frame', nil, 'AnglerGuideFrame')
window.CloseButton = T.Frame('Button', window)
window.PortraitContainer = T.Frame('Frame', window)
window.PortraitContainer:SetPoint('TOPLEFT', window, 'TOPLEFT', -3, 5)
window.header = T.Frame('Frame', window); window.header.text = T.FontString(window.header, 'Catches')
local plate = T.Texture(window.header, 'BACKGROUND'); plate.atlas = 'spellbook-list-backplate'
local divider = T.Texture(window.header, 'ARTWORK'); divider.atlas = 'spellbook-divider'
window.header.text:SetTextColor(0.2, 0.12, 0.05)
local good = T.FontString(window, 'Ready'); good:SetTextColor(0.04, 0.34, 0.04)
local gold = T.FontString(window, 'Rare catch'); gold:SetTextColor(1, 0.82, 0)
window.home = T.Frame('Button', window)
local homeClicks = 0
local homeClick, homeEnter, homeLeave = function() homeClicks = homeClicks + 1 end, function() end, function() end
window.home:SetScript('OnClick', homeClick); window.home:SetScript('OnEnter', homeEnter); window.home:SetScript('OnLeave', homeLeave)
local entry = T.Frame('Button', window); entry.backplate = T.Texture(entry, 'BACKGROUND'); entry.icon = T.Texture(entry, 'ARTWORK')
local tab = T.Frame('Button', window); tab.active = T.Texture(tab, 'ARTWORK')
local classicTab = T.Frame('CheckButton', window); classicTab.icon = T.Texture(classicTab, 'ARTWORK')
local gear = T.Frame('Button', window); gear.normal = T.Texture(gear, 'ARTWORK'); gear.normal.path = 'Interface\\WorldMap\\Gear_64Grey'
local page = T.Frame('Button', window); page.normal = T.Texture(page, 'ARTWORK'); page.normal.path = 'Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up'
local back = T.Frame('Button', window); back.label = T.FontString(back, 'Back')
local search = T.Frame('EditBox', window, 'AnglerGuideSearch')
local slot = T.Frame('Frame', window); slot.backdrop = {bgFile = 'Interface\\Buttons\\WHITE8x8', edgeFile = 'Interface\\Buttons\\WHITE8x8', edgeSize = 2}
local filter = T.Frame('Frame', window, 'AnglerGuideFilterMenu'); filter.backdrop = {bgFile = 'Interface\\Tooltips\\UI-Tooltip-Background', edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border', edgeSize = 16}
local dragStart, dragStop = function(self) self.dragging = true end, function(self) self.dragging = false end
window:SetScript('OnDragStart', dragStart); window:SetScript('OnDragStop', dragStop)

T.Install('AnglersFieldGuide')
assert(window.skin.Shell, 'journal window not shelled')
local point, relative, relativePoint, x, y = window.PortraitContainer:GetPoint(1)
assert(point == 'TOPLEFT' and relative == window and relativePoint == 'TOPLEFT' and x == 8 and y == -8,
    'portrait container not placed inside the window')
window.home:GetScript('OnClick')(window.home)
assert(homeClicks == 1 and window.home:GetScript('OnEnter') == homeEnter
    and window.home:GetScript('OnLeave') == homeLeave,
    'portrait home action or tooltip changed')
assert(window:GetScript('OnDragStart') == dragStart and window:GetScript('OnDragStop') == dragStop,
    'journal dragging scripts changed')
assert(window.CloseButton.skin.CloseButton and not window.CloseButton.skin.Button,
    'journal close button was boxed')
local r, g, b = window.header.text:GetTextColor()
assert(r == 1 and g == 1 and b == 1, 'spellbook ink remained unreadable')
r, g, b = good:GetTextColor()
assert(g > 0.9 and r < g and b < g, 'coloured ink lost its hue')
r, g, b = gold:GetTextColor()
assert(r == 1 and g == 0.82 and b == 0, 'gold text changed')
assert(plate.alpha == 0 and divider.alpha ~= 0, 'header backplate kept or divider faded')
assert(not entry.skin.Button and not (entry.icon.skin and entry.icon.skin.SquareIcon),
    'catch entry art was restyled')
assert(not tab.skin.Button and not classicTab.skin.Checkbox and not window.home.skin.Button,
    'journal tab or portrait home target was restyled')
assert(not gear.skin.Button and not page.skin.Button, 'gear or page-arrow art was restyled')
assert(back.skin.Button and search.skin.EditBox, 'button or search box not styled')
assert(slot.backdrop.edgeSize == 1 and filter.backdrop.edgeSize == 1,
    'icon slot or filter menu did not receive a flat edge')

-- The export is lazy and must retain its movement scripts after the factory hook discovers it.
assert(guide.ShowExport() == 'exported'); T.Flush()
assert(export.skin.Shell and export.CloseButton.skin.CloseButton, 'lazy export window not fully skinned')
export:GetScript('OnDragStart')(export); assert(export.dragging)
export:GetScript('OnDragStop')(export); assert(not export.dragging, 'export dragging changed')

-- Toast creation during combat defers every visual write to the existing combat-end pass.
T.combat = true; guide.CreateToast(); T.Flush()
assert(not applied[toast] and toast.TopEdge:GetAlpha() == 1, 'toast creation modified UI during combat')
T.combat = false; T.Fire('PLAYER_REGEN_ENABLED'); T.Flush()
assert(applied[toast] and applied[toast].calls == 1, 'toast did not receive exactly one configured border')
local args = applied[toast].args
assert(args[1] == 3 and args[2] == 0.1 and args[5] == 0.4 and args[6] == 'test-border'
    and args[7] == 5 and args[8] == 6 and args[9] == 7 and args[10] == 8
    and args[11] == 'actionbars' and args[12] == 'heavy' and args[14] == 4,
    'toast border did not receive the configured style')
for _, key in ipairs(nativeBorder) do
    assert(toast[key]:GetAlpha() == 0, 'native toast edge remained visible: ' .. key)
    toast[key]:SetAlpha(1)
    assert(toast[key]:GetAlpha() == 0, 'native toast edge reappeared: ' .. key)
end
assert(panelCalls[toast] == 1 and toast.Center:GetAlpha() == 0,
    'toast did not replace its inset parchment with one EUI fill')
toast.Center:SetAlpha(1)
assert(toast.Center:GetAlpha() == 0, 'toast parchment reappeared')
local dark = toast.euiasTestPanelBackground
assert(dark and dark.all == toast and dark.color[1] == 0.07 and dark.color[4] == 0.97,
    'toast background does not fill the owner with the active EUI panel colour')
assert(ns.OwnFrames[EllesmereUI._bdBorderData[toast]],
    'generated border child was exposed as Angler content')
assert(not toast:IsShown(), 'border creation showed the hidden toast')
assert(toast.slot.backdrop.edgeSize == 1, 'toast icon slot was not styled')

-- Repeated catches reuse the singleton and keep its timing, hover and click lifecycle.
local owner, onEnter, onLeave = toast, toast:GetScript('OnEnter'), toast:GetScript('OnLeave')
for _, id in ipairs({111, 222, 333}) do guide:Toast(id); assert(toast == owner); toast:Hide() end
toast:Show(); toast.expired = true; toast:GetScript('OnUpdate')(toast)
assert(not toast:IsShown(), 'toast timing/disappearance changed')
toast.expired = nil; guide:Toast(444); toast:GetScript('OnMouseUp')(toast, 'LeftButton')
assert(calls.OpenCatch == 444 and not toast:IsShown(), 'toast click/open behavior changed')
assert(toast:GetScript('OnEnter') == onEnter and toast:GetScript('OnLeave') == onLeave,
    'toast tooltip lifecycle changed')

local counts = {#window.regions, #window.children, #toast.regions, #toast.children}
T.Refresh('AnglersFieldGuide'); T.Refresh('AnglersFieldGuide')
assert(#window.regions == counts[1] and #window.children == counts[2]
    and #toast.regions == counts[3] and #toast.children == counts[4] and applied[toast].calls == 1,
    'warm pass created objects or a duplicate toast border')

-- The target addon missing or this skin disabled leaves native UI untouched.
local T2 = dofile('tests/support.lua')
_G.AnglersFieldGuide = nil
T2.Load('Skins/AnglersFieldGuide.lua')
local stray = T2.Frame('Frame', nil, 'AnglerGuideFrame')
T2.Install('AnglersFieldGuide')
assert(not stray.skin.Shell and not T2.Module('AnglersFieldGuide').active,
    "installed without Angler's Field Guide")

local T3 = dofile('tests/support.lua')
EUIAdditionalSkinningDB = {skins = {AnglersFieldGuide = false}}
local disabledBorders = 0
EllesmereUI.ApplyBorderStyle = function() disabledBorders = disabledBorders + 1 end
_G.AnglersFieldGuide = {}
local ns3 = T3.Load('Skins/AnglersFieldGuide.lua')
local disabled = T3.Frame('Frame', nil, 'AnglerGuideToast')
disabled.TopEdge = T3.Texture(disabled, 'BORDER')
local entry3 = T3.Entry('AnglersFieldGuide')
T3.loaded.AnglersFieldGuide = true; T3.Fire('ADDON_LOADED', 'AnglersFieldGuide')
assert(T3.registered[T3.PREFIX .. entry3.label], 'disabled skin not registered with EllesmereUI')
T3.registered[T3.PREFIX .. entry3.label](T3.S); T3.Flush()
assert(#ns3.modules == 0 and disabledBorders == 0 and disabled.TopEdge:GetAlpha() == 1,
    "switched-off Angler's Field Guide skin changed a frame")

print("PASS: Angler's Field Guide shells, dark singleton toast, configured border, preserved fishing art/lifecycle, combat, hooks, idempotence and gates")
