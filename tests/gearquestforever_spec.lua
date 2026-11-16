-- GearQuest Forever: the log window and simulate dialog shelled; its X a close button only; the parchment faded and black detail text made readable (rarity colours kept); metal-edged panels a 1px grey edge with no added fill; the fallback window border dropped; menus a flat edge; hunt rows and tabs left as drawn; buttons and horizontal sliders styled; its methods post-hooked; warm passes create nothing; nothing without GearQuest or with its EUI toggle off.
local T = dofile('tests/support.lua')
local ns = T.Load('Skins/GearQuestForever.lua')
local METAL = 'Interface\\Tooltips\\UI-Tooltip-Border'

-- GearQuest's namespace (_G.GearQuest): the log builds and redraws the window; Preview the dialog.
local calls = {}
local function Method(name) return function() calls[name] = (calls[name] or 0) + 1 end end
_G.GearQuest = {Log = {Init = Method('Init'), Show = Method('Show'), Refresh = Method('Refresh'), Toggle = Method('Toggle'),
    SetPageTab = Method('SetPageTab')}, Preview = {EnsureDialog = Method('EnsureDialog')}}

-- GearQuestLogFrame (PortraitFrameTemplate), as Log:Init builds it.
local window = T.Frame('Frame', nil, 'GearQuestLogFrame')
window.CloseButton = T.Frame('Button', window); window.CloseButton.width, window.CloseButton.height = 32, 32
window.listInset = T.Frame('Frame', window); window.listInset.backdrop = {edgeFile = METAL, edgeSize = 12}
window.detailBg = T.Frame('Frame', window); window.detailBg.backdrop = {edgeFile = METAL, edgeSize = 12}
window.detailBg.gqParchment = T.Texture(window.detailBg, 'BACKGROUND')
local lore = T.FontString(window.detailBg, 'Kill boars'); lore:SetTextColor(0, 0, 0)
local epic = T.FontString(window.detailBg, 'Epic sword'); epic:SetTextColor(0.64, 0.21, 0.93)
local track = T.Frame('Button', window, 'GearQuestLogTrackButton'); track.label = T.FontString(track, 'Track')
local row = T.Frame('Button', window, 'GearQuestLogRow1'); row.label = T.FontString(row, 'Wolf Pelt')
local tab = T.Frame('Button', window); tab.label = T.FontString(tab, 'Hunts'); tab.gqFill = T.Texture(tab, 'BACKGROUND')
local menu = T.Frame('Frame', window, 'GearQuestSourceFilterMenu')
menu.backdrop = {bgFile = 'Interface/Tooltips/UI-Tooltip-Background', edgeFile = METAL, edgeSize = 16}
local scale = T.Frame('Slider', window, 'GearQuestWindowScaleSlider'); scale.width, scale.height = 160, 17
local thumb = T.Texture(scale, 'OVERLAY'); thumb.width, thumb.height = 32, 32
function scale:GetThumbTexture() return thumb end
function scale:GetOrientation() return 'HORIZONTAL' end
window.gqOuterBorder = T.Frame('Frame', window); window.gqOuterBorder.backdrop = {edgeFile = METAL, edgeSize = 16}
local dialog = T.Frame('Frame', nil, 'GearQuestSimulateDialog')
dialog.backdrop = {bgFile = 'Interface/DialogFrame/UI-DialogBox-Background'}

T.Install('GearQuestForever')
assert(window.skin.Shell and dialog.skin.Shell, 'log window or simulate dialog not shelled')
assert(dialog.backdrop == nil, "the dialog's own backdrop chrome left under the shell")
assert(window.CloseButton.skin.CloseButton and not window.CloseButton.skin.Button, 'X boxed instead of a close button')
assert(window.detailBg.gqParchment.alpha == 0, 'parchment not faded')
assert(lore.textColor[1] == 1 and lore.textColor[2] == 1, 'black detail text left unreadable on the dark shell')
assert(epic.textColor[1] == 0.64 and epic.textColor[3] == 0.93, 'rarity colour changed')
for _, panel in ipairs({window.listInset, window.detailBg}) do
    assert(panel.backdrop and panel.backdrop.edgeSize == 1 and panel.backdrop.bgFile == nil and not panel.skin.Panel,
        'metal edge not a flat edge, or a fill added (it could cover the content)')
end
assert(window.gqOuterBorder.backdrop == nil, 'the fallback window border kept beside the shell')
assert(menu.backdrop.edgeSize == 1 and menu.backdrop.bgFile, 'menu not given a flat edge with its fill')
assert(track.skin.Button, 'action button not styled')
assert(not row.skin.Button and not tab.skin.Button, 'hunt row or tab boxed (their fill shows selection and quality)')
assert(thumb.width == 8 and thumb.height == 14, 'horizontal slider not styled')

-- Its own methods are post-hooked: they still run and queue a pass.
_G.GearQuest.Log.Refresh(); _G.GearQuest.Preview.EnsureDialog()
assert(calls.Refresh == 1 and calls.EnsureDialog == 1 and #T.timers > 0, 'a hook replaced the original or queued nothing')
T.Flush()
-- The dialog re-applies its backdrop each time it opens: removed again on the next pass.
dialog.backdrop = {bgFile = 'Interface/DialogFrame/UI-DialogBox-Background'}
T.Refresh('GearQuestForever')
assert(dialog.backdrop == nil, 're-applied dialog chrome kept')
-- Ink set again by a redraw is lifted again; light text is never rewritten.
lore:SetTextColor(0, 0, 0); T.Refresh('GearQuestForever')
assert(lore.textColor[1] == 1, 'redrawn detail text not lifted')

-- Warm passes create nothing and do not rewrite.
local counts = {#window.regions, #window.children, #window.listInset.regions}
T.Refresh('GearQuestForever'); T.Refresh('GearQuestForever')
assert(#window.regions == counts[1] and #window.children == counts[2] and #window.listInset.regions == counts[3],
    'warm pass created UI objects')

-- GearQuest not loaded: nothing installs, nothing is touched.
local T2 = dofile('tests/support.lua')
_G.GearQuest = nil
T2.Load('Skins/GearQuestForever.lua')
local stray = T2.Frame('Frame', nil, 'GearQuestLogFrame')
T2.Install('GearQuestForever')
assert(not stray.skin.Shell and not T2.Module('GearQuestForever').active, 'installed without GearQuest')

-- Its EUI toggle off: nothing installs.
local T3 = dofile('tests/support.lua')
_G.GearQuest = {Log = {}}
T3.S.IsEnabled = function() return false end
T3.Load('Skins/GearQuestForever.lua')
local other = T3.Frame('Frame', nil, 'GearQuestLogFrame')
T3.loaded.GearQuestForever = true
T3.Fire('ADDON_LOADED', 'GearQuestForever')
T3.registered[T3.PREFIX .. 'GearQuest Forever'](T3.S); T3.Flush()
assert(not other.skin.Shell and #T3.ns.modules == 0, 'installed with its EUI toggle off')
_G.GearQuest = nil
print('PASS: GearQuest Forever window and dialog shells, close button, parchment faded and dark text lifted (rarity kept), flat metal edges without fills, fallback border dropped, menus, rows and tabs left as drawn, buttons and sliders, post-hooks, re-applied chrome removed, warm passes, missing addon, EUI toggle off')
