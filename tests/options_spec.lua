-- Options: EUI plugin section, Debug Mode toggle, Button style (default and per skin, Game Menu or window, live), one row per catalog entry (each TOC skin defines one), rows locked while their addon is not enabled, a debounced reload prompt on every change, switch-on applied at once, /eas options.
local T = dofile('tests/support.lua')
local plugin, popups, opened, refreshes = nil, {}, nil, 0
EllesmereUI.RegisterPlugin = function(id, spec) plugin = {id = id, spec = spec}; return true end
EllesmereUI.OpenPlugin = function(id) opened = id; return true end
EllesmereUI.ShowConfirmPopup = function(_, opts) popups[#popups + 1] = opts end
EllesmereUI.RefreshPage = function() refreshes = refreshes + 1 end
-- Records each row's configs, as EUI's widget factory would build them.
local rows = {}
local function Record(_, _, _, left, right) rows[#rows + 1] = {left, right}; return nil, 40 end
EllesmereUI.Widgets = {
    SectionHeader = function(_, _, text) rows[#rows + 1] = {header = text}; return nil, 30 end,
    Spacer = function(_, _, _, height) return nil, height end,
    DualRow = Record, Slider = function() return nil, 40 end,
}
-- Every skin the TOC lists, so the row check below covers future skins too.
local skins = {}
for line in io.open(T.TOC):read('*a'):gmatch('[^\r\n]+') do
    if line:match('^Skins\\') then skins[#skins + 1] = (line:gsub('\\', '/')) end
end
local ns = T.Load(table.unpack(skins))

assert(plugin and plugin.id == T.ADDON, 'plugin not registered under the folder name')
assert(plugin.spec.label == 'Additional Skinning' and not plugin.spec.label:find('^EUI'), 'EUI refuses labels starting with EUI')
local page = plugin.spec.modules[1]
assert(page.key == 'Skins' and page.pages[1] == 'Skins', 'one Skins page first')
local height = page.buildPage('Skins', {}, -10)
assert(height > 0, 'page height')

local byText = {}
for _, row in ipairs(rows) do
    for _, cfg in ipairs(row) do if type(cfg) == 'table' and cfg.text then byText[cfg.text] = cfg end end
end
local master, skin = byText['Enable Skinning'], byText['Auctionator']
assert(master and skin, 'master and Auctionator toggles built')
-- Debug Mode: on the Skins page, off by default, saved at once without a reload prompt; off stops perf timing.
local debug = assert(byText['Enable Debug Mode'], 'no Debug Mode toggle on the Skins page')
assert(debug.getValue() == false, 'Debug Mode on by default')
local before = #popups
debug.setValue(true); T.Flush()
assert(EUIAdditionalSkinningDB.debug == true and debug.getValue() and #popups == before, 'Debug Mode not saved, or asked for a reload')
ns.profiling = true
debug.setValue(false); T.Flush()
assert(EUIAdditionalSkinningDB.debug == nil and not ns.profiling and #popups == before, 'Debug Mode off left perf timing on')

-- Button style: EllesmereUI windows by default, Game Menu opt-in. In the Game Menu style a button
-- the facade styles gets one inset 2px inside it with the Popup Menu button colour and
-- EllesmereUI's configured border (the Game Menu's calls); the window fill and border are hidden.
-- The dropdown switches live, both ways, without a reload.
local styleRow = assert(byText['Default button style'], 'no Default button style setting on the Skins page')
assert(styleRow.getValue() == 'window', 'Button style not EllesmereUI windows by default')
local borders, ffd = {}, {}
EllesmereUI._applyBlizzardConfiguredBorder = function(owner, prefix, legacy) borders[#borders + 1] = {owner, prefix, legacy} end
EllesmereUI.PP = {HideBorder = function(f) f.ppHidden = true end, ShowBorder = function(f) f.ppHidden = false end}
EllesmereUI._ModuleNS = {EllesmereUIBlizzardSkin = {WSkin = {GetFFD = function(f) ffd[f] = ffd[f] or {}; return ffd[f] end}}}
EllesmereUIDB = {popupMenuButtonBackgroundColor = {r = 0.54, g = 0, b = 0, a = 0.4}}
local early = T.Frame('Button', T.Frame('Frame')); ffd[early] = {bg = T.Texture(early, 'BACKGROUND')}
ns.StyledFacade(T.S).Button(early)
assert(#early.children == 0 and #borders == 0 and ffd[early].bg.alpha == 1, 'a button changed in the default (window) style')
styleRow.setValue('gamemenu'); T.Flush()
assert(EUIAdditionalSkinningDB.buttonStyle == 'gamemenu' and styleRow.getValue() == 'gamemenu' and #early.children == 1,
    'choosing Game Menu as the default not saved or not applied live')
borders = {}
local facade = ns.StyledFacade(T.S)
local btn = T.Frame('Button', T.Frame('Frame')); btn.label = T.FontString(btn, 'Search')
ffd[btn] = {bg = T.Texture(btn, 'BACKGROUND'), hover = T.Texture(btn, 'HIGHLIGHT')}
facade.Button(btn)
local inset = btn.children[1]
assert(btn.skin.Button and inset and ns.OwnFrames[inset] and #btn.children == 1, 'no Game Menu inset (or not marked as our own frame)')
assert(inset.points[1][2] == 2 and inset.points[1][3] == -2 and inset.points[2][2] == -2 and inset.points[2][3] == 2, 'inset not 2px inside the button')
assert(inset.bg.color[1] == 0.54 and inset.bg.color[4] == 0.4, 'inset not in the Popup Menu button colour')
assert(#borders == 1 and borders[1][1] == inset and borders[1][2] == 'popupMenuButton' and borders[1][3] == 1, 'Popup Menu border not applied')
assert(ffd[btn].bg.alpha == 0 and btn.ppHidden == true and inset.shown, 'window fill or border still showing')
assert(ffd[btn].hover.all == inset, 'hover wash not on the inset (it shows in the corners around the border)')
facade.Button(btn)
assert(#btn.children == 1 and #borders == 1, 'a second pass rebuilt the inset or the border')
before = #popups
styleRow.setValue('window'); T.Flush()
assert(EUIAdditionalSkinningDB.buttonStyle == nil and not inset.shown and ffd[btn].bg.alpha == 1 and btn.ppHidden == false
    and ffd[btn].hover.all == btn and #popups == before, 'switching to the window style is not live')
styleRow.setValue('gamemenu'); T.Flush()
assert(EUIAdditionalSkinningDB.buttonStyle == 'gamemenu' and inset.shown and ffd[btn].bg.alpha == 0 and btn.ppHidden == true
    and ffd[btn].hover.all == inset and #btn.children == 1, 'switching back to the Game Menu style is not live')
-- Without EllesmereUI's configured-border call, buttons keep the window style untouched.
-- Per skin: one row per frame skin (none for Naowh Forever), "Default" until set; a skin's own
-- choice wins over the default, live; "Default" again clears it.
for _, entry in ipairs(ns.skinCatalog) do
    local row = byText[entry.label .. ' buttons']
    if entry.integration then assert(not row, entry.label .. ' has a button style row')
    else assert(row and row.getValue() == 'default', entry.label .. ' has no button style row set to Default') end
end
local altoRow = byText['Altoholic buttons']
assert(altoRow.disabled() and altoRow.disabledTooltip():find('not enabled', 1, true), 'a skin row open while its addon is off')
local alto = T.Frame('Button', T.Frame('Frame')); ffd[alto] = {bg = T.Texture(alto, 'BACKGROUND')}
ns.StyledFacade(T.S, 'Altoholic').Button(alto)
assert(alto.children[1] and alto.children[1].shown, 'Altoholic button not in the default (Game Menu) style')
altoRow.setValue('window'); T.Flush()
assert(EUIAdditionalSkinningDB.buttonStyles.Altoholic == 'window' and altoRow.getValue() == 'window', 'per-skin choice not saved')
assert(not alto.children[1].shown and ffd[alto].bg.alpha == 1, 'per-skin choice not applied live')
assert(inset.shown and ffd[btn].bg.alpha == 0, 'one skin\'s choice changed another skin\'s buttons')
styleRow.setValue('window'); styleRow.setValue('gamemenu'); T.Flush()
assert(not alto.children[1].shown, 'the default overrode a skin\'s own choice')
altoRow.setValue('default'); T.Flush()
assert(EUIAdditionalSkinningDB.buttonStyles == nil and alto.children[1].shown, '"Default" did not hand the skin back to the default')
EllesmereUI._applyBlizzardConfiguredBorder = nil
local plain = T.Frame('Button', T.Frame('Frame')); ffd[plain] = {bg = T.Texture(plain, 'BACKGROUND')}
facade.Button(plain)
assert(#plain.children == 0 and ffd[plain].bg.alpha == 1 and not plain.ppHidden, 'a button changed without the Game Menu style available')
EllesmereUI.PP, EllesmereUI._ModuleNS, EllesmereUIDB = nil, nil, nil
-- Rows come from the catalog, so a skin has its row before its code loads.
for _, entry in ipairs(ns.skinCatalog) do assert(byText[entry.label], entry.id .. ' has no row on the options page') end
-- Each TOC skin file defines a catalog entry (ns.RegisterSkinDefinition), and each skin entry has a file.
local defined = 0
for _, entry in ipairs(ns.skinCatalog) do if entry.defined then defined = defined + 1 end end
assert(defined == #skins, 'a TOC skin file did not define a catalog entry (' .. defined .. ' of ' .. #skins .. ')')
for _, entry in ipairs(ns.skinCatalog) do
    assert(entry.defined or entry.integration, entry.id .. ' is in the catalog but no skin file defines it')
end

-- Its addon not enabled (not loaded): the row is locked and says why.
assert(skin.disabled() and skin.rawTooltip and skin.disabledTooltip():find('not enabled', 1, true), 'row of an absent addon must be locked')
Auctionator = {Tabs = {State = {knownTabs = {}}}}
T.Install('Auctionator')
local entry = ns.skinCatalogByID.Auctionator
assert(master.getValue() and skin.getValue() and not skin.disabled() and skin.disabledTooltip() == nil, 'both on by default')
assert(ns.Status(entry) == 'active', 'installed skin reads active: ' .. ns.Status(entry))

-- A skin switched off: the module turns off and a reload is offered once the changes settle.
local module = T.Module('Auctionator')
skin.setValue(false)
assert(EUIAdditionalSkinningDB.skins.Auctionator == false and not skin.getValue() and not ns.IsEnabled(module), 'skin not switched off')
assert(#popups == 0, 'the prompt waits for the changes to settle')
T.Flush()
assert(#popups == 1 and popups[1].reload and popups[1].message:find('Removing', 1, true), 'switching off must offer a reload')
assert(ns.Status(entry) == 'switched off', 'status names the switch')
-- Switched on again: the saved value is cleared, Apply runs, and a reload is offered too.
local applied = 0
local apply = ns.Apply
ns.Apply = function() applied = applied + 1; apply() end
skin.setValue(true); T.Flush()
assert(EUIAdditionalSkinningDB.skins.Auctionator == nil and skin.getValue() and applied == 1, 'switch-on not applied')
assert(#popups == 2 and popups[2].message:find('Applying', 1, true), 'switching on must offer a reload')

-- Rapid changes (a slider drag) give one prompt, for the last change.
skin.setValue(false); skin.setValue(true); T.Flush()
assert(#popups == 3 and popups[3].message:find('Applying', 1, true), 'rapid changes must prompt once')

-- The master switch disables every row and also offers a reload.
master.setValue(false); T.Flush()
assert(EUIAdditionalSkinningDB.disabled and not ns.IsEnabled() and skin.disabled() and #popups == 4, 'master off')
master.setValue(true); T.Flush()
assert(not EUIAdditionalSkinningDB.disabled and ns.IsEnabled() and not skin.disabled() and #popups == 5, 'master on')
assert(refreshes == 6, 'page refreshed after each change')

-- Another skinning addon being loaded locks nothing (no old-addon guard).
T.loaded.OtherSkins = true
assert(not skin.disabled() and not master.disabled and ns.IsEnabled(), 'a row locked beside another skinning addon')
T.loaded.OtherSkins = nil

SlashCmdList.EUIADDITIONALSKINNING('options')
assert(opened == T.ADDON, '/eas options does not open the page')
print('PASS: EUI plugin section, catalog rows and skin definitions, locks (absent addon, master; none for other skinning addons), debounced reload prompts, switch-on applied at once, /eas options')
