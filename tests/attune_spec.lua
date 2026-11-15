-- Attune: main window shelled (no footer band), portrait left of the list/grid toggle, no status box, our own border frames never painted, the chrome's NineSlice never painted as a panel, graph nodes get a 1px backdrop, tree rows a selection fill and +/- glyph, the graph canvas untouched, Attune's own functions queue a refresh, combat defers, warm passes create nothing.
local T = dofile('tests/support.lua')
local ns = T.Load('Skins/Attune.lua')

Attune = {}
local updates = 0
Attune_UpdateTreeGroup = function() updates = updates + 1 end
local main = T.Frame('Frame', nil, 'Attune_MainFrame')
-- The bronze chrome: a see-through PortraitFrameTemplate one level above the window.
local chrome = T.Frame('Frame', main, 'AttuneBronzeChrome')
chrome.PortraitContainer = T.Frame('Frame', chrome); chrome.PortraitContainer.portrait = T.Texture(chrome.PortraitContainer, 'ARTWORK')
chrome.PortraitContainer.portrait.path = 'attune-portrait'
-- Its NineSlice covers the window at level 517 and reports a backdrop with a bgFile, as in game.
chrome.NineSlice = T.Frame('Frame', chrome); chrome.Bg = T.Texture(chrome, 'BACKGROUND')
chrome.NineSlice.level = 517; chrome.NineSlice.backdrop = {bgFile = 'Interface/Tooltips/UI-Tooltip-Background'}
-- Zoom: a horizontal slider whose native thumb is 32x32.
local zoom = T.Frame('Slider', main); zoom.width, zoom.height = 160, 17
local thumb = T.Texture(zoom, 'OVERLAY'); thumb.width, thumb.height = 32, 32
function zoom:GetThumbTexture() return thumb end
function zoom:GetOrientation() return 'HORIZONTAL' end
local node = T.Frame('Frame', main, 'Attune_Node_1')
node.backdrop = {bgFile = 'Interface/Tooltips/UI-Tooltip-Background', edgeFile = 'Interface/Tooltips/UI-Tooltip-Border', edgeSize = 16}
T.FontString(node, 'Molten Core')
local row = T.Frame('Button', main); row.treeline = true; row.selected = true
row.text = T.FontString(row, 'Attunements')
row.toggle = T.Frame('Button', row); row.toggle.normal = T.Texture(row.toggle); row.toggle.normal.path = 'Interface/Buttons/UI-MinusButton-Up'
-- The graph canvas and its lines are never painted.
local map = T.Frame('Frame', main); main.map = map
local line = T.Texture(map, 'ARTWORK')

-- The AceGUI window widget: its status line sits in a backdrop box (statusbg) at the bottom.
local statusbg = T.Frame('Button', main); statusbg:SetBackdropColor(0.1, 0.1, 0.1)
local widget = {frame = main, statustext = T.FontString(statusbg, 'Attune v16001-41')}; main.obj = widget
-- Attune's list/grid view toggle (40x16) above the content pane; the gap left of it is the portrait's.
widget.attuneViewToggle = T.Frame('Frame', main)

-- Our EllesmereUI window border on the shelled window: a host above the content whose textured
-- edge is a backdrop frame (bgFile) at level 517, as /eas probe found. It must never be painted.
local borderHost = T.Frame('Frame', main); borderHost.level = 516; ns.OwnFrames[borderHost] = true
local edge = T.Frame('Frame', borderHost); edge.level = 517; edge.width, edge.height = 1217, 737
edge.backdrop = {bgFile = 'Interface/Buttons/WHITE8X8', edgeFile = 'Interface/AddOns/EllesmereUI/media/border.tga'}

T.Install('Attune')
assert(not edge.skin.Panel and not borderHost.skin.Panel and edge.backdrop.edgeFile,
    'our window border painted as a panel over the whole window (the dark overlay)')
assert(main.skin.Shell and not (type(main.skin.Shell) == 'table' and main.skin.Shell.bottomBar), 'main window shelled with a dark footer band')
assert(not chrome.skin.Shell, 'the see-through chrome got a second background')
assert(chrome.Bg.alpha == 0, 'chrome background art not faded')
local portrait
for _, r in ipairs(chrome.regions) do if r.path == 'attune-portrait' and r ~= chrome.PortraitContainer.portrait then portrait = r end end
local at = portrait and portrait.points[#portrait.points]
assert(portrait and portrait.width == 16 and #portrait.points == 1 and at[1] == 'RIGHT' and at[2] == widget.attuneViewToggle
    and at[3] == 'LEFT' and at[4] == -12 and at[5] == 0, 'portrait not anchored left of the list/grid toggle')
assert(not statusbg.skin.Panel and select(4, statusbg:GetBackdropColor()) == 0 and statusbg.backdropBorder[4] == 0,
    'status line still has a dark box along the bottom')
assert(not chrome.NineSlice.skin.Panel, 'chrome border art painted as a panel over the whole window (the dark overlay)')
assert(thumb.width == 8 and thumb.height == 14, 'zoom slider thumb is a block over its labels')
assert(node.backdrop.edgeSize == 1 and node.backdrop.edgeFile == 'Interface/Buttons/WHITE8X8', 'node keeps its thick backdrop')
assert(row.euiSelection and row.euiSelection.color[4] == 0.2, 'selected tree row has no accent fill')
local glyph
for _, r in ipairs(row.toggle.regions) do if r.kind == 'FontString' then glyph = r end end
assert(glyph and glyph.text == '-', 'expanded toggle not drawn as "-"')
assert(line.alpha == 1 and not map.skin.Panel, 'graph canvas was painted')

-- Attune's own redraw functions are post-hooked: they still run and queue a refresh.
Attune_UpdateTreeGroup()
assert(updates == 1 and #T.timers > 0, 'redraw hook missing or replaced the original')
T.Flush()

-- Combat defers the pass; it runs once combat ends.
T.combat = true
node.backdrop = {bgFile = 'x', edgeFile = 'thick', edgeSize = 8}
T.Refresh('Attune')
T.combat = false
T.Fire('PLAYER_REGEN_ENABLED'); T.Flush()

-- Warm passes create nothing new.
local regions, rowRegions = #main.regions, #row.regions
T.Refresh('Attune'); T.Refresh('Attune')
assert(#main.regions == regions and #row.regions == rowRegions, 'warm pass created regions')
print('PASS: Attune window shell, see-through chrome without a second background, compact zoom handle, node backdrops, tree selection and glyphs, untouched graph, post-hooked redraws, combat, warm passes')
