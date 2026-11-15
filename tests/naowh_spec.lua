-- Naowh Forever integration: dormant until NaowhForever's ADDON_LOADED, then wraps its shared factories in place (theme repaint, EUI font, buttons, borders); honours imported settings (useFont off); still activates when Naowh loaded first; stays inert with its row off; no old-addon guard or import; the options page covers every setting.
local function Naowh()
    local calls = {border = 0, button = 0}
    local ns = {THEME = {bg = {r = 0, g = 0, b = 0}, accent = {r = 0, g = 0, b = 0}, accentSoft = {r = 0, g = 0, b = 0},
        line = {r = 0.2, g = 0.2, b = 0.2}, fg = {r = 1, g = 1, b = 1}, panel = {r = 0, g = 0, b = 0},
        muted = {r = 0, g = 0, b = 0}, grey = {r = 0, g = 0, b = 0}}, skin = 'naowh', calls = calls}
    function ns.ApplyThemeColors() end
    function ns.UIFontPath() return 'naowh-font' end
    function ns.Color(token, text) return token, text end
    function ns.Border(frame, color) calls.border = calls.border + 1; return {_frame = {SetAlpha = function() end}, SetColor = function() end} end
    function ns.Button() calls.button = calls.button + 1; return {} end
    ns.Shared = {Style = {BORDER_RGB = {r = 0, g = 0, b = 0}}}
    return ns
end

local function Setup(T)
    EllesmereUI.DARK_BG = {r = 0.05, g = 0.05, b = 0.05}
    EllesmereUI.GetFontPath = function() return 'eui-font' end
    EllesmereUI.ResolveActiveAccent = function() return 0.1, 0.8, 0.6 end
    EllesmereUI.Widgets = nil
end

-- 1. Load order: nothing until NaowhForever's own ADDON_LOADED, then everything at once.
local T = dofile('tests/support.lua'); Setup(T)
local A = T.Load()
T.Fire('ADDON_LOADED', T.ADDON)
local original = Naowh()
NaowhForever = original
local border, font, button = original.Border, original.UIFontPath, original.Button
assert(original.Border == border, 'wrapped before Naowh Forever finished loading')
T.loaded.NaowhForever = true
T.Fire('ADDON_LOADED', 'NaowhForever')
assert(original.Border ~= border and original.UIFontPath ~= font and original.Button ~= button, 'factories not wrapped at Naowh load')
assert(original.UIFontPath() == 'eui-font', 'EUI font not handed to Naowh')
original.ApplyThemeColors()
assert(math.abs(original.THEME.accent.g - 0.8) < 1e-6, 'theme not repainted with the EUI accent')
original.Border(T.Frame('Frame'), original.THEME.line)
assert(original.calls.border == 1, 'wrapped Border did not call through')
assert(T.ns.skinCatalogByID.NaowhForever.active(), 'integration not reported active')
-- The GCD watcher listens to the player's casts only (the client filters other units out).
local gcd = T.Frame('Frame', nil, 'NaowhForeverGcdTracker')
T.Fire('PLAYER_LOGIN'); T.Flush()
local unit
for _, f in ipairs(T.events) do if f.registered.UNIT_SPELLCAST_SUCCEEDED then unit = f.registered.UNIT_SPELLCAST_SUCCEEDED end end
assert(unit == 'player', 'GCD watcher not filtered to the player: ' .. tostring(unit))

-- 2. Saved settings: useFont off leaves Naowh's own font; Naowh loaded before this addon still activates.
T = dofile('tests/support.lua'); Setup(T)
EUIAdditionalSkinningDB = {naowh = {useFont = false, edgeSize = 4}}
original = Naowh(); NaowhForever = original; font = original.UIFontPath
T.loaded.NaowhForever = true
A = T.Load()
T.Fire('ADDON_LOADED', T.ADDON)
assert(original.Border ~= border and original.UIFontPath == font, 'useFont = false not honoured, or not activated when Naowh loaded first')
assert(EUIAdditionalSkinningDB.naowh.edgeSize == 4 and EUIAdditionalSkinningDB.naowh.useFont == false, 'saved values changed on load')

