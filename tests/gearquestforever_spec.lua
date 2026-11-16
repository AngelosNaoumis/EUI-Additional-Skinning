-- GearQuest Forever: window/dialog shells; contained portrait + guide hit target; full button intro washes; aligned native side tabs with actions/tooltips preserved; readable parchment text; flat panel edges; controls; idempotence and gates.
local T = dofile('tests/support.lua')
local ns = T.Load('Skins/GearQuestForever.lua')
local METAL = 'Interface\\Tooltips\\UI-Tooltip-Border'

-- GearQuest's namespace (_G.GearQuest): the log builds and redraws the window; Preview the dialog.
local calls = {}
local function Method(name) return function() calls[name] = (calls[name] or 0) + 1 end end
_G.GearQuest = {Log = {Init = Method('Init'), Show = Method('Show'), Refresh = Method('Refresh'), Toggle = Method('Toggle'),
    }, Preview = {EnsureDialog = Method('EnsureDialog')}}

-- GearQuestLogFrame (PortraitFrameTemplate), as Log:Init builds it.
UIParent = T.Frame('Frame', nil, 'UIParent')
local window = T.Frame('Frame', nil, 'GearQuestLogFrame')
window.CloseButton = T.Frame('Button', window); window.CloseButton.width, window.CloseButton.height = 32, 32
window.PortraitContainer = T.Frame('Frame', window)
window.PortraitContainer:SetPoint('TOPLEFT', window, 'TOPLEFT', -6, 7)
local guideHit = T.Frame('Button', window)
guideHit:SetPoint('TOPLEFT', window, 'TOPLEFT', -6, 7)
local guideClicks = 0
local guideClick, guideEnter, guideLeave = function() guideClicks = guideClicks + 1 end, function() end, function() end
guideHit:SetScript('OnClick', guideClick); guideHit:SetScript('OnEnter', guideEnter); guideHit:SetScript('OnLeave', guideLeave)
local guideBubble = T.Frame('Frame', UIParent)
guideBubble._blX, guideBubble._blY = 100, 200
guideBubble:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', 100, 200)
_G.GearQuest.PortraitGuide = {
    hit = guideHit, bubble = guideBubble, Begin = Method('Begin'), Open = Method('Open'),
}
_G.GearQuest.Log.frame = window
window.listInset = T.Frame('Frame', window); window.listInset.backdrop = {edgeFile = METAL, edgeSize = 12}
window.detailBg = T.Frame('Frame', window); window.detailBg.backdrop = {edgeFile = METAL, edgeSize = 12}
window.detailBg.gqParchment = T.Texture(window.detailBg, 'BACKGROUND')
local lore = T.FontString(window.detailBg, 'Kill boars'); lore:SetTextColor(0, 0, 0)
local epic = T.FontString(window.detailBg, 'Epic sword'); epic:SetTextColor(0.64, 0.21, 0.93)
local track = T.Frame('Button', window, 'GearQuestLogTrackButton'); track.label = T.FontString(track, 'Track')
local trackClicks = 0
local trackClick, trackEnter, trackLeave = function() trackClicks = trackClicks + 1 end, function() end, function() end
track:SetScript('OnClick', trackClick); track:SetScript('OnEnter', trackEnter); track:SetScript('OnLeave', trackLeave)
track.introWash = T.Texture(track, 'OVERLAY')
track.introWash:SetPoint('TOPLEFT', track, 'TOPLEFT', 5, -4)
track.introWash:SetPoint('BOTTOMRIGHT', track, 'BOTTOMRIGHT', -5, 4)
window.trackBtn = track
local play = T.Frame('Button', window, 'GearQuestPlayStyleButton'); play.label = T.FontString(play, 'Play style')
local playClicks = 0
local playClick = function() playClicks = playClicks + 1 end
play:SetScript('OnClick', playClick)
play.introWash = T.Texture(play, 'OVERLAY')
play.introWash:SetPoint('TOPLEFT', play, 'TOPLEFT', 5, -4)
play.introWash:SetPoint('BOTTOMRIGHT', play, 'BOTTOMRIGHT', -5, 4)
window.playStyleBtn = play
local row = T.Frame('Button', window, 'GearQuestLogRow1'); row.label = T.FontString(row, 'Wolf Pelt')
local tab = T.Frame('Button', window); tab.label = T.FontString(tab, 'Hunts'); tab.gqFill = T.Texture(tab, 'BACKGROUND')
local menu = T.Frame('Frame', window, 'GearQuestSourceFilterMenu')
menu.backdrop = {bgFile = 'Interface/Tooltips/UI-Tooltip-Background', edgeFile = METAL, edgeSize = 16}
local scale = T.Frame('Slider', window, 'GearQuestWindowScaleSlider'); scale.width, scale.height = 160, 17
local thumb = T.Texture(scale, 'OVERLAY'); thumb.width, thumb.height = 32, 32
function scale:GetThumbTexture() return thumb end
function scale:GetOrientation() return 'HORIZONTAL' end
window.gqOuterBorder = T.Frame('Frame', window); window.gqOuterBorder.backdrop = {edgeFile = METAL, edgeSize = 16}
window.sideTabRail = T.Frame('Frame')
local page = 'log'
local sideClicks, sideEnters, sideLeaves = {}, {}, {}
for _, key in ipairs({'tabLog', 'tabLookup', 'tabSimulator', 'tabSettings'}) do
    local button = T.Frame('Button', window.sideTabRail)
    sideClicks[key], sideEnters[key], sideLeaves[key] = function() end, function() end, function() end
    button:SetScript('OnClick', sideClicks[key]); button:SetScript('OnEnter', sideEnters[key]); button:SetScript('OnLeave', sideLeaves[key])
    window[key] = button
