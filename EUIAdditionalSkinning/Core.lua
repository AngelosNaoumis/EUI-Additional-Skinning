local ADDON, ns = ...
ns.VERSION = "2.3.0"
ns.TITLE = "EUI Additional Skinning"
ns.modules = {}

local CHAT = "|cff0cd29fEUI Additional Skinning:|r "
-- EUI's third-party skin list shows each toggle under this prefix.
local SKIN_PREFIX = "EUI Additional Skinning - "

function ns.Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(CHAT .. message)
end
local Print = ns.Print

-- The saved settings table: disabled (master switch), skins[id] = false (switched off here),
-- euiWindows/euiBags (EllesmereUI borders), debug (Debug Mode), buttonStyle ("gamemenu"; nil = EllesmereUI windows), buttonStyles[id] (per skin; nil = that default), skinSettings[id]
-- (declarative per-skin values), naowh (the Naowh Forever integration's settings),
-- skinFeatures[id][key] = false (optional skin component off),
-- dumps (Dev.lua).
local cleanedSavedVariables
local function RemoveSkinKey(db, tableKey, id)
    local values = db[tableKey]
    if type(values) ~= "table" then return end
    values[id] = nil
    if next(values) == nil then db[tableKey] = nil end
end

local function CleanSavedVariables(db)
    if cleanedSavedVariables then return end
    cleanedSavedVariables = true
    -- LayerSwap is no longer an integration. Remove only its owned entries, leaving every other
    -- skin preference intact. The BGE castbar component likewise disappeared when castbars became
    -- deliberately native again.
    for _, tableKey in ipairs({"skins", "buttonStyles", "skinFeatures", "skinSettings"}) do
        RemoveSkinKey(db, tableKey, "LayerSwap")
    end
    local features = type(db.skinFeatures) == "table" and db.skinFeatures.BattlegroundEnemiesFixed
    if type(features) == "table" then
        features.castbars = nil
        if next(features) == nil then RemoveSkinKey(db, "skinFeatures", "BattlegroundEnemiesFixed") end
    end
    local naowh = type(db.skinSettings) == "table" and db.skinSettings.NaowhForever
    if type(naowh) == "table" then
        naowh.buttonFontSize, naowh.autoResizeButtonText, naowh.minimumAutoFontSize = nil, nil, nil
        if next(naowh) == nil then RemoveSkinKey(db, "skinSettings", "NaowhForever") end
    end
end

function ns.DB()
    local db = EUIAdditionalSkinningDB
    if type(db) ~= "table" then db = {}; EUIAdditionalSkinningDB = db end
    CleanSavedVariables(db)
    return db
end

local IsLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
-- An addon folder is loaded in this session.
function ns.AddOnLoaded(name)
    return IsLoaded and IsLoaded(name) and true or false
end

-- The EllesmereUI window and bag borders (Skins page): "euiWindows" or "euiBags", on unless switched off.
function ns.EllesmereOption(key)
    local db = EUIAdditionalSkinningDB
    return not (db and db[key] == false)
end

-- Debug Mode (Skins page): the dev commands (/eas dump, probe, perf) work only while it is on. Off by default.
function ns.DebugMode()
    local db = EUIAdditionalSkinningDB
    return db and db.debug == true or false
end

-- True unless the integration was switched off on this addon's options page.
function ns.IsSwitchedOn(id)
    local skins = EUIAdditionalSkinningDB and EUIAdditionalSkinningDB.skins
    return not (skins and skins[id] == false)
end

-- Optional parts of a skin are on unless explicitly disabled. Keeping only false values makes
-- older saved-variable tables inherit new components without a migration.
function ns.SkinFeature(id, key)
    local features = EUIAdditionalSkinningDB and EUIAdditionalSkinningDB.skinFeatures
    local skin = features and features[id]
    return not (skin and skin[key] == false)
end

-- Skinning on overall (no module), or for one module: switched on here and in EUI.
function ns.IsEnabled(module)
    local db = EUIAdditionalSkinningDB
    if db and db.disabled then return false end
    if not module then return true end
    if not ns.IsSwitchedOn(module.id) then return false end
    local S = module.skin
    return S and (not S.IsEnabled or S.IsEnabled()) or false
end

-------------------------------------------------------------------------------
--  Targets and lazy activation
-------------------------------------------------------------------------------
local enabledCache, cacheCharacter = {}, nil
-- One of the entry's target addons is enabled for this character (it loads, or will load).
function ns.TargetEnabled(entry)
    local modern = C_AddOns and C_AddOns.GetAddOnEnableState
    -- The modern AddOn list keys characters by GUID: a name can read as enabled (2) for an addon
    -- that is disabled on this character. The legacy API takes the name.
    local character
    if modern then character = UnitGUID and UnitGUID("player")
    else character = UnitName and UnitName("player") end
    if not character then return false end -- Resolved again once the player exists.
    if character ~= cacheCharacter then enabledCache, cacheCharacter = {}, character end
    for _, target in ipairs(entry.targets) do
        if enabledCache[target] == nil then
            local info = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
            local ok, name = pcall(info or function() end, target)
            local state = 0
            if ok and name then
                if modern then state = C_AddOns.GetAddOnEnableState(target, character)
                elseif GetAddOnEnableState then state = GetAddOnEnableState(character, target) end
            end
            enabledCache[target] = (state or 0) > 0
        end
        if enabledCache[target] then return true end
    end
    return false
end

-- One of the entry's target addons is loaded in this session.
function ns.TargetLoaded(entry)
    for _, target in ipairs(entry.targets) do
        if ns.AddOnLoaded(target) then return true end
    end
    return false
end

-- Skin loads held back by combat, kept until they load or fail; while there are none the
-- combat-end event does nothing.
local deferred = {}

-- Run the entry's skin factory once every condition holds; it then registers its module.
function ns.LoadSkin(entry)
    if entry.loading or entry.loaded or entry.failed or not entry.factory or not entry.skin then return end
    if not ns.IsEnabled() or not ns.IsSwitchedOn(entry.id) then return end
    if entry.skin.IsEnabled and not entry.skin.IsEnabled() then return end
    if not ns.TargetEnabled(entry) or not ns.TargetLoaded(entry) then return end
    if InCombatLockdown and InCombatLockdown() then deferred[entry] = true; return end
    entry.loading = true
    local ok, reason = pcall(entry.factory)
    entry.loading = false
    entry.loaded = ok
    if ok then entry.factory = nil
    else
        entry.failed = true
        geterrorhandler()(ADDON .. " / " .. entry.label .. ": " .. tostring(reason))
    end
end

-- A skin file hands over its factory; it runs once its target is loaded (ns.LoadSkin).
function ns.RegisterSkinDefinition(id, factory)
    local entry = ns.skinCatalogByID[id]
    if not entry or entry.defined then error("Unknown or duplicate skin definition: " .. tostring(id)) end
    entry.defined, entry.factory = true, factory
    ns.LoadSkin(entry)
end

local function TryModules()
    for _, module in ipairs(ns.modules) do
        if not module.attempted and ns.IsEnabled(module) and module.available() then
            module.attempted = true
            local ok, err = pcall(module.install, module.skin, module)
            module.active = ok
            if not ok then geterrorhandler()(ADDON .. " / " .. module.label .. ": " .. tostring(err)) end
        end
    end
end

-- Each enabled target gets its toggle in EUI's third-party skin list; EUI hands back the S facade.
local function Register()
    local EUI = _G.EllesmereUI
    if not (EUI and EUI.RegisterSkin) then return end
    for _, entry in ipairs(ns.skinCatalog) do
        if not entry.registered and ns.TargetEnabled(entry) then
            entry.registered = true
            EUI.RegisterSkin(SKIN_PREFIX .. entry.label, function(S)
                -- Every skin's buttons draw the chosen button style (Widgets.lua).
                if ns.StyledFacade then S = ns.StyledFacade(S, entry.id) end
                entry.skin = S
                for _, module in ipairs(ns.modules) do
                    if module.id == entry.id then module.skin = S end
                end
                if entry.onSkin then entry.onSkin(S) end
                ns.LoadSkin(entry)
                TryModules()
            end)
        end
    end
end

-- A skin's factory calls this. available() says the target's frames exist; install runs once,
-- with the S facade EUI handed over for its catalog entry.
function ns.RegisterModule(id, label, available, install)
    for _, module in ipairs(ns.modules) do
        if module.id == id then error("Duplicate skin module: " .. id) end
    end
    local entry = ns.skinCatalogByID[id]
    table.insert(ns.modules, {id = id, label = label, available = available, install = install,
        registered = entry and entry.registered, skin = entry and entry.skin})
    TryModules()
end

-- Install skins that can install now and refresh the active ones. Switching one on applies here;
-- switching one off needs a reload, since a skin's hooks stay until then.
function ns.Apply()
    if not ns.IsEnabled() then return end
    for _, entry in ipairs(ns.skinCatalog) do ns.LoadSkin(entry) end
    TryModules()
    for _, module in ipairs(ns.modules) do
        if module.active and ns.IsEnabled(module) and module.refresh then module.refresh() end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
-- A skin deferred by combat activates when it ends.
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if ns.FlushButtonTypography then ns.FlushButtonTypography() end
        for _, module in ipairs(ns.modules) do
            if module.combatDeferred and module.refresh and ns.IsEnabled(module) then
                module.combatDeferred = nil
                local callback = module.flushCombatDeferred or module.refresh
                local ok, err = pcall(callback)
                if not ok then geterrorhandler()(ADDON .. " / " .. module.label .. ": " .. tostring(err)) end
            end
        end
        if next(deferred) == nil then return end
    end
    ns.DB()
    if event == "PLAYER_LOGIN" then
        if not (_G.EllesmereUI and _G.EllesmereUI.RegisterSkin) then
            Print("Skin API unavailable. Update EllesmereUI.")
        end
    end
    Register()
    for _, entry in ipairs(ns.skinCatalog) do ns.LoadSkin(entry) end
    TryModules()
    for entry in pairs(deferred) do
        if entry.loaded or entry.failed then deferred[entry] = nil end
    end
end)