-- 3. With the Naowh row off: inert.
for _, case in ipairs({'switch'}) do
    T = dofile('tests/support.lua'); Setup(T)
    EUIAdditionalSkinningDB = {skins = {NaowhForever = false}}
    original = Naowh(); NaowhForever = original; border = original.Border
    A = T.Load()
    T.Fire('ADDON_LOADED', T.ADDON)
    T.loaded.NaowhForever = true
    T.Fire('ADDON_LOADED', 'NaowhForever')
    assert(original.Border == border, case .. ': Naowh factories wrapped although inactive')
    T.Fire('PLAYER_LOGIN')
    assert(not T.ns.skinCatalogByID.NaowhForever.active(), case .. ': reported active')
end

-- 4. Another Naowh skin addon loaded changes nothing (no guard) and nothing is imported from it.
T = dofile('tests/support.lua'); Setup(T)
EUIAdditionalSkinningDB = nil
OtherNaowhSkinDB = {useFont = false}
original = Naowh(); NaowhForever = original; border = original.Border
A = T.Load()
T.Fire('ADDON_LOADED', T.ADDON)
T.loaded.OtherNaowhSkin = true
T.loaded.NaowhForever = true
T.Fire('ADDON_LOADED', 'NaowhForever')
T.Fire('PLAYER_LOGIN')
assert(original.Border ~= border and A.Naowh.Config:Get().useFont == true and EUIAdditionalSkinningDB.imported == nil,
    'another Naowh skin addon deactivated the integration, or its settings were imported')