end
local sideKeys = {'tabLog', 'tabLookup', 'tabSimulator', 'tabSettings'}
local sidePages = {'log', 'lookup', 'simulator', 'settings'}
local function NativeLayoutSideTabs()
    calls.LayoutSideTabs = (calls.LayoutSideTabs or 0) + 1
    window.sideTabRail:ClearAllPoints()
    window.sideTabRail:SetPoint('TOPLEFT', window, 'TOPRIGHT', -8, -123)
    window.sideTabRail:SetSize(53, 242)
    for index, key in ipairs(sideKeys) do
        local button = window[key]
        button:ClearAllPoints()
        button:SetPoint('TOPLEFT', window.sideTabRail, 'TOPLEFT', 0, -(index - 1) * 63)
        button:SetSize(53, 53)
        button.nativeSelected = page == sidePages[index]
    end
end
function _G.GearQuest.Log:SetPageTab(nextPage)
    calls.SetPageTab = (calls.SetPageTab or 0) + 1
    page = nextPage
    NativeLayoutSideTabs()
end
NativeLayoutSideTabs()
local dialog = T.Frame('Frame', nil, 'GearQuestSimulateDialog')
dialog.backdrop = {bgFile = 'Interface/DialogFrame/UI-DialogBox-Background'}

T.Install('GearQuestForever')
assert(window.skin.Shell and dialog.skin.Shell, 'log window or simulate dialog not shelled')
local point, relative, relativePoint, x, y = window.PortraitContainer:GetPoint(1)
assert(point == 'TOPLEFT' and relative == window and relativePoint == 'TOPLEFT' and x == 8 and y == -8,
    'portrait container not placed wholly inside the window')
point, relative, relativePoint, x, y = guideHit:GetPoint(1)
guideHit:GetScript('OnClick')(guideHit)
assert(x == 8 and y == -8 and guideClicks == 1 and guideHit:GetScript('OnEnter') == guideEnter
    and guideHit:GetScript('OnLeave') == guideLeave,
    'portrait guide hit target not aligned, or its action/tooltip changed')
local _, bubbleRelative, _, bubbleX, bubbleY = guideBubble:GetPoint(1)
assert(bubbleRelative == UIParent and bubbleX == 114 and bubbleY == 185,
    'portrait guide bubble tail did not follow the contained portrait')
guideBubble:ClearAllPoints(); guideBubble:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', 100, 200)
_G.GearQuest.PortraitGuide:Begin(window)
_, bubbleRelative, _, bubbleX, bubbleY = guideBubble:GetPoint(1)
assert(bubbleRelative == UIParent and bubbleX == 114 and bubbleY == 185,
    'native guide open did not correct the bubble tail')
