-- Options: EUI plugin section, Debug Mode toggle, one row per catalog entry (each TOC skin defines one), rows locked while their addon is not enabled, a debounced reload prompt on every change, switch-on applied at once, /eas options.
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
