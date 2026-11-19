-- Hunter's Field Guide: journal/export shells; dark target/toast panels, configured borders and native suppression; movement, visibility and notification reuse; contained portrait; controls; hooks, idempotence and gates.
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
    frame:Show() -- the solid-border renderer does this; Borders.lua must restore hidden owners
end
local ns = T.Load('Skins/HuntersFieldGuide.lua')
ns.SetConfiguredBorderStyleProvider(function()
    return {size = 3, px = 4, texture = 'test-border', r = 0.1, g = 0.2, b = 0.3, a = 0.4,
        offX = 5, offY = 6, shiftX = 7, shiftY = 8, sizeKey = 'heavy'}
end)

local nativeBorder = {'TopEdge', 'BottomEdge', 'LeftEdge', 'RightEdge', 'TopLeftCorner',
    'TopRightCorner', 'BottomLeftCorner', 'BottomRightCorner'}
local function Popup(name)
    local panel = T.Frame('Frame', nil, name)
    panel.backdrop = {bgFile = 'Interface\\Buttons\\WHITE8x8',
        edgeFile = 'Interface\\DialogFrame\\UI-DialogBox-Border', edgeSize = 16}
    panel.Center = T.Texture(panel, 'BACKGROUND'); panel.Center:SetAlpha(0.95)
    for _, key in ipairs(nativeBorder) do panel[key] = T.Texture(panel, 'BORDER') end
    panel:Hide()
    return panel
end

local calls = {}
local window, target, toast
local guide = {}
for _, name in ipairs({'CreateUI', 'RefreshUI', 'ToggleUI', 'ShowExport', 'ShowTargetPanel'}) do
    guide[name] = function() calls[name] = (calls[name] or 0) + 1 end
end
guide.CreateTargetPanel = function()
    calls.CreateTargetPanel = (calls.CreateTargetPanel or 0) + 1
    target = Popup('FieldGuideTargetPanel')
    target.zones = T.FontString(target, 'The Barrens')
    target:SetPoint('TOPLEFT', window, 'BOTTOMLEFT', 16, 8)
    target:SetScript('OnMouseUp', function(self) self.dismissed = true; self:Hide() end)
end
guide.CreateToast = function()
    calls.CreateToast = (calls.CreateToast or 0) + 1
    toast = Popup('FieldGuideToast')
    toast.head = T.FontString(toast, 'NEW BEAST RECORDED')
    toast:SetScript('OnUpdate', function(self) if self.expired then self:Hide() end end)
    toast:SetScript('OnMouseUp', function(self) self.dismissed = true; self:Hide() end)
end
guide.Toast = function(kind) toast.kind = kind; toast.expired = nil; toast:Show() end
guide.ToastNotice = function() toast.kind = 'notice'; toast.expired = nil; toast:Show(); return true end
guide.MovePopups = function(on)
    target:SetFrameStrata(on and 'FULLSCREEN_DIALOG' or 'MEDIUM')
    toast:SetFrameStrata(on and 'FULLSCREEN_DIALOG' or 'HIGH')
    target:SetShown(on); toast:SetShown(on)
end
_G.HuntersFieldGuide = guide

-- FieldGuideFrame (PortraitFrameTemplate, the "Forever spellbook" look), as PD:CreateUI builds it.
window = T.Frame('Frame', nil, 'FieldGuideFrame')
local page = T.Texture(window, 'BACKGROUND'); page.atlas = 'spellbook-Page-Right-C60'
window.CloseButton = T.Frame('Button', window)
window.PortraitContainer = T.Frame('Frame', window)
window.PortraitContainer:SetPoint('TOPLEFT', window, 'TOPLEFT', -3, 5)
window.header = T.Frame('Frame', window); window.header.text = T.FontString(window.header, 'Wolves')
local plate = T.Texture(window.header, 'BACKGROUND'); plate.atlas = 'spellbook-list-backplate'
local divider = T.Texture(window.header, 'ARTWORK'); divider.atlas = 'spellbook-divider'
window.header.text:SetTextColor(0.2, 0.12, 0.05) -- SPELLBOOK_FONT_COLOR ink
local good = T.FontString(window, 'Tameable'); good:SetTextColor(0.04, 0.34, 0.04)
local gold = T.FontString(window, 'Gold name'); gold:SetTextColor(1, 0.82, 0)
window.home = T.Frame('Button', window)
local homeClicks = 0
local homeClick, homeEnter, homeLeave = function() homeClicks = homeClicks + 1 end, function() end, function() end
window.home:SetScript('OnClick', homeClick); window.home:SetScript('OnEnter', homeEnter); window.home:SetScript('OnLeave', homeLeave)
local entry = T.Frame('Button', window); entry.backplate = T.Texture(entry, 'BACKGROUND'); entry.icon = T.Texture(entry, 'ARTWORK')
local tab = T.Frame('Button', window); tab.active = T.Texture(tab, 'ARTWORK')
local back = T.Frame('Button', window); back.label = T.FontString(back, 'Back')
local search = T.Frame('EditBox', window, 'FieldGuideSearch')
local slot = T.Frame('Frame', window); slot.backdrop = {bgFile = 'Interface\\Buttons\\WHITE8x8', edgeFile = 'Interface\\Buttons\\WHITE8x8', edgeSize = 2}
local export = T.Frame('Frame', nil, 'FieldGuideExport')
export.CloseButton = nil

