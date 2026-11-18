-- Declarative settings registry and compact per-skin SavedVariables.
local T = dofile('tests/support.lua')
local ns = T.Load()

local entry = {id = 'FutureSkin', label = 'Future Skin', targets = {'FutureSkin'}, buttons = true, typography = true}
ns.skinCatalog[#ns.skinCatalog + 1] = entry
ns.skinCatalogByID.FutureSkin = entry
local reset = 0
local sections = {{section = 'ADVANCED', settings = {
    {key = 'enabledPart', type = 'toggle', label = 'Enabled Part', default = true},
    {key = 'amount', type = 'slider', label = 'Amount', default = 8, min = 4, max = 32},
    {type = 'dropdown', label = 'Existing Value', get = function() return 'a' end,
        set = function() end, values = {a = 'A'}},
    {type = 'colorpicker', label = 'Existing Color', get = function() return 1, 1, 1 end,
        set = function() end},
}}}
ns.RegisterSkinSettings('FutureSkin', sections, {reset = function() reset = reset + 1 end})
assert(ns.skinSettings.FutureSkin.sections == sections, 'registered settings were copied or lost')
assert(not pcall(ns.RegisterSkinSettings, 'FutureSkin', {}), 'duplicate registration was accepted')
assert(not pcall(ns.RegisterSkinSettings, 'MissingSkin', {}), 'unknown skin registration was accepted')

assert(ns.SkinSetting('FutureSkin', 'amount', 8) == 8, 'default setting not returned')
ns.SetSkinSetting('FutureSkin', 'amount', 12, 8)
assert(ns.SkinSetting('FutureSkin', 'amount', 8) == 12
    and EUIAdditionalSkinningDB.skinSettings.FutureSkin.amount == 12, 'non-default setting not persisted')
ns.SetSkinSetting('OtherSkin', 'amount', 20, 8)
assert(ns.SkinSetting('FutureSkin', 'amount', 8) == 12, 'skin settings are coupled')
ns.SetSkinSetting('FutureSkin', 'amount', 8, 8)
assert(not EUIAdditionalSkinningDB.skinSettings.FutureSkin, 'default did not remove the per-skin table')

EUIAdditionalSkinningDB.skinSettings.FutureSkin = {buttonFontSize = 'bad', autoResizeButtonText = 'yes',
    minimumAutoFontSize = 500}
assert(ns.ButtonFontSelection('FutureSkin') == 'default' and not ns.AutoResizeButtonText('FutureSkin')
    and ns.MinimumAutoFontSize('FutureSkin') == 32, 'invalid typography values were not normalized safely')
assert(ns.DefaultButtonFontSize() == 8 and ns.ResolveButtonFontSize('FutureSkin', 12) == 'default',
    'global typography defaults are wrong')
ns.SetDefaultButtonFontSize(10)
local mode, size = ns.ResolveButtonFontSize('FutureSkin', 12)
assert(mode == 'default' and size == 10 and EUIAdditionalSkinningDB.defaultButtonFontSize == 10,
    'Default selection did not inherit the global size')
EUIAdditionalSkinningDB.skinSettings.FutureSkin.buttonFontSize = 'addon'
mode, size = ns.ResolveButtonFontSize('FutureSkin', 12)
assert(mode == 'addon' and size == 12, 'Add-on font selection did not resolve to native size')
EUIAdditionalSkinningDB.skinSettings.FutureSkin.buttonFontSize = 8
mode, size = ns.ResolveButtonFontSize('FutureSkin', 12)
assert(mode == 'fixed' and size == 8, 'an existing numeric 8 was incorrectly migrated to Default')
ns.SetButtonFontSelection('FutureSkin', '11')
assert(ns.ButtonFontSelection('FutureSkin') == 11, 'numeric dropdown value was not normalized')
ns.SetButtonFontSelection('FutureSkin', 'default')
assert(ns.ButtonFontSelection('FutureSkin') == 'default', 'Default selection was not stored compactly')
assert(not ns.SupportsButtonTypography('NaowhForever') and not ns.AutoResizeButtonText('NaowhForever'),
    'Naowh Forever was not excluded by the typography capability')
EUIAdditionalSkinningDB.buttonStyles = {FutureSkin = 'gamemenu', OtherSkin = 'window'}
EUIAdditionalSkinningDB.skinFeatures = {FutureSkin = {part = false}, OtherSkin = {part = false}}
ns.ResetSkinSettings('FutureSkin')
assert(reset == 1 and not EUIAdditionalSkinningDB.skinSettings.FutureSkin
    and not EUIAdditionalSkinningDB.buttonStyles.FutureSkin
    and not EUIAdditionalSkinningDB.skinFeatures.FutureSkin, 'per-skin reset left registered or legacy values')
assert(EUIAdditionalSkinningDB.skinSettings.OtherSkin and EUIAdditionalSkinningDB.buttonStyles.OtherSkin
    and EUIAdditionalSkinningDB.skinFeatures.OtherSkin, 'per-skin reset changed another skin')

-- One-time SavedVariables cleanup removes only retired ownership. Explicit numeric font choices
-- and unrelated skin values survive exactly as saved.
T = dofile('tests/support.lua')
EUIAdditionalSkinningDB = {
    skins = {LayerSwap = false, Altoholic = false},
    buttonStyles = {LayerSwap = 'window', Altoholic = 'gamemenu'},
    skinFeatures = {LayerSwap = {part = false}, BattlegroundEnemiesFixed = {castbars = false, icons = false}},
    skinSettings = {LayerSwap = {buttonFontSize = 9}, Altoholic = {buttonFontSize = 8},
        NaowhForever = {buttonFontSize = 10, autoResizeButtonText = true, minimumAutoFontSize = 5}},
}
ns = T.Load()
assert(not EUIAdditionalSkinningDB.skins.LayerSwap and not EUIAdditionalSkinningDB.buttonStyles.LayerSwap
    and not EUIAdditionalSkinningDB.skinFeatures.LayerSwap and not EUIAdditionalSkinningDB.skinSettings.LayerSwap,
    'retired LayerSwap SavedVariables were not removed')
assert(not EUIAdditionalSkinningDB.skinSettings.NaowhForever,
    'obsolete Naowh typography settings were not removed')
assert(EUIAdditionalSkinningDB.skins.Altoholic == false
    and EUIAdditionalSkinningDB.buttonStyles.Altoholic == 'gamemenu'
    and EUIAdditionalSkinningDB.skinSettings.Altoholic.buttonFontSize == 8,
    'cleanup changed unrelated or explicit font preferences')
assert(EUIAdditionalSkinningDB.skinFeatures.BattlegroundEnemiesFixed.icons == false
    and EUIAdditionalSkinningDB.skinFeatures.BattlegroundEnemiesFixed.castbars == nil,
    'obsolete BGE castbar setting was not removed independently')

print('PASS: declarative skin setting registration, defaults, validation, isolation, legacy compatibility and reset')