guideBubble:ClearAllPoints(); guideBubble:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', 100, 200)
window:GetScript('OnDragStop')(window)
_, bubbleRelative, _, bubbleX, bubbleY = guideBubble:GetPoint(1)
assert(bubbleRelative == UIParent and bubbleX == 114 and bubbleY == 185,
    'window drag stop did not correct the bubble tail')
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
assert(track.skin.Button and play.skin.Button, 'animated action button not styled')
for _, button in ipairs({track, play}) do
    local wash = button.introWash
    assert(#wash.points == 2 and wash.points[1][4] == 2 and wash.points[1][5] == -2
        and wash.points[2][4] == -2 and wash.points[2][5] == 2,
        'intro animation does not cover the full button interior')
end
track:GetScript('OnClick')(track); play:GetScript('OnClick')(play)
assert(trackClicks == 1 and playClicks == 1 and track:GetScript('OnEnter') == trackEnter
    and track:GetScript('OnLeave') == trackLeave,
    'animated button actions or tooltip scripts changed')
point, relative, relativePoint, x, y = window.sideTabRail:GetPoint(1)
assert(point == 'TOPLEFT' and relative == window and relativePoint == 'TOPRIGHT' and x == -8 and y == -123
    and window.sideTabRail:GetWidth() == 53 and window.sideTabRail:GetHeight() == 242,
    'skin changed GearQuest-owned right-side tab rail geometry')
for index, key in ipairs({'tabLog', 'tabLookup', 'tabSimulator', 'tabSettings'}) do
    local button = window[key]
    local _, buttonRelative, _, buttonX, buttonY = button:GetPoint(1)
    assert(buttonRelative == window.sideTabRail and buttonX == 0 and buttonY == -(index - 1) * 63
        and button:GetWidth() == 53 and button:GetHeight() == 53,
        'skin changed GearQuest-owned right-side tab geometry')
    assert(button:GetScript('OnClick') == sideClicks[key] and button:GetScript('OnEnter') == sideEnters[key]
        and button:GetScript('OnLeave') == sideLeaves[key],
        'right-side tab action or tooltip script changed')
    assert(not button.skin.Button and not button.skin.SquareIcon, 'right-side tab received duplicate EUI artwork')
end

-- Page navigation re-runs GearQuest's layout and selected-state styling. The skin must not queue a
-- SetPageTab pass or restore competing coordinates after that native lifecycle finishes.
local navigationTimers = #T.timers
for round = 1, 3 do
    for _, nextPage in ipairs({'lookup', 'simulator', 'settings', 'log'}) do
        _G.GearQuest.Log:SetPageTab(nextPage)
        if round == 1 and nextPage == 'lookup' then
            assert(#T.timers == navigationTimers, 'SetPageTab queued a redundant skin refresh')
        end
        T.Flush()
        T.Refresh('GearQuestForever')
        local _, railRelative, _, railX, railY = window.sideTabRail:GetPoint(1)
        assert(railRelative == window and railX == -8 and railY == -123
            and window.sideTabRail:GetWidth() == 53 and window.sideTabRail:GetHeight() == 242,
            'right-side tab rail moved or resized during repeated navigation')
        for index, key in ipairs(sideKeys) do
            local button = window[key]
            local _, buttonRelative, _, buttonX, buttonY = button:GetPoint(1)
            assert(buttonRelative == window.sideTabRail and buttonX == 0 and buttonY == -(index - 1) * 63
                and button:GetWidth() == 53 and button:GetHeight() == 53,
                'right-side tab moved or resized during repeated navigation')
            assert(button.nativeSelected == (sidePages[index] == nextPage),
                'native selected-state update was not preserved')
            assert(button:GetScript('OnClick') == sideClicks[key]
                and button:GetScript('OnEnter') == sideEnters[key]
                and button:GetScript('OnLeave') == sideLeaves[key],
                'right-side tab handler changed during repeated navigation')
        end
    end
end
assert(calls.LayoutSideTabs == 13 and calls.SetPageTab == 12,
    'repeated navigation did not exercise every native layout pass')
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
print('PASS: GearQuest Forever shells, contained portrait/guide hit target, full intro washes, aligned native side tabs with handlers/tooltips preserved, readable text, flat edges, controls, post-hooks, idempotence and gates')