T.Install('HuntersFieldGuide')
assert(window.skin.Shell and export.skin.Shell, 'journal or export window not shelled')
local point, relative, relativePoint, x, y = window.PortraitContainer:GetPoint(1)
assert(point == 'TOPLEFT' and relative == window and relativePoint == 'TOPLEFT' and x == 8 and y == -8,
    'portrait container not placed wholly inside the window')
window.home:GetScript('OnClick')(window.home)
assert(homeClicks == 1 and window.home:GetScript('OnEnter') == homeEnter
    and window.home:GetScript('OnLeave') == homeLeave,
    'portrait home action or tooltip script changed')
assert(window.CloseButton.skin.CloseButton and not window.CloseButton.skin.Button, 'X boxed instead of a close button')
local r, g, b = window.header.text:GetTextColor()
assert(r == 1 and g == 1 and b == 1, 'spellbook ink left unreadable on the dark shell')
r, g, b = good:GetTextColor()
assert(g > 0.9 and r < g and b < g, 'coloured ink lost its hue')
r, g, b = gold:GetTextColor()
assert(r == 1 and g == 0.82 and b == 0, 'gold text changed')
assert(plate.alpha == 0 and divider.alpha ~= 0, 'header backplate kept, or the divider faded')
assert(not entry.skin.Button and not (entry.icon.skin and entry.icon.skin.SquareIcon), 'beast entry restyled (its art carries the marks)')
assert(not tab.skin.Button and not window.home.skin.Button, 'icon tab or home button restyled')
assert(back.skin.Button and search.skin.EditBox, 'button or search box not styled')
assert(slot.backdrop.edgeSize == 1 and slot.backdrop.bgFile, 'icon slot not a flat edge with its fill')

-- Core creates both panels after CreateUI. Their verified factory hooks discover and skin the
-- initially hidden frames without waiting for a target change or first notification. A creation
-- during combat is left untouched until the framework's existing combat-end event resumes the pass.
T.combat = true
guide.CreateTargetPanel(); guide.CreateToast(); T.Flush()
assert(not applied[target] and not applied[toast] and target.TopEdge:GetAlpha() == 1
    and toast.TopEdge:GetAlpha() == 1, 'panel creation modified UI during combat')
T.combat = false; T.Fire('PLAYER_REGEN_ENABLED'); T.Flush()

for _, panel in ipairs({target, toast}) do
    assert(applied[panel] and applied[panel].calls == 1, 'panel did not receive exactly one configured border')
    local args = applied[panel].args
    assert(args[1] == 3 and args[2] == 0.1 and args[5] == 0.4 and args[6] == 'test-border'
        and args[7] == 5 and args[8] == 6 and args[9] == 7 and args[10] == 8
        and args[11] == 'actionbars' and args[12] == 'heavy' and args[14] == 4,
        'panel border did not receive the configured style, thickness, colour, opacity or offsets')
    assert(panel.backdrop.edgeSize == 16
        and panel.backdrop.edgeFile == 'Interface\\DialogFrame\\UI-DialogBox-Border',
        'native panel backdrop definition changed')
    for _, key in ipairs(nativeBorder) do
        assert(panel[key]:GetAlpha() == 0, 'native panel border remained visible: ' .. key)
        panel[key]:SetAlpha(1)
        assert(panel[key]:GetAlpha() == 0, 'native panel border reappeared: ' .. key)
    end
    assert(ns.OwnFrames[EllesmereUI._bdBorderData[panel]],
        'generated configured-border child was exposed as Hunter\'s Field Guide content')
    assert(not panel:IsShown(), 'border creation showed a hidden panel')
end
assert(target.skin.Panel and target.skin.Panel.noBorder and target.Center:GetAlpha() == 0
    and panelCalls[target] == 1,
    'target did not replace the tan native fill with one borderless EUI panel fill')
target.Center:SetAlpha(1)
assert(target.Center:GetAlpha() == 0, 'target native tan fill reappeared')
local targetDark = target.euiasTestPanelBackground
assert(targetDark and targetDark.all == target and targetDark.color[1] == 0.07
    and targetDark.color[4] == 0.97,
    'target dark background does not match the active EUI panel colour or owner geometry')
