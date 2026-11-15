-- Loader: factories run once per enabled, loaded target; GUID filtering; deferred and disabled targets; late EUI; combat deferral; EUI toggle respected; failure isolation; no addon-loading calls.
local ns, entries, handlers, installed, loaded, disabled = {}, {}, {}, {}, {}, {}
local combat, attempts, errors = false, {}, {}
EUIAdditionalSkinningDB = {}; SlashCmdList = {}; DEFAULT_CHAT_FRAME = {AddMessage = function() end}
UnitName = function() return 'Tester' end
UnitGUID = function() return 'Player-Tester' end
InCombatLockdown = function() return combat end
geterrorhandler = function() return function(e) errors[#errors + 1] = e end end
CreateFrame = function()
    local f = {RegisterEvent = function() end}; function f:SetScript(_, fn) handlers[#handlers + 1] = fn end; return f
end
local function event(e, addon) for _, fn in ipairs(handlers) do fn(nil, e, addon) end end
C_AddOns = {
    GetAddOnInfo = function(name) if installed[name] then return name end end,
    GetAddOnEnableState = function(name, character)
        if character == 'Tester' then return 2 end
        assert(character == 'Player-Tester'); return disabled[name] and 0 or 2
    end,
    IsAddOnLoaded = function(name) return loaded[name] end,
    LoadAddOn = function() error('the loader must never request an addon load') end,
}
installed.BugSack, loaded.BugSack = true, true
installed.Attune = true
installed.WhatsTraining = true
installed.Altoholic, disabled.Altoholic = true, true
installed.OneForAll, loaded.OneForAll = true, true
installed.ForeverDungeonJournal, loaded.ForeverDungeonJournal = true, true
local euiAPI = {RegisterSkin = function(name, fn)
    assert(not entries[name]); entries[name] = fn
    fn({IsEnabled = function() return name ~= 'EUI Additional Skinning - Forever Dungeon Journal' end})
end}
EllesmereUI = nil
assert(loadfile('EUIAdditionalSkinning/Catalog.lua'))('EUIAdditionalSkinning', ns)
assert(loadfile('EUIAdditionalSkinning/Core.lua'))('EUIAdditionalSkinning', ns)
for _, entry in ipairs(ns.skinCatalog) do
    if not entry.integration then
        ns.RegisterSkinDefinition(entry.id, function()
            attempts[entry.id] = (attempts[entry.id] or 0) + 1
            if entry.id == 'OneForAll' then error('fixture activation failure') end
            ns.RegisterModule(entry.id, entry.label, function() return true end, function() end)
        end)
    end
end
assert(next(attempts) == nil, 'a factory ran before EUI handed its facade over')
EllesmereUI = euiAPI; event('PLAYER_LOGIN')
assert(attempts.BugSack == 1 and not attempts.Attune and not attempts.Altoholic and not attempts.ForeverDungeonJournal
    and not attempts.WhatsTraining, 'only the loaded, enabled, switched-on targets activate')
assert(entries['EUI Additional Skinning - Attune'] and not entries['EUI Additional Skinning - Altoholic']
    and not entries['EUI Additional Skinning - Auctionator'], 'EUI toggles only for enabled, installed targets')
assert(attempts.OneForAll == 1 and #errors == 1, 'a failing factory is reported once and isolated')
combat = true; loaded.Attune = true; event('ADDON_LOADED', 'Attune'); assert(not attempts.Attune, 'activated in combat')
loaded.WhatsTraining = true; event('ADDON_LOADED', 'WhatsTraining'); assert(not attempts.WhatsTraining)
combat = false; EUIAdditionalSkinningDB.disabled = true; event('PLAYER_REGEN_ENABLED'); assert(not attempts.Attune, 'activated while disabled')
EUIAdditionalSkinningDB.disabled = nil; event('PLAYER_REGEN_ENABLED')
assert(attempts.Attune == 1 and attempts.WhatsTraining == 1, 'deferred targets activate after combat')
for _ = 1, 25 do event('ADDON_LOADED', 'Unrelated') end
assert(attempts.BugSack == 1 and attempts.Attune == 1 and attempts.OneForAll == 1 and attempts.WhatsTraining == 1, 'reactivated')
-- The EUI toggle for Forever Dungeon Journal was off; turning it on hands a new facade over.
entries['EUI Additional Skinning - Forever Dungeon Journal']({IsEnabled = function() return true end})
assert(attempts.ForeverDungeonJournal == 1, 'EUI toggle on did not activate')
assert(not ns.skinCatalogByID.BugSack.factory and ns.skinCatalogByID.Altoholic.factory, 'factory lifecycle incorrect')
-- Replay an account/name mismatch: only the player's GUID decides.
local account = {Altoholic = 1, Attune = 1, OneForAll = 1}
local modern = C_AddOns; local state = modern.GetAddOnEnableState
UnitGUID = function() return 'Player-Reported' end
modern.GetAddOnInfo = function(name) return name end
modern.GetAddOnEnableState = function(name, character)
    if character == nil then return account[name] or 0 end
    if character == 'Tester' then return 2 end
    assert(character == 'Player-Reported')
    return (name == 'BugSack' or name == 'ForeverDungeonJournal') and 2 or 0
end
for _, entry in ipairs(ns.skinCatalog) do
    assert(ns.TargetEnabled(entry) == (entry.id == 'BugSack' or entry.id == 'ForeverDungeonJournal'), entry.id)
end
modern.GetAddOnEnableState = state
C_AddOns = nil; GetAddOnInfo = modern.GetAddOnInfo
GetAddOnEnableState = function(character, name) assert(character == 'TesterLegacy'); return disabled[name] and 0 or 2 end
UnitName = function() return 'TesterLegacy' end
assert(ns.TargetEnabled(ns.skinCatalogByID.BugSack) and not ns.TargetEnabled(ns.skinCatalogByID.Altoholic), 'legacy API')
C_AddOns = modern; GetAddOnInfo, GetAddOnEnableState = nil, nil; UnitName, UnitGUID = nil, nil
print('PASS: catalog factories, GUID filtering, deferred/disabled targets, late EUI, combat, EUI toggle, failure isolation, reuse and no addon-loading calls')
