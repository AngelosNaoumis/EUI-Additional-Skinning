-- Hunter's Field Guide: the journal and export window shelled (the spellbook page art goes with the shell); its X a close button only; spellbook ink made readable with its hue (gold and white text kept); the header backplate faded; beast entries, icon tabs and the home button left as drawn; icon slots and the filter menu a flat edge; buttons and the search box styled; its methods post-hooked; warm passes create nothing; nothing without the addon.
local T = dofile('tests/support.lua')
local ns = T.Load('Skins/HuntersFieldGuide.lua')

local calls = {}
local guide = {}
for _, name in ipairs({'CreateUI', 'RefreshUI', 'ToggleUI', 'ShowExport'}) do
    guide[name] = function() calls[name] = (calls[name] or 0) + 1 end
end
_G.HuntersFieldGuide = guide

-- FieldGuideFrame (PortraitFrameTemplate, the "Forever spellbook" look), as PD:CreateUI builds it.
local window = T.Frame('Frame', nil, 'FieldGuideFrame')
local page = T.Texture(window, 'BACKGROUND'); page.atlas = 'spellbook-Page-Right-C60'
window.CloseButton = T.Frame('Button', window)
window.header = T.Frame('Frame', window); window.header.text = T.FontString(window.header, 'Wolves')
local plate = T.Texture(window.header, 'BACKGROUND'); plate.atlas = 'spellbook-list-backplate'
local divider = T.Texture(window.header, 'ARTWORK'); divider.atlas = 'spellbook-divider'
window.header.text:SetTextColor(0.2, 0.12, 0.05) -- SPELLBOOK_FONT_COLOR ink
local good = T.FontString(window, 'Tameable'); good:SetTextColor(0.04, 0.34, 0.04)
local gold = T.FontString(window, 'Gold name'); gold:SetTextColor(1, 0.82, 0)
window.home = T.Frame('Button', window)
local entry = T.Frame('Button', window); entry.backplate = T.Texture(entry, 'BACKGROUND'); entry.icon = T.Texture(entry, 'ARTWORK')
local tab = T.Frame('Button', window); tab.active = T.Texture(tab, 'ARTWORK')
local back = T.Frame('Button', window); back.label = T.FontString(back, 'Back')
local search = T.Frame('EditBox', window, 'FieldGuideSearch')
local slot = T.Frame('Frame', window); slot.backdrop = {bgFile = 'Interface\\Buttons\\WHITE8x8', edgeFile = 'Interface\\Buttons\\WHITE8x8', edgeSize = 2}
local export = T.Frame('Frame', nil, 'FieldGuideExport')
export.CloseButton = nil

T.Install('HuntersFieldGuide')
assert(window.skin.Shell and export.skin.Shell, 'journal or export window not shelled')
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

guide.RefreshUI(); guide.ShowExport()
assert(calls.RefreshUI == 1 and calls.ShowExport == 1 and #T.timers > 0, 'a hook replaced the original or queued nothing')
T.Flush()
local counts = {#window.regions, #window.children}
T.Refresh('HuntersFieldGuide'); T.Refresh('HuntersFieldGuide')
assert(#window.regions == counts[1] and #window.children == counts[2], 'warm pass created UI objects')

-- The addon not loaded: nothing installs.
local T2 = dofile('tests/support.lua')
_G.HuntersFieldGuide = nil
T2.Load('Skins/HuntersFieldGuide.lua')
local stray = T2.Frame('Frame', nil, 'FieldGuideFrame')
T2.Install('HuntersFieldGuide')
assert(not stray.skin.Shell and not T2.Module('HuntersFieldGuide').active, "installed without Hunter's Field Guide")
print("PASS: Hunter's Field Guide journal and export shells, close button, spellbook ink lifted with its hue (gold kept), header backplate faded, entries, tabs and home left as drawn, slots and menus flat, buttons and search, post-hooks, warm passes, missing addon")