assert(toast.skin.Panel and toast.skin.Panel.noBorder and toast.Center:GetAlpha() == 0
    and panelCalls[toast] == 1,
    'toast dark background or existing one-panel treatment changed')
toast.Center:SetAlpha(1)
assert(toast.Center:GetAlpha() == 0, 'toast native tan fill reappeared')
local dark = toast.euiasTestPanelBackground
assert(dark and dark.all == toast and dark.color[1] == 0.07 and dark.color[4] == 0.97,
    'toast dark background does not match the active EUI panel colour or owner geometry')

-- Dragging changes only the owner's anchors; direct border ownership follows it. Dismissal and the
-- toast's existing OnUpdate/OnMouseUp lifecycle scripts remain authoritative.
target:ClearAllPoints(); target:SetPoint('CENTER', window, 'CENTER', 21, -13)
T.Refresh('HuntersFieldGuide')
local point, relative, relativePoint, x, y = target:GetPoint(1)
assert(point == 'CENTER' and relative == window and relativePoint == 'CENTER' and x == 21 and y == -13,
    'target-panel drag position changed during border refresh')
target:Show(); target:GetScript('OnMouseUp')(target)
assert(target.dismissed and not target:IsShown(), 'target-panel dismissal was changed')
local notificationOwner = toast
for _, kind in ipairs({'seen', 'studied', 'tamed'}) do
    guide.Toast(kind); assert(toast == notificationOwner); toast:Hide()
end
guide.ToastNotice(); assert(toast == notificationOwner and toast.kind == 'notice'); toast:Hide()
toast:Show(); toast.expired = true; toast:GetScript('OnUpdate')(toast)
assert(not toast:IsShown(), 'notification timing or disappearance was changed')
toast.expired = nil; toast:Show(); toast:GetScript('OnMouseUp')(toast)
assert(toast.dismissed and not toast:IsShown(), 'notification dismissal was changed')
guide.MovePopups(true)
assert(target:GetFrameStrata() == 'FULLSCREEN_DIALOG' and toast:GetFrameStrata() == 'FULLSCREEN_DIALOG',
    'settings placement mode strata changed')
guide.MovePopups(false)

guide.RefreshUI(); guide.ShowExport(); guide.ShowTargetPanel()
assert(calls.RefreshUI == 1 and calls.ShowExport == 1 and calls.ShowTargetPanel == 1 and #T.timers > 0,
    'a hook replaced the original or queued nothing')
T.Flush()
local counts = {#window.regions, #window.children}
T.Refresh('HuntersFieldGuide'); T.Refresh('HuntersFieldGuide')
assert(#window.regions == counts[1] and #window.children == counts[2]
    and applied[target].calls == 1 and applied[toast].calls == 1,
    'warm pass created UI objects or duplicate panel borders')

-- The addon not loaded: nothing installs.
local T2 = dofile('tests/support.lua')
_G.HuntersFieldGuide = nil
T2.Load('Skins/HuntersFieldGuide.lua')
local stray = T2.Frame('Frame', nil, 'FieldGuideFrame')
T2.Install('HuntersFieldGuide')
assert(not stray.skin.Shell and not T2.Module('HuntersFieldGuide').active, "installed without Hunter's Field Guide")

-- A clean session with this individual skin switched off leaves both the native panel and its
-- edge untouched. The enabled case above represents the corresponding clean-session enable path.
local T3 = dofile('tests/support.lua')
EUIAdditionalSkinningDB = {skins = {HuntersFieldGuide = false}}
local disabledBorders = 0
EllesmereUI.ApplyBorderStyle = function() disabledBorders = disabledBorders + 1 end
_G.HuntersFieldGuide = {}
local ns3 = T3.Load('Skins/HuntersFieldGuide.lua')
local disabled = T3.Frame('Frame', nil, 'FieldGuideTargetPanel')
disabled.TopEdge = T3.Texture(disabled, 'BORDER')
local entry3 = T3.Entry('HuntersFieldGuide')
T3.loaded.HuntersFieldGuide = true; T3.Fire('ADDON_LOADED', 'HuntersFieldGuide')
assert(T3.registered[T3.PREFIX .. entry3.label], 'disabled skin was not registered with EllesmereUI')
T3.registered[T3.PREFIX .. entry3.label](T3.S); T3.Flush()
assert(#ns3.modules == 0 and disabledBorders == 0 and disabled.TopEdge:GetAlpha() == 1,
    'switched-off Hunter\'s Field Guide skin changed a panel')
print("PASS: Hunter's Field Guide shells, dark target/toast panels, configured borders, preserved lifecycle, notification reuse, portrait, controls, hooks, idempotence and gates")
