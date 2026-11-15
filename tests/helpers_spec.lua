-- Shared helpers: Once, Pixel, Shift, Strip (keeps art), Wash, ScrollBar (both generations),
-- Glyph (and its no-atlas fallback), Squared (pooled re-square), Pooled (row restyle), Font skip.
local T = dofile('tests/support.lua')
local ns = T.Load()
local H = ns.CreateSkinHelper(T.S, {skin = T.S})

-- Once: true the first time per frame and key.
local f = T.Frame()
assert(H.Once(f, 'a') and not H.Once(f, 'a') and H.Once(f, 'b'), 'Once')

-- Pixel follows the frame's scale; Shift keeps every anchor and offsets it.
PixelUtil = {GetNearestPixelSize = function(size, scale) return size / scale end}
f.GetEffectiveScale = function() return 2 end
assert(H.Pixel(f) == 0.5, 'Pixel')
f:SetPoint('TOPLEFT', nil, 'TOPLEFT', 10, -5); f:SetPoint('BOTTOMRIGHT', nil, 'BOTTOMRIGHT', -3, 4)
H.Shift(f, 2, 1)
assert(f.points[1][4] == 12 and f.points[1][5] == -4 and f.points[2][4] == -1 and f.points[2][5] == 5, 'Shift')

-- Strip clears the panel but restores its spinner; once per frame.
local inset = T.Frame()
local spinner = T.Texture(inset, 'OVERLAY')
T.S.Inset = function(frame) frame.skin.Inset = (frame.skin.Inset or 0) + 1; spinner:SetAlpha(0) end
H.Strip(inset); H.Strip(inset)
assert(inset.skin.Inset == 1 and spinner.alpha == 1, 'Strip')

-- Wash: one child layer with a 2% fill and 1px top/left seams.
local area = T.Frame()
local layer = H.Wash(area)
assert(H.Wash(area) == layer and #area.children == 1, 'Wash once')
assert(layer.regions[1].color[4] == 0.02 and layer.regions[2].height == 1 and layer.regions[3].width == 1, 'Wash look')

-- ScrollBar: trim bars lose their caps and Background track; classic sliders take the legacy path.
local bar = T.Frame('EventFrame')
local cap = T.Texture(bar)
bar.Background = T.Frame('Frame', bar); local track = T.Texture(bar.Background)
H.ScrollBar(bar)
assert(cap.alpha == 0 and track.alpha == 0 and bar.skin.ScrollBar, 'trim scroll bar')

-- Glyph: native art faded, white refresh icon drawn; without the atlas the button stays native.
local refresh = T.Frame('Button'); local art = T.Texture(refresh)
local glyph = H.Glyph(refresh)
assert(art.alpha == 0 and glyph.atlas == 'UI-RefreshButton' and glyph.desaturated and H.Glyph(refresh) == glyph, 'Glyph')
C_Texture = {GetAtlasInfo = function() return nil end}
local native = T.Frame('Button'); local nativeArt = T.Texture(native)
assert(H.Glyph(native) == nil and nativeArt.alpha == 1 and #native.regions == 1, 'Glyph without atlas')
C_Texture = nil

-- Squared: unmasked, inset, and re-squared when the pooled button is refilled.
local slot = T.Frame('Button'); local icon = T.Texture(slot); icon:AddMaskTexture({})
H.Squared(slot, icon)
assert(#icon.masks == 0 and icon.points[1][2] == 2 and icon.skin.SquareIcon == slot, 'Squared')
icon:AddMaskTexture({}); icon:SetAllPoints(slot); icon:SetTexture('next-item')
assert(#icon.masks == 0 and icon.points[1][2] == 2, 'Squared after refill')

-- Pooled: rows restyled whenever the box refills them.
local box = T.Frame(); local rows = {T.Frame(), T.Frame()}
box.ForEachFrame = function(_, fn) for _, row in ipairs(rows) do fn(row) end end
box.Update = function() end
H.Pooled(box, function(row) row.styled = (row.styled or 0) + 1 end); H.Pooled(box, error)
box:Update()
assert(rows[1].styled == 1 and rows[2].styled == 1, 'Pooled')

-- Font: applied once; a matching font is not rewritten, a new colour is applied.
local label = T.FontString(T.Frame(), 'Label')
H.Font(label); local writes = label.fontWrites
H.Font(label); assert(label.fontWrites == writes, 'Font rewrote a matching font')
H.Font(label, 1, 0.82, 0); assert(label.textColor[2] == 0.82, 'Font colour not applied')
-- Ace: AceGUI dropdown and checkbox widgets; plain frames are not claimed.
local dropFrame = T.Frame('Frame'); local drop = T.Frame('Button', dropFrame); local arrow = T.Frame('Button', dropFrame)
local arrowArt = T.Texture(arrow)
dropFrame.obj = {type = 'Dropdown', frame = dropFrame, dropdown = drop, button = arrow}
assert(H.Ace(dropFrame) and drop.skin.Dropdown and arrowArt.alpha == 0, 'Ace dropdown')
local boxFrame = T.Frame('Frame')
local checkWidget = {type = 'CheckBox', frame = boxFrame, checkbg = T.Texture(boxFrame), check = T.Texture(boxFrame),
    text = T.FontString(boxFrame, 'Option'), SetType = function() end, SetDisabled = function() end}
boxFrame.obj = checkWidget
local refreshed = 0
assert(H.Ace(boxFrame, function() refreshed = refreshed + 1 end), 'Ace checkbox')
assert(checkWidget.checkbg.color[1] == 0.02 and checkWidget.check.vertex[1] == T.accent[1] and checkWidget.text.font == 'eui')
local edges = #boxFrame.regions
H.Ace(boxFrame); assert(#boxFrame.regions == edges and edges == 7, 'checkbox edges added once')
checkWidget.disabled = true; H.Ace(boxFrame); assert(checkWidget.check.vertex[1] == 0.5, 'disabled check is grey')
checkWidget:SetDisabled(true); assert(refreshed == 1, 'SetDisabled does not refresh')
assert(not H.Ace(T.Frame()), 'plain frame claimed')
print('PASS: Once, Pixel, Shift, Strip, Wash, ScrollBar, Glyph and its fallback, Squared refills, Pooled rows, Font skip, Ace dropdown/checkbox')