-------------------------------------------------------------------------------
--  Status and commands
-------------------------------------------------------------------------------
-- One phrase for a catalog entry's state, as /eas and the options page show it.
function ns.Status(entry)
    if not ns.IsSwitchedOn(entry.id) then return "switched off" end
    if entry.failed then return "failed to load (error reported)" end
    local module
    for _, m in ipairs(ns.modules) do if m.id == entry.id then module = m end end
    if module and module.attempted and not module.active then return "failed to install (error reported)" end
    if (module and module.active and ns.IsEnabled(module)) or (entry.active and entry.active()) then return "active" end
    if not ns.TargetLoaded(entry) then return "addon not enabled" end
    return "inactive (off in EUI's Window Skins page)"
end

-- Extra subcommands (Options.lua, Dev.lua): ns.SlashCommands[name] = function(argument, Print).
-- Naowh Forever has its own command, /easnf (Integrations/NaowhForever/Runtime.lua).
ns.SlashCommands = ns.SlashCommands or {}
local HELP = "/eas options, on, off, refresh, euiwindows, euibags; /easnf for Naowh Forever"
local DEBUG_HELP = "Debug Mode: /eas dump <frame|mouse|clear>, probe <frame|mouse>, perf [off|reset]"

SLASH_EUIADDITIONALSKINNING1 = "/eas"
SlashCmdList.EUIADDITIONALSKINNING = function(message)
    local command, argument = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    local db = ns.DB()
    if ns.SlashCommands[command] then
        ns.SlashCommands[command](argument ~= "" and argument or nil, Print)
    elseif command == "off" or command == "on" then
        db.disabled = command == "off" or nil
        if command == "on" then ns.Apply() end
        Print((command == "off" and "Disabled." or "Enabled.") .. " Run /reload for a clean result.")
    elseif command == "refresh" then
        if not ns.IsEnabled() then return Print("Skins are inactive. Enable skinning and run /reload.") end
        ns.Apply()
        Print("Refresh requested.")
    else
        Print("v" .. ns.VERSION .. " | " .. HELP)
        if ns.DebugMode() then Print(DEBUG_HELP) end
        if db.disabled then Print("Skinning disabled. Enable it and run /reload.") end
        for _, entry in ipairs(ns.skinCatalog) do Print(entry.label .. ": " .. ns.Status(entry)) end
    end
end
