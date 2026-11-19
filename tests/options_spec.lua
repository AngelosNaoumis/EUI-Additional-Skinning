-- Options: compact skin rows with native EUI cogs, declarative popup settings, live typography/style,
-- persistence, reload-gated components, target switches and /eas options.
local T = dofile('tests/support.lua')
local plugin, popups, opened, refreshes = nil, {}, nil, 0
EllesmereUI.RegisterPlugin = function(id, spec) plugin = {id = id, spec = spec}; return true end
EllesmereUI.OpenPlugin = function(id) opened = id; return true end
EllesmereUI.ShowConfirmPopup = function(_, opts) popups[#popups + 1] = opts end
EllesmereUI.RefreshPage = function() refreshes = refreshes + 1 end
-- Records each row's configs, as EUI's widget factory would build them.
local rows, cogs = {}, {}
local function Record(_, _, _, left, right)
    local row = {_leftRegion = {}}
    rows[#rows + 1] = {left, right, frame = row}
    return row, 40
end
EllesmereUI.Widgets = {
    SectionHeader = function(_, _, text) rows[#rows + 1] = {header = text}; return nil, 30 end,
    Spacer = function(_, _, _, height) return nil, height end,
    DualRow = Record, Slider = function() return nil, 40 end,
}
EllesmereUI.BuildInlineCog = function(region, opts)
    cogs[#cogs + 1] = opts
    region.cog = opts
    return {opts = opts}
end
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
local function CogRows(id)
    local wanted = ns.skinCatalogByID[id].label .. ' Settings'
    local result, found = {}, nil
    for _, cog in ipairs(cogs) do if cog.title == wanted then found = cog end end
    assert(found, 'no three-dot settings popup for ' .. id)
    for _, section in ipairs(found.sections or {}) do
        for _, row in ipairs(section.rows or {}) do if row.label then result[row.label] = row end end
    end
    return result, found
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
local globalFontRow = assert(byText['Default Button Font Size'], 'no global default button font size')
local globalWrappingRow = assert(byText['Disable Button Text Wrapping'], 'no global wrapping toggle')
assert(globalFontRow.getValue() == 8 and globalFontRow.min == 4 and globalFontRow.max == 32,
    'global font default or range is wrong')
assert(not globalWrappingRow.getValue(), 'global wrapping disable is on by default')
globalWrappingRow.setValue(true)
assert(globalWrappingRow.getValue() and EUIAdditionalSkinningDB.disableButtonTextWrapping,
    'global wrapping toggle did not persist or apply live')
globalWrappingRow.setValue(false)
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
-- The main page contains only one toggle and one native three-dot control per skin; the global
-- default remains above the SKINS header.
local headerAt, defaultAt = {}, nil
for i, row in ipairs(rows) do
    if row.header then headerAt[row.header] = i end
    if row[1] and row[1].text == 'Default button style' then defaultAt = i end
end
assert(defaultAt and defaultAt < headerAt.SKINS, 'Default button style not above the skin rows')
for _, entry in ipairs(ns.skinCatalog) do
    local mainRow
    for _, row in ipairs(rows) do
        if row[1] and row[1].text == entry.label then mainRow = row end
    end
    assert(mainRow and mainRow[2] == nil and mainRow.frame._leftRegion.cog,
        entry.label .. ' main row contains inline settings or has no cog')
end
assert(#cogs == #ns.skinCatalog, 'a skin created no cog or duplicate cogs')
-- Per button-bearing frame skin: "Default" until set; a skin's own choice wins over the default,
-- live; "Default" again clears it. Naowh has neither generic typography nor button style.
for _, entry in ipairs(ns.skinCatalog) do
    local popup = CogRows(entry.id)
    local row = popup['Button Style']
    if entry.buttons and not entry.integration then
        assert(row and row.get() == 'default', entry.label .. ' has no popup button style set to Default')
    else assert(not row, entry.label .. ' exposes a meaningless button style') end
end
local altoPopup = CogRows('Altoholic')
local altoRow = altoPopup['Button Style']
assert(not altoRow.disabled, 'popup settings are locked while the target is absent')
local alto = T.Frame('Button', T.Frame('Frame')); ffd[alto] = {bg = T.Texture(alto, 'BACKGROUND')}
ns.StyledFacade(T.S, 'Altoholic').Button(alto)
assert(alto.children[1] and alto.children[1].shown, 'Altoholic button not in the default (Game Menu) style')
altoRow.set('window'); T.Flush()
assert(EUIAdditionalSkinningDB.buttonStyles.Altoholic == 'window' and altoRow.get() == 'window', 'per-skin choice not saved')
assert(not alto.children[1].shown and ffd[alto].bg.alpha == 1, 'per-skin choice not applied live')
assert(inset.shown and ffd[btn].bg.alpha == 0, 'one skin\'s choice changed another skin\'s buttons')
styleRow.setValue('window'); styleRow.setValue('gamemenu'); T.Flush()
assert(not alto.children[1].shown, 'the default overrode a skin\'s own choice')
altoRow.set('default'); T.Flush()
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

-- Optional components live only in their popup, default on, persist only explicit false, and stay
-- configurable before the target is loaded.
local dbmPopup = CogRows('DeadlyBossMods')
local dbmBars = assert(dbmPopup['Unified timer border'], 'DBM unified-border option missing')
local dbmIcons = assert(dbmPopup['Icon/bar dividers'], 'DBM divider option missing')
assert(dbmBars.get(), 'DBM timer-bar feature not on by default')
assert(dbmIcons.get(), 'DBM timer-icon feature not on by default')
assert(not dbmBars.disabled, 'DBM feature locked while its target is absent')
T.loaded['DBM-StatusBarTimers'] = true
local featurePopups, featureRefreshes = #popups, refreshes
dbmIcons.set(false); T.Flush()
assert(not ns.SkinFeature('DeadlyBossMods', 'icons')
    and EUIAdditionalSkinningDB.skinFeatures.DeadlyBossMods.icons == false,
    'DBM divider switch was not persisted')
dbmIcons.set(true); T.Flush()
assert(ns.SkinFeature('DeadlyBossMods', 'icons') and EUIAdditionalSkinningDB.skinFeatures == nil,
    'DBM divider default did not clear the saved override')
assert(#popups == featurePopups + 2 and refreshes == featureRefreshes + 2,
    'DBM feature changes did not use the standard reload/refresh lifecycle')

local bgeRows = CogRows('BattlegroundEnemiesFixed')
local bgeFeatures = {
    assert(bgeRows['Unit-frame borders'], 'BGE unit-frame option missing'),
    assert(bgeRows['Health/Power dividers'], 'BGE Health/Power option missing'),
    assert(bgeRows['Buff/debuff borders'], 'BGE aura option missing'),
    (assert(bgeRows['Additional icon borders'], 'BGE icon option missing')),
}
assert(not bgeRows['Castbar borders'], 'BGE still exposes obsolete castbar skinning')
for _, option in ipairs(bgeFeatures) do
    assert(option.get() and not option.disabled, 'BGE feature default or absent-target configuration is wrong')
end
T.loaded.BattleGroundEnemiesFixed = true
local bgePopups, bgeRefreshes = #popups, refreshes
bgeFeatures[2].set(false); T.Flush()
assert(not ns.SkinFeature('BattlegroundEnemiesFixed', 'dividers')
    and EUIAdditionalSkinningDB.skinFeatures.BattlegroundEnemiesFixed.dividers == false,
    'BGE Health/Power divider switch was not persisted')
bgeFeatures[2].set(true); T.Flush()
assert(ns.SkinFeature('BattlegroundEnemiesFixed', 'dividers') and EUIAdditionalSkinningDB.skinFeatures == nil,
    'BGE divider default did not clear the saved override')
assert(#popups == bgePopups + 2 and refreshes == bgeRefreshes + 2,
    'BGE feature changes did not use the standard reload/refresh lifecycle')

-- Typography is isolated per applicable skin. Default inherits the global value, native and
-- explicit options remain independent, and auto-resize is reload-gated.
local altoTypography = CogRows('Altoholic')
local attuneTypography = CogRows('Attune')
for _, popup in ipairs({altoTypography, attuneTypography}) do
    assert(popup['Button Font Size'].get() == 'default' and not popup['Auto Resize Button Text'].get()
        and popup['Button Text Wrapping'].get() == 'default'
        and popup['Minimum Auto Font Size'].get() == 8, 'typography defaults are wrong')
    assert(not popup['Button Font Size'].disabled(), 'font dropdown disabled while auto resize is off')
    assert(popup['Minimum Auto Font Size'].disabled(), 'minimum size is enabled while auto resize is off')
end
local typographyPopups = #popups
altoTypography['Button Font Size'].set(11)
altoTypography['Button Text Wrapping'].set('disabled')
altoTypography['Auto Resize Button Text'].set(true)
altoTypography['Minimum Auto Font Size'].set(6)
T.Flush()
assert(ns.ButtonFontSelection('Altoholic') == 11 and ns.ConfiguredAutoResizeButtonText('Altoholic')
    and not ns.AutoResizeButtonText('Altoholic') and ns.ButtonTextWrappingDisabled('Altoholic')
    and ns.MinimumAutoFontSize('Altoholic') == 6, 'Altoholic typography did not persist')
assert(ns.ButtonFontSelection('Attune') == 'default' and not ns.AutoResizeButtonText('Attune'),
    'one skin typography changed another')
assert(altoTypography['Button Font Size'].disabled() and not altoTypography['Minimum Auto Font Size'].disabled()
    and #popups == typographyPopups + 1 and popups[#popups].confirmText == 'Reload UI',
    'auto-resize did not preserve pending state or request the required reload')
assert(not CogRows('DeadlyBossMods')['Button Font Size'], 'buttonless DBM exposes typography controls')
local naowhTypography = CogRows('NaowhForever')
assert(not naowhTypography['Button Font Size'] and not naowhTypography['Auto Resize Button Text']
    and not naowhTypography['Button Text Wrapping'] and not naowhTypography['Minimum Auto Font Size'],
    'Naowh exposes shared typography controls')

SlashCmdList.EUIADDITIONALSKINNING('options')
assert(opened == T.ADDON, '/eas options does not open the page')
print('PASS: compact skin rows, native cog settings, isolated typography, optional components, persistence, reload lifecycle and /eas options')