-- 5. Every setting has a control: Naowh's look and components on its own page, the border
-- settings (copy or manual style, Naowh's border switches) on the Skins page.
T = dofile('tests/support.lua'); Setup(T)
local pages, rows = {}, {}
EllesmereUI.RegisterPlugin = function(_, spec) pages = spec.modules end
EllesmereUI.Widgets = {SectionHeader = function() return nil, 30 end, Spacer = function() return nil, 10 end,
    DualRow = function(_, _, _, left, right) rows[#rows + 1] = left; rows[#rows + 1] = right; return nil, 40 end}
A = T.Load()
local function BuildPage(key)
    local found
    for _, module in ipairs(pages) do if module.key == key then found = module end end
    assert(found, 'no page ' .. key)
    rows = {}
    found.buildPage(found.pages[1], {}, -10)
    local byText = {}
    for _, row in ipairs(rows) do if row.text then byText[row.text] = row end end
    return byText, found
end
local naowhTexts, page = BuildPage('NaowhForever')
local skinTexts = BuildPage('Skins')
local texts = {}
for text, row in pairs(naowhTexts) do texts[text] = row end
for text, row in pairs(skinTexts) do texts[text] = row end
local config = A.Naowh.Config
for _, key in ipairs(config.FEATURE_KEYS) do
    local found
    for _, row in pairs(texts) do
        if row.getValue and row.type == 'toggle' then
            local before = config:Get()[key]
            config:Get()[key] = not before
            if row.getValue() ~= (not before) then config:Get()[key] = before else found = true; config:Get()[key] = before end
        end
        if found then break end
    end
    assert(found, 'no toggle for ' .. key)
end
local BORDER_ROWS = {'Enable custom borders', 'Copy Main Action Bar 1 border', 'Divider strength', 'Button-border strength',
    'Border Style', 'Shift X', 'Shift Y', 'Border Color', 'Class Color', 'Show Behind'}
for _, text in ipairs(BORDER_ROWS) do
    assert(skinTexts[text], 'border control not on the Skins page: ' .. text)
    assert(not naowhTexts[text], 'border control still on the Naowh page: ' .. text)
end
for _, text in ipairs({'Use EllesmereUI font', 'Naowh window borders', 'Enable All', 'Disable All', 'Reset to Defaults'}) do
    assert(naowhTexts[text] and not skinTexts[text], 'Naowh control not on its own page: ' .. text)
end
assert(page.title == 'Naowh Forever Additional Settings', 'page not renamed: ' .. tostring(page.title))
skinTexts['Divider strength'].setValue(30)
assert(config:Get().borderAlpha == 30, 'slider does not save')
-- The border style serves the EllesmereUI borders too: with Naowh Forever's row off it stays
-- editable, while Naowh's own border switches lock.
EUIAdditionalSkinningDB.skins = {NaowhForever = false}
assert(not skinTexts['Copy Main Action Bar 1 border'].disabled(), 'border style locked with Naowh Forever off')
assert(skinTexts['Enable custom borders'].disabled() and skinTexts['Divider strength'].disabled(), 'Naowh border switches open with Naowh off')
EUIAdditionalSkinningDB.skins = nil

-- 5b. Manual border: Main Action Bar 1's option set, built from EllesmereUI's own border controls
-- (stand-ins here), locked while copying, kept when switching modes, drawn when copying is off.
T = dofile('tests/support.lua'); Setup(T)
OtherNaowhSkinDB = nil
EUIAdditionalSkinningDB = {naowh = {edgeMode = 'actionbars', edgeSize = 4, edgeR = 0.5}}
local E = EllesmereUI
E.GetBorderTextureDropdown = function() return {solid = 'Solid', pixels = 'Pixels'}, {'solid', 'pixels'} end
E.BorderPxSliderCfg = function(spec)
    return {type = 'slider', text = spec.text, getValue = spec.getStep,
        setValue = function(v) spec.setStep(math.min(v, 4)); spec.setPx(v > 4 and (v .. 'px') or false); spec.apply() end}
end
E.BorderOffsetRowCfgs = function(spec)
    assert(spec.addonKey == 'actionbars', 'offsets must use the action bars registry')
    local function Make(text, get, set) return {type = 'slider', text = text, getValue = get, setValue = function(v) set(v); spec.apply() end} end
    return Make('Border Width Offset', spec.getX, spec.setX), Make('Border Height Offset', spec.getY, spec.setY)
end
E.GetBorderDefaults = function() return 2, 2, 0, 0 end
E.GetBorderDefaultSize = function(_, tex) return tex == 'pixels' and 2 or 1 end
E.GetBorderStyleSelectDefaults = function(tex) return {r = 0.1, g = 0.2, b = 0.3}, tex == 'pixels' end
E.BorderPx = function(value) return type(value) == 'string' and tonumber(value:match('%d+')) or nil end
local styled = {}
E.ApplyBorderStyle = function(target, size, r, g, b, a, texture, offX, offY, shiftX, shiftY, key, sizeKey, _, px)
    styled[target] = {size = size, r = r, g = g, b = b, a = a, texture = texture, offX = offX, offY = offY,
        shiftX = shiftX, shiftY = shiftY, key = key, sizeKey = sizeKey, px = px}
end
pages, rows = {}, {}
E.RegisterPlugin = function(_, spec) pages = spec.modules end
E.Widgets = {SectionHeader = function() return nil, 30 end, Spacer = function() return nil, 10 end,
    DualRow = function(_, _, _, left, right) rows[#rows + 1] = left; rows[#rows + 1] = right; return nil, 40 end}
A = T.Load()
T.Fire('ADDON_LOADED', T.ADDON)
config = A.Naowh.Config
for _, module in ipairs(pages) do if module.key == 'Skins' then page = module end end
page.buildPage('Skins', {}, -10)
texts = {}
for _, row in ipairs(rows) do if row.text then texts[row.text] = row end end
local MANUAL = {'Border Style', 'Border Size', 'Border Width Offset', 'Border Height Offset', 'Shift X', 'Shift Y',
    'Border Color', 'Class Color', 'Show Behind'}
for _, text in ipairs(MANUAL) do
    assert(texts[text], 'manual option missing: ' .. text)
    assert(texts[text].disabled() and texts[text].disabledTooltip():find('Copying Main Action Bar 1', 1, true),
        text .. ' editable while copying Main Action Bar 1')
end
-- Seeded from the old plain edge (4 px, its colour).
local m = config:Manual()
assert(m.texture == 'solid' and m.thickness == 'strong' and m.r == 0.5, 'manual border not seeded from the old edge')
-- Copy off: manual controls open; offsets and shifts only for a textured style.
texts['Copy Main Action Bar 1 border'].setValue(false)
assert(config:Get().edgeMode == 'solid' and not texts['Border Style'].disabled(), 'manual controls still locked')
assert(texts['Shift X'].disabled() and texts['Shift X'].disabledTooltip():find('Textured', 1, true), 'shift open on a solid style')
texts['Border Style'].setValue('pixels')
assert(m.texture == 'pixels' and m.thickness == 'normal' and m.behind == true and m.r == 0.1, 'style pick did not take its defaults')
assert(not texts['Shift X'].disabled(), 'shift locked on a textured style')
texts['Border Size'].setValue(6); texts['Border Width Offset'].setValue(3); texts['Border Height Offset'].setValue(-1)
texts['Shift X'].setValue(2); texts['Shift Y'].setValue(0)
texts['Border Color'].setValue(0.9, 0.8, 0.7, 0.6); texts['Show Behind'].setValue(false)
assert(m.thickness == 'strong' and m.px == '6px' and m.offX == 3 and m.offY == -1 and m.shiftX == 2 and m.shiftY == nil
    and m.r == 0.9 and m.a == 0.6 and m.behind == false, 'a manual value did not save')
texts['Class Color'].setValue(true); assert(m.classColor == true, 'class colour did not save')
texts['Class Color'].setValue(false)
-- Copy on again keeps every manual value; off again finds them as left.
texts['Copy Main Action Bar 1 border'].setValue(true)
assert(texts['Border Style'].disabled() and m.px == '6px' and m.offX == 3 and m.texture == 'pixels', 'copy mode erased the manual border')
texts['Copy Main Action Bar 1 border'].setValue(false)
assert(config:Manual().texture == 'pixels' and config:Manual().r == 0.9, 'manual values lost switching back')

-- The renderer draws the manual border with every value; Show Behind keeps the element's level.
local function Render(db)
    local T = dofile('tests/support.lua'); Setup(T)
    OtherNaowhSkinDB = nil
    EUIAdditionalSkinningDB = db
    E = EllesmereUI
    styled = {}
    E.ApplyBorderStyle = function(target, size, r, g, b, a, texture, offX, offY, shiftX, shiftY, key, sizeKey, _, px)
        styled[target] = {size = size, r = r, a = a, texture = texture, offX = offX, offY = offY, shiftX = shiftX,
            sizeKey = sizeKey, px = px}
    end
    E.BorderPx = function(value) return type(value) == 'string' and tonumber(value:match('%d+')) or nil end
    E.PP = {GetBorders = function(f) return f.ppBorder end}
    E._ModuleNS = {EllesmereUIActionBars = {EAB = {db = {profile = {bars = {MainBar = {borderTexture = 'bar-tex',
        borderThickness = 'heavy', borderColor = {r = 0.4, g = 0.4, b = 0.4, a = 1}}}}}},
        ResolveBorderThickness = function() return 3, nil end}}
    local naowh = Naowh()
    function naowh.Border(frame) local edge = T.Frame('Frame', frame); edge.shown = true; return {_frame = edge, SetColor = function() end} end
    NaowhForever = naowh
    T.Load()
    T.Fire('ADDON_LOADED', T.ADDON)
    T.loaded.NaowhForever = true
    T.Fire('ADDON_LOADED', 'NaowhForever')
    T.Fire('PLAYER_LOGIN'); T.Flush()
    local item = T.Frame('Button', T.Frame('Frame')); item.width, item.height = 36, 36
    local child = T.Frame('Frame', item); child.level = 9
    item.ppBorder = T.Frame('Frame', item)
    naowh.Shared.ItemBar = nil
    -- An outlined element: the generic border path.
    naowh.Border(item, naowh.THEME.line)
    T.Flush()
    return styled[item], item.ppBorder.level
end
local manual = {naowh = {edgeMode = 'solid', manual = {texture = 'pixels', thickness = 'strong', px = '6px', r = 0.9, g = 0.8,
    b = 0.7, a = 0.6, offX = 3, offY = -1, shiftX = 2, behind = false}}}
local drawn, level = Render(manual)
assert(drawn and drawn.texture == 'pixels' and drawn.size == 4 and drawn.px == 6 and drawn.r == 0.9 and drawn.a == 0.6
    and drawn.offX == 3 and drawn.offY == -1 and drawn.shiftX == 2 and drawn.sizeKey == 'strong', 'manual border not drawn as set')
assert(level == 10, 'border not raised above the element by default')
manual.naowh.manual.behind = true
drawn, level = Render(manual)
assert(level ~= 10, 'Show Behind still raised the border above the content')
drawn = Render({naowh = {edgeMode = 'actionbars', manual = manual.naowh.manual}})
assert(drawn and drawn.texture == 'bar-tex' and drawn.size == 3, 'copy mode does not draw Main Action Bar 1 border')

-- 6. In-game issues A-D (Phase 3), on mirrors of the real frames.
T = dofile('tests/support.lua'); Setup(T)
T.enabled.NaowhForever = true -- installed and enabled before it loads, as in game
EUIAdditionalSkinningDB = nil
local applied = {}
EllesmereUI.ApplyBorderStyle = function(target) applied[target] = (applied[target] or 0) + 1 end
local shellCalls = {}
local WSkin = {Shell = function() end, GetFFD = function() return {} end}
EllesmereUI._ModuleNS = {EllesmereUIBlizzardSkin = {WSkin = WSkin}}
original = Naowh()
local BORDER = original.Shared.Style.BORDER_RGB
original.Border = function(frame, color)
    local edge = T.Frame('Frame', frame); edge.shown = true
    return {_frame = edge, SetColor = function() end}
end
original.Shared.Parts = {
    HudBackdrop = function(frame) return {frame = frame, border = original.Border(frame, BORDER)} end,
    Backdrop = function(frame) return setmetatable({frame = frame, gradient = T.Texture(frame)}, {__index = {Paint = function() end}}) end,
}
NaowhForever = original
A = T.Load()
T.Fire('ADDON_LOADED', T.ADDON)
T.loaded.NaowhForever = true
T.Fire('ADDON_LOADED', 'NaowhForever')
T.loaded.EllesmereUIBlizzardSkin = true
T.Fire('PLAYER_LOGIN'); T.Flush()
T.registered[T.PREFIX .. 'Naowh Forever'](T.S); T.Flush()

-- A: a large HUD element on UIParent (Restock: five lines, transparent "none" background) is a
-- HUD element, never a window: no shell (no background), but it keeps its HUD border.
local restock = T.Frame('Frame', nil, 'NaowhForeverRestock'); restock.width, restock.height = 220, 130
original.Shared.Parts.HudBackdrop(restock)
T.Flush()
for _, child in ipairs(restock.children) do assert(not child.skin.Shell, 'A: HUD element got a window shell') end
assert(applied[restock] == 1, 'A: HUD element lost its border')

-- B: a HUD card that clips its children (the waypoint's Quest Objectives card) gets its border on
-- an unclipped host beside it, one frame after the factory, so the module's SetClipsChildren counts.
local pin = T.Frame('Frame')
local objectives = T.Frame('Frame', pin); objectives.width, objectives.height = 240, 40
function objectives:DoesClipChildren() return self.clips end
original.Shared.Parts.HudBackdrop(objectives)
objectives.clips = true
T.Flush()
assert(not applied[objectives], 'B: border drawn inside a clipping frame')
local host
for _, child in ipairs(pin.children) do if applied[child] then host = child end end
assert(host and host.all == objectives, 'B: no unclipped host beside the clipping card')
objectives:Hide(); assert(not host.shown, 'B: host does not hide with its card')
objectives:Show(); assert(host.shown, 'B: host does not show with its card')
T.Refresh = nil

-- C, D: EllesmereUI's loot roll popup (243x84) and loot toast (276x96) are windows its engine
-- shells; they get the border although smaller than a Naowh window. Other small shelled frames don't.
local roll = T.Frame('Frame', nil, 'GroupLootFrame1'); roll.width, roll.height = 243, 84
local toast = T.Frame('Frame'); toast.width, toast.height = 276, 96
local other = T.Frame('Frame'); other.width, other.height = 120, 60
WSkin.Shell('lootroll', roll, {noTopBar = true})
WSkin.Shell('loottoast', toast, {noTopBar = true})
WSkin.Shell('somethingelse', other, {noTopBar = true})
T.Flush()
local function Host(f) for _, child in ipairs(f.children) do if applied[child] then return child end end end
assert(Host(roll), 'C: loot roll popup has no border')
local toastHost = Host(toast)
assert(toastHost and toast.EUIAdditionalSkinningBorder == toastHost, 'D: loot toast border missing or not published for the art sweep')
assert(not Host(other), 'a small frame of another window pack was bordered')
assert(not roll.EUIAdditionalSkinningBorder, 'only swept windows publish their host')
-- Pooled reuse: showing the same popup again makes no second border.
roll:Hide(); roll:Show(); T.Flush()
local count = 0
for _, child in ipairs(roll.children) do if applied[child] then count = count + 1 end end
assert(count == 1, 'C: reuse created another border host')


-- 7. EllesmereUI window and bag borders are independent of Naowh Forever (Skins page toggles).
local function EuiCase(db, naowhLoaded)
    local T = dofile('tests/support.lua'); Setup(T)
    EUIAdditionalSkinningDB = db
    local applied = {}
    EllesmereUI.ApplyBorderStyle = function(target) applied[target] = true end
    local WSkin = {Shell = function() end, GetFFD = function() return {} end}
    EllesmereUI._ModuleNS = {EllesmereUIBlizzardSkin = {WSkin = WSkin}}
    NaowhForever = nil
    T.Load()
    T.Fire('ADDON_LOADED', T.ADDON)
    if naowhLoaded then NaowhForever = Naowh(); T.loaded.NaowhForever = true; T.Fire('ADDON_LOADED', 'NaowhForever') end
    T.loaded.EllesmereUIBlizzardSkin = true
    T.Fire('PLAYER_LOGIN'); T.Flush()
    local window = T.Frame('Frame', nil, 'CharacterFrame'); window.width, window.height = 400, 500
    WSkin.Shell('character', window, {})
    T.Flush()
    for _, child in ipairs(window.children) do if applied[child] then return true end end
    return false
end
assert(EuiCase(nil, false), 'EllesmereUI windows not bordered without Naowh Forever installed')
assert(EuiCase({skins = {NaowhForever = false}}, true), 'EllesmereUI windows depend on the Naowh row')
assert(EuiCase({naowh = {useEdges = false}}, true), 'EllesmereUI windows depend on Naowh\'s custom-border switch')
assert(not EuiCase({euiWindows = false}, false), 'EllesmereUI window toggle off still bordered')
assert(EuiCase({naowh = {euiWindows = false}}, false), 'a stale value under naowh still counts (only the Skins page key does)')
assert(EuiCase({euiBags = false}, false), 'the bag toggle switched window borders')
assert(not EuiCase({disabled = true}, false), 'master switch off still bordered')

-- The toggles live on the Skins page, not the Naowh Forever page.
T = dofile('tests/support.lua'); Setup(T)
EUIAdditionalSkinningDB = {}
local modulesSpec, built = nil, {}
EllesmereUI.RegisterPlugin = function(_, spec) modulesSpec = spec.modules end
EllesmereUI.Widgets = {SectionHeader = function() return nil, 30 end, Spacer = function() return nil, 10 end,
    DualRow = function(_, _, _, left, right) built[#built + 1] = left; built[#built + 1] = right; return nil, 40 end}
A = T.Load()
local function Texts(key)
    built = {}
    for _, module in ipairs(modulesSpec) do if module.key == key then module.buildPage(key, {}, -10) end end
    local texts = {}
    for _, row in ipairs(built) do if row.text then texts[row.text] = row end end
    return texts
end
local skinsPage, naowhPage = Texts('Skins'), Texts('NaowhForever')
assert(skinsPage['Border EllesmereUI windows'] and skinsPage['Border EllesmereUI bags'], 'EllesmereUI toggles missing from the Skins page')
assert(not naowhPage['Border EllesmereUI windows'] and not naowhPage['Border EllesmereUI bags'], 'EllesmereUI toggles still on the Naowh page')
EUIAdditionalSkinningDB.skins = {NaowhForever = false}
local windows = skinsPage['Border EllesmereUI windows']
assert(not windows.disabled() and windows.getValue(), 'EllesmereUI toggle locked by the Naowh row')
windows.setValue(false)
assert(EUIAdditionalSkinningDB.euiWindows == false and not windows.getValue(), 'EllesmereUI toggle does not save')

-- /easnf (which replaced /nfeui): the status names the border mode; edge <n> sets a solid manual
-- border at that size step.
T = dofile('tests/support.lua'); Setup(T)
OtherNaowhSkinDB = nil
EUIAdditionalSkinningDB = {naowh = {manual = {texture = 'pixels', thickness = 'thin', r = 0.5, g = 0.5, b = 0.5}}}
A = T.Load()
T.Fire('ADDON_LOADED', T.ADDON)
T.Fire('PLAYER_LOGIN')
local function Chat(command)
    T.chat = {}; SlashCmdList.EASNF(command); return table.concat(T.chat, '\n')
end
assert(Chat(''):find("border Main Action Bar 1's", 1, true), 'status does not name the copied border')
local reply = Chat('edge 2')
local manual = A.Naowh.Config:Manual()
assert(reply:find('Solid manual border, size normal.', 1, true) and manual.texture == 'solid' and manual.thickness == 'normal'
    and manual.r == 0.5 and A.Naowh.Config:Get().edgeMode == 'solid', '/easnf edge did not set the manual border: ' .. reply)
assert(Chat(''):find('border manual (solid, normal)', 1, true), 'status does not name the manual border')
assert(Chat(''):find('/easnf edge bars', 1, true) and not Chat(''):find('nfeui', 1, true), 'help names an old command')

-- The Naowh page's bulk actions touch Naowh's settings only: Enable/Disable All switch its features
-- and keep the manual border; Reset to Defaults resets all of Naowh's settings, the manual border
-- included. None of them changes the EllesmereUI border toggles, Debug Mode or the skin switches.
T = dofile('tests/support.lua'); Setup(T)
OtherNaowhSkinDB = nil
local MANUAL_SET = {texture = 'pixels', thickness = 'heavy', px = '6px', r = 0.2, g = 0.3, b = 0.4, a = 0.5,
    classColor = false, offX = 2, behind = true}
EUIAdditionalSkinningDB = {debug = true, euiWindows = false, euiBags = false, skins = {Altoholic = false},
    naowh = {edgeMode = 'solid', borderAlpha = 40, manual = MANUAL_SET}}
pages, rows = {}, {}
EllesmereUI.RegisterPlugin = function(_, spec) pages = spec.modules end
EllesmereUI.Widgets = {SectionHeader = function() return nil, 30 end, Spacer = function() return nil, 10 end,
    DualRow = function(_, _, _, left, right) rows[#rows + 1] = left; rows[#rows + 1] = right; return nil, 40 end}
A = T.Load()
T.Fire('ADDON_LOADED', T.ADDON)
local naowhPage
for _, module in ipairs(pages) do if module.key == 'NaowhForever' then naowhPage = module end end
naowhPage.buildPage('Naowh Forever', {}, -10)
local buttons = {}
for _, row in ipairs(rows) do if row.type == 'button' then buttons[row.text] = row end end
local function Unrelated()
    local db = EUIAdditionalSkinningDB
    return db.debug == true and db.euiWindows == false and db.euiBags == false and db.skins.Altoholic == false
end
local function ManualKept()
    local m = A.Naowh.Config:Manual()
    return m.texture == 'pixels' and m.thickness == 'heavy' and m.px == '6px' and m.a == 0.5 and m.offX == 2 and m.behind == true
end
buttons['Disable All'].onClick()
local cfg = A.Naowh.Config:Get()
for _, key in ipairs(A.Naowh.Config.FEATURE_KEYS) do assert(cfg[key] == false, 'Disable All left ' .. key .. ' on') end
assert(ManualKept() and cfg.edgeMode == 'solid' and Unrelated(), 'Disable All changed the manual border or another setting')
buttons['Enable All'].onClick()
for _, key in ipairs(A.Naowh.Config.FEATURE_KEYS) do assert(cfg[key] == true, 'Enable All left ' .. key .. ' off') end
assert(ManualKept() and cfg.edgeMode == 'solid' and cfg.borderAlpha == 40 and Unrelated(), 'Enable All changed the manual border or another setting')
buttons['Reset to Defaults'].onClick()
local m = A.Naowh.Config:Manual()
assert(cfg.edgeMode == 'actionbars' and cfg.borderAlpha == A.Naowh.Config.DEFAULTS.borderAlpha and m.texture == 'solid'
    and m.px == false and m.offX == nil and m.behind == false, 'Reset to Defaults kept a Naowh setting or the manual border')
assert(Unrelated(), 'Reset to Defaults changed the EllesmereUI borders, Debug Mode or a skin switch')

print('PASS: Naowh dormant until its ADDON_LOADED, factories wrapped in place, saved settings honoured, Naowh-first activation, inert switched off, no guard or import, every setting on the options pages (border settings on the Skins page), manual border (complete option set, locked while copying, kept across modes, drawn as set, Show Behind), issues A-D (HUD never shelled, clipped cards bordered beside, loot roll and loot toast bordered), EllesmereUI borders independent of Naowh with their toggles on the Skins page, /easnf status and edge, bulk actions scoped to Naowh')
