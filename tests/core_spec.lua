-- Core: TOC load order and versions, lazy skin activation (factory runs only for an enabled, loaded target), EUI toggles only for enabled targets, GUID enable state, single install, no old-addon guard or settings import, combat-end pass only after a combat deferral, slash commands.
local T = dofile('tests/support.lua')
local toc = assert(io.open(T.TOC)):read('*a')

-- The TOC loads the catalog first and every listed file exists.
local first
for line in toc:gmatch('[^\r\n]+') do
    if not line:match('^#') and line:match('%S') then
        first = first or line
        assert(io.open(T.DIR .. (line:gsub('\\', '/'))), 'TOC lists a missing file: ' .. line)
    end
end
assert(first == 'Catalog.lua', 'Catalog.lua must load first')
assert(not toc:find('## Dependencies:[^\n]*EllesmereUIBlizzardSkin'), 'EllesmereUIBlizzardSkin must stay optional')

-- A test skin whose factory counts its runs.
local ns = T.Load()
assert(toc:match('## Version: (%S+)') == ns.VERSION, 'TOC and Core versions differ')
local factoryRuns, installs = 0, 0
ns.skinCatalog[#ns.skinCatalog + 1] = {id = 'Foo', label = 'Foo Addon', targets = {'Foo'}}
ns.skinCatalogByID.Foo = ns.skinCatalog[#ns.skinCatalog]
ns.RegisterSkinDefinition('Foo', function()
    factoryRuns = factoryRuns + 1
    ns.RegisterModule('Foo', 'Foo Addon', function() return _G.Foo ~= nil end, function() installs = installs + 1 end)
end)
local entry = ns.skinCatalogByID.Foo

-- Not enabled for this character (enable state is fixed for the session): no EUI toggle.
ns.skinCatalog[#ns.skinCatalog + 1] = {id = 'Baz', label = 'Baz Addon', targets = {'Baz'}}
ns.skinCatalogByID.Baz = ns.skinCatalog[#ns.skinCatalog]
-- Enabled but not loaded yet: the toggle appears, the factory still waits.
T.enabled.Foo = true
T.Fire('ADDON_LOADED', 'Other')
assert(not T.registered['EUI Additional Skinning - Baz Addon'], 'disabled target registered')
local register = assert(T.registered['EUI Additional Skinning - Foo Addon'], 'enabled target has no EUI toggle')
register(T.S)
assert(factoryRuns == 0 and #ns.modules == 0, 'factory ran before its target loaded')
-- Loaded: the factory runs once, the module waits for available(), then installs once.
T.loaded.Foo = true
T.Fire('ADDON_LOADED', 'Foo'); T.Fire('ADDON_LOADED', 'Foo')
assert(factoryRuns == 1 and entry.loaded and not entry.factory, 'factory must run exactly once')
assert(installs == 0, 'installed before available()')
Foo = {}
T.Fire('ADDON_LOADED', 'Foo'); T.Fire('ADDON_LOADED', 'Foo')
assert(installs == 1 and T.Module('Foo').active and ns.Status(entry) == 'active', 'single install')

-- The modern enable-state API is asked with the player's GUID, never the name.
local seen
C_AddOns.GetAddOnEnableState = function(name, character) seen = character; return 2 end
T.enabled.Bar = true; ns.TargetEnabled({targets = {'Bar'}})
assert(seen == 'Player-Test', 'enable state asked with ' .. tostring(seen))

-- Switched off on the options page: no activation for a fresh entry, status says so.
EUIAdditionalSkinningDB.skins = {Foo = false}
assert(not ns.IsEnabled(T.Module('Foo')) and ns.Status(entry) == 'switched off', 'per-skin switch')
EUIAdditionalSkinningDB.skins = nil

-- Slash commands: /eas (master switch, refresh, status) and /easnf for Naowh Forever, nothing else:
-- the old /euiangelos and /nfeui are gone, and there is one handler each.
assert(SLASH_EUIADDITIONALSKINNING1 == '/eas' and SLASH_EUIADDITIONALSKINNING2 == nil, 'slash names')
assert(SLASH_EASNF1 == '/easnf' and type(SlashCmdList.EASNF) == 'function', '/easnf not registered')
local commands = {}
for key, value in pairs(_G) do
    if type(key) == 'string' and key:match('^SLASH_') then
        assert(value ~= '/euiangelos' and value ~= '/nfeui', 'legacy command still registered: ' .. key .. ' = ' .. value)
        assert(not commands[value], 'two handlers for ' .. value); commands[value] = true
    end
end
assert(SlashCmdList.NAOWHELLESMERESKIN == nil and ns.SlashCommands.naowh == nil, 'old Naowh command routes left')
local function said(fragment)
    for _, line in ipairs(T.chat) do if line:find(fragment, 1, true) then return true end end
end
-- Help lists the dev commands only in Debug Mode (off by default).
assert(ns.DebugMode() == false, 'Debug Mode on by default')
T.chat = {}; SlashCmdList.EUIADDITIONALSKINNING('')
assert(said('/easnf') and not said('dump') and not said('probe') and not said('perf'), 'dev commands in help with Debug Mode off')
EUIAdditionalSkinningDB.debug = true
T.chat = {}; SlashCmdList.EUIADDITIONALSKINNING(''); assert(said('probe') and said('dump') and said('perf'), 'Debug Mode help')
EUIAdditionalSkinningDB.debug = nil
T.chat = {}; SlashCmdList.EUIADDITIONALSKINNING('off')
assert(EUIAdditionalSkinningDB.disabled and not ns.IsEnabled() and said('Disabled'), 'off')
T.chat = {}; SlashCmdList.EUIADDITIONALSKINNING('refresh'); assert(said('inactive'), 'refresh while off')
SlashCmdList.EUIADDITIONALSKINNING('on'); assert(not EUIAdditionalSkinningDB.disabled and ns.IsEnabled(), 'on')
T.chat = {}; SlashCmdList.EUIADDITIONALSKINNING(''); assert(said('Foo Addon: active'), 'status lists entries')


-- The combat-end event does nothing unless a skin load was held back by combat.
local loads = 0
local load = ns.LoadSkin
ns.LoadSkin = function(e) loads = loads + 1; return load(e) end
T.Fire('PLAYER_REGEN_ENABLED')
assert(loads == 0, 'combat end re-ran the load pass with nothing deferred')
local heldRuns = 0
ns.skinCatalog[#ns.skinCatalog + 1] = {id = 'Held', label = 'Held Addon', targets = {'Foo'}, skin = T.S}
ns.skinCatalogByID.Held = ns.skinCatalog[#ns.skinCatalog]
InCombatLockdown = function() return true end
ns.RegisterSkinDefinition('Held', function() heldRuns = heldRuns + 1 end)
assert(heldRuns == 0, 'a skin loaded in combat')
InCombatLockdown = function() return false end
loads = 0; T.Fire('PLAYER_REGEN_ENABLED')
assert(loads > 0 and heldRuns == 1, 'a load deferred by combat did not resume when it ended')
loads = 0; T.Fire('PLAYER_REGEN_ENABLED')
assert(loads == 0, 'the deferral was not cleared after it resumed')
ns.LoadSkin = load

-- No old-addon guard: another skinning addon being loaded changes nothing here, and nothing is
-- imported from its settings.
assert(ns.Conflict == nil and ns.REPLACED == nil, 'old-addon guard still present')
T.loaded.OtherSkins = true
OtherSkinsDB = {skins = {Auctionator = false}}
T.chat = {}; T.Fire('PLAYER_LOGIN')
assert(ns.IsEnabled() and ns.Status(entry) == 'active' and not said('still enabled'), 'an old addon deactivated this one')
assert(not (EUIAdditionalSkinningDB.skins and EUIAdditionalSkinningDB.skins.Auctionator == false)
    and EUIAdditionalSkinningDB.imported == nil, 'old settings imported')
T.loaded.OtherSkins = nil
print('PASS: TOC order and versions, lazy activation, EUI toggles for enabled targets, GUID enable state, single install, per-skin switch, slash commands, no old-addon guard or import, combat-end pass only after a deferral')
