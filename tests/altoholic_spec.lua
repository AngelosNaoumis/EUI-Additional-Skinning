-- Altoholic: main window and message box shelled without title strip or accent bar, a clean X, its tab and redraw methods post-hooked (originals still run), combat defers, warm passes create nothing.
local T = dofile('tests/support.lua')
local ns = T.Load('Skins/Altoholic.lua')

Altoholic = {}
local main = T.Frame('Frame', nil, 'AltoholicFrame')
local calls = {}
for _, method in ipairs({'SwitchToTab', 'SetTabs', 'ToggleUI', 'SetPortraitToUnit'}) do
    main[method] = function() calls[method] = (calls[method] or 0) + 1 end
end
-- Summary's expand/collapse button (AddonFactory_ToggleButtonTemplate): 16x16, its NormalTexture
-- keyed Icon carries the plus/minus art; the controller swaps it with SetNormalTexture.
local summary = T.Frame('Frame', main); main.TabSummary = summary
local toggle = T.Frame('Button', summary); summary.ToggleView = toggle
toggle.width, toggle.height = 16, 16
toggle.normal = T.Texture(toggle, 'ARTWORK'); toggle.normal.path = 130821; toggle.Icon = toggle.normal
function toggle:SetNormalTexture(file) self.normal.path = file end
-- The window's X: 28x28, its NormalTexture an atlas that reads back as a file ID.
local close = T.Frame('Button', main, 'AltoholicFrameCloseButton'); main.CloseButton = close
close.width, close.height = 28, 28
close.normal = T.Texture(close, 'ARTWORK'); close.normal.path = 4169; close.normal.width, close.normal.height = 28, 28
local box = T.Frame('Frame', nil, 'AltoMessageBox')
local ok = T.Frame('Button', box); ok.label = T.FontString(ok, 'OK')

T.Install('Altoholic')
for _, f in ipairs({main, box}) do
    assert(f.skin.Shell and f.skin.Shell.noTopBar and f.skin.Shell.noAccent, 'root not shelled without title strip and accent')
    for _, r in ipairs(f.regions) do assert(r.height ~= 2, 'accent bar attached despite noAccent') end
end
assert(ok.skin.Button, 'message box button not styled')
assert(close.skin.CloseButton and not close.skin.Button and not close.normal.skin, 'close button boxed as a toolbar icon')
local function Glyph(f) for _, r in ipairs(f.regions) do if r.kind == 'FontString' then return r end end end
assert(not toggle.Icon.skin or not toggle.Icon.skin.SquareIcon, 'expand button art kept as a cropped icon')
assert(toggle.Icon.alpha == 0 and Glyph(toggle) and Glyph(toggle).text == '-', 'expanded toggle not drawn as a flat "-" button')
toggle.isCollapsed = true; toggle:SetNormalTexture('Interface\\Buttons\\UI-PlusButton-Up'); T.Flush()
assert(Glyph(toggle).text == '+' and toggle.Icon.alpha == 0, 'collapsed toggle not drawn as "+"')
toggle.isCollapsed = nil; toggle:SetNormalTexture('Interface\\Buttons\\UI-MinusButton-Up'); T.Flush()
assert(Glyph(toggle).text == '-', 'toggle did not follow back to expanded')

-- Its methods are post-hooked: originals still run, the skin repaints.
main:SwitchToTab(1); main:ToggleUI()
assert(calls.SwitchToTab == 1 and calls.ToggleUI == 1, 'hook replaced an original method')
assert(#T.timers > 0, 'ToggleUI queued no refresh')
T.Flush()

-- Combat defers: a refresh in combat touches nothing until it ends.
T.combat = true
local late = T.Frame('Button', box); late.label = T.FontString(late, 'Later')
T.Refresh('Altoholic')
assert(not late.skin.Button, 'styled in combat')
T.combat = false
T.Fire('PLAYER_REGEN_ENABLED'); T.Flush()
assert(late.skin.Button, 'deferred pass did not run after combat')

local regions = #main.regions + #box.regions
T.Refresh('Altoholic'); T.Refresh('Altoholic')
assert(#main.regions + #box.regions == regions, 'warm pass created regions')
print('PASS: Altoholic shells (no title strip, no accent), post-hooked methods, flat expand/collapse toggle in both states, combat deferral, warm passes')
