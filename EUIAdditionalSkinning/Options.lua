local ADDON, ns = ...
-- "Additional Skinning" in EUI's options sidebar (EllesmereUI's PLUGINS_API.md). The Skins page
-- holds the master switch and one compact toggle/cog row per catalog entry. Per-skin settings use
-- Settings.lua's registry and EllesmereUI's shared cog popup; OptionPages remains for genuinely
-- global future pages. EUI refuses section labels starting with "EUI".
local LABEL = "Additional Skinning"
ns.OptionPages = ns.OptionPages or {}

local function MasterOff() return ns.DB().disabled and true or false end

-- Offer EUI's reload popup once the player stops changing things (a slider drag calls this on
-- every step); turning something on is applied at once as well.
local generation = 0
local function QueueReload(message, confirmText)
    local EUI = _G.EllesmereUI
    generation = generation + 1
    local mine = generation
    C_Timer.After(0.4, function()
        if mine ~= generation or not EUI.ShowConfirmPopup then return end
        EUI:ShowConfirmPopup({title = "Reload Required", message = message,
            confirmText = confirmText or "Reload Now", cancelText = "Later", reload = true})
    end)
end

function ns.SettingChanged(on, what)
    local EUI = _G.EllesmereUI
    if on then ns.Apply() end
    if EUI.RefreshPage then EUI:RefreshPage() end
    QueueReload((on and "Applying " or "Removing ") .. what .. " requires a UI reload.")
end

function ns.RequestSettingReload(what)
    local EUI = _G.EllesmereUI
    if EUI.RefreshPage then EUI:RefreshPage() end
    QueueReload("Changing " .. what .. " requires a UI reload.", "Reload UI")
end

-- Why a row is locked, or nil while it can be switched.
local function Locked(entry)
    if not ns.TargetLoaded(entry) then
        return entry.label .. " is not enabled. Enable it in the AddOns list and reload."
    end
    if MasterOff() then return "Turn on Enable Skinning." end
end

local function SkinRow(entry)
    return {type = "toggle", text = entry.label,
        tooltip = "Skin " .. entry.label .. " in the EllesmereUI style. It also needs its toggle on EUI's Window Skins page.",
        disabled = function() return Locked(entry) ~= nil end,
        disabledTooltip = function() return Locked(entry) end, rawTooltip = true,
        getValue = function() return ns.IsSwitchedOn(entry.id) end,
        setValue = function(on)
            local db = ns.DB()
            db.skins = db.skins or {}
            if on then db.skins[entry.id] = nil else db.skins[entry.id] = false end
            ns.SettingChanged(on, entry.label .. "'s skin")
        end}
end

-- EllesmereUI's own windows and bags get the border style set in the Borders sections below. Independent of
-- Naowh Forever: it works without it installed, and with its row switched off.
local function Locked()
    if MasterOff() then return "Turn on Enable Skinning." end
end
local function SetEllesmere(key, on)
    ns.DB()[key] = on and true or false
    ns.SettingChanged(on, "this border")
end
local function EllesmereRow(text, key, tooltip)
    return {type = "toggle", text = text, tooltip = tooltip,
        disabled = function() return Locked() ~= nil end, disabledTooltip = Locked, rawTooltip = true,
        getValue = function() return ns.EllesmereOption(key) end,
        setValue = function(on) SetEllesmere(key, on) end}
end

-- The global default stays on the page; each skin's override lives in its three-dot popup.
local STYLE_NAMES = {gamemenu = "Game Menu", window = "EllesmereUI windows"}
local function ButtonDefaultRow()
    return {type = "dropdown", text = "Default button style",
        tooltip = "How buttons in the skinned addons look, unless a skin below has its own choice. EllesmereUI windows (default): the window skins' dark grey button. Game Menu: your EllesmereUI Popup Menu button colour and border, like the Game Menu.",
        values = STYLE_NAMES, order = {"window", "gamemenu"},
        getValue = function() return ns.ButtonStyle() end,
        setValue = function(value)
            ns.DB().buttonStyle = value == "gamemenu" and "gamemenu" or nil
            ns.RefreshButtonStyle()
        end}
end

local function SetButtonStyle(entry, value)
    local db = ns.DB()
    if type(db.buttonStyles) ~= "table" then db.buttonStyles = {} end
    db.buttonStyles[entry.id] = (value == "gamemenu" or value == "window") and value or nil
    if next(db.buttonStyles) == nil then db.buttonStyles = nil end
    ns.RefreshButtonStyle(entry.id)
end

local function SetFeature(entry, feature, on)
    local db = ns.DB()
    if type(db.skinFeatures) ~= "table" then db.skinFeatures = {} end
    if type(db.skinFeatures[entry.id]) ~= "table" then db.skinFeatures[entry.id] = {} end
    if on then db.skinFeatures[entry.id][feature.key] = nil
    else db.skinFeatures[entry.id][feature.key] = false end
    if next(db.skinFeatures[entry.id]) == nil then db.skinFeatures[entry.id] = nil end
    if next(db.skinFeatures) == nil then db.skinFeatures = nil end
    ns.SettingChanged(on, entry.label .. " " .. feature.label:lower())
end

local function SetTypography(entry, key, value, default)
    ns.SetSkinSetting(entry.id, key, value, default)
    ns.RefreshButtonTypography(entry.id)
    local EUI = _G.EllesmereUI
    if EUI.RefreshPage then EUI:RefreshPage() end
end


local FONT_SIZE_NAMES = {default = "Default", addon = "Addon's Font Size"}
local FONT_SIZE_ORDER = {"default", "addon"}
for size = 4, 32 do
    FONT_SIZE_NAMES[size] = tostring(size)
    FONT_SIZE_ORDER[#FONT_SIZE_ORDER + 1] = size
end

local function DefaultFontSizeRow()
    return {type = "slider", text = "Default Button Font Size", min = 4, max = 32, step = 1,
        tooltip = "Font size inherited by eligible skins whose Button Font Size is Default.",
        getValue = ns.DefaultButtonFontSize,
        setValue = function(value)
            ns.SetDefaultButtonFontSize(value)
            if ns.RefreshInheritedButtonTypography then ns.RefreshInheritedButtonTypography() end
        end}
end

-- Convert a registered declarative row to EllesmereUI's native cog-row schema. Existing Naowh
-- rows retain their getValue/setValue SavedVariables; new rows may use key/default directly.
local function CogRow(entry, setting)
    local row = {}
    for key, value in pairs(setting) do row[key] = value end
    row.label = setting.label or setting.text
    row.get = setting.get or setting.getValue
    row.set = setting.set or setting.setValue
    row.action = setting.action or setting.onClick
    if setting.key and not row.get then
        row.get = function() return ns.SkinSetting(entry.id, setting.key, setting.default) end
        row.set = function(value)
            ns.SetSkinSetting(entry.id, setting.key, value, setting.default)
            if setting.apply then setting.apply(value) end
            if setting.reload then ns.SettingChanged(true, setting.label or setting.text) end
        end
    end
    return row
end

local function PopupSections(entry)
    local sections = {}
    if entry.buttons and not entry.integration then
        sections[#sections + 1] = {title = "APPEARANCE", rows = {{
            type = "dropdown", label = "Button Style",
            tooltip = "Default follows the button style on the main Skins page.",
            values = {default = "Default", gamemenu = STYLE_NAMES.gamemenu, window = STYLE_NAMES.window},
            order = {"default", "window", "gamemenu"},
            get = function() return ns.SkinButtonSetting(entry.id) end,
            set = function(value) SetButtonStyle(entry, value) end,
        }}}
    end
    if entry.typography then
        sections[#sections + 1] = {title = "TYPOGRAPHY", rows = {
            {type = "toggle", label = "Auto Resize Button Text",
                tooltip = "After reload, shrink overflowing single-line button text only when necessary.",
                get = function() return ns.ConfiguredAutoResizeButtonText(entry.id) end,
                set = function(value)
                    ns.SetSkinSetting(entry.id, "autoResizeButtonText", value, false)
                    ns.RequestSettingReload(entry.label .. " automatic button text resizing")
                end},
            {type = "dropdown", label = "Button Font Size", values = FONT_SIZE_NAMES, order = FONT_SIZE_ORDER,
                tooltip = "Default inherits the global size. Addon's Font Size leaves native typography untouched.",
                disabled = function() return ns.ButtonFontSelectionLocked(entry.id) end,
                disabledTooltip = "Automatic text resizing takes effect after reload and preserves this selection.",
                get = function() return ns.ButtonFontSelection(entry.id) end,
                set = function(value)
                    ns.SetButtonFontSelection(entry.id, value)
                    ns.RefreshButtonTypography(entry.id)
                    local EUI = _G.EllesmereUI
                    if EUI.RefreshPage then EUI:RefreshPage() end
                end},
            {type = "slider", label = "Minimum Auto Font Size", min = 4, max = 32, step = 1,
                tooltip = "Smallest size automatic fitting may use.",
                disabled = function() return not ns.ConfiguredAutoResizeButtonText(entry.id) end,
                disabledTooltip = "Turn on Auto Resize Button Text.",
                get = function() return ns.MinimumAutoFontSize(entry.id) end,
                set = function(value) SetTypography(entry, "minimumAutoFontSize", value, 8) end},
        }}
    end
    if entry.features then
        local rows = {}
        for _, feature in ipairs(entry.features) do
            local function FeatureRow(part)
                return {type = "toggle", label = part.label, tooltip = part.tooltip,
                    get = function() return ns.SkinFeature(entry.id, part.key) end,
                    set = function(on) SetFeature(entry, part, on) end}
            end
            rows[#rows + 1] = FeatureRow(feature)
        end
        sections[#sections + 1] = {title = "COMPONENTS", rows = rows}
    end
    local registered = ns.skinSettings and ns.skinSettings[entry.id]
    if registered then
        for _, section in ipairs(registered.sections) do
            local source = section.settings or section.rows or section[2] or {}
            if type(source) == "function" then source = source() end
            local rows = {}
            for _, setting in ipairs(source) do rows[#rows + 1] = CogRow(entry, setting) end
            if #rows > 0 then
                sections[#sections + 1] = {title = section.title or section.section or section[1], rows = rows,
                    hidden = section.hidden, stackLast = section.stackLast}
            end
        end
    end
    if #sections > 0 then
        sections[#sections + 1] = {title = "RESET", stackLast = true, rows = {{
            type = "button", label = "Reset to Defaults", action = function()
                local EUI = _G.EllesmereUI
                local reset = function()
                    local autoBefore = entry.typography and ns.ConfiguredAutoResizeButtonText(entry.id)
                    ns.ResetSkinSettings(entry.id)
                    local registered = ns.skinSettings and ns.skinSettings[entry.id]
                    if autoBefore ~= (entry.typography and ns.ConfiguredAutoResizeButtonText(entry.id)) then
                        ns.RequestSettingReload(entry.label .. " automatic button text resizing")
                    elseif entry.features or registered and registered.reload then
                        ns.SettingChanged(true, entry.label .. " settings")
                    elseif EUI.RefreshPage then EUI:RefreshPage() end
                end
                if EUI.ShowConfirmPopup then
                    EUI:ShowConfirmPopup({title = "Reset " .. entry.label,
                        message = "Reset this skin's settings to their defaults?",
                        confirmText = "Reset", cancelText = "Cancel", onConfirm = reset})
                else reset() end
            end,
        }}}
    end
    return sections
end

-- Builds the Skins page; also run by EUI's search pre-build with a stub factory (no side effects).
local function BuildSkins(_, parent, y)
    local W = _G.EllesmereUI.Widgets
    local _, h
    _, h = W:SectionHeader(parent, "GENERAL", y); y = y - h
    _, h = W:DualRow(parent, y, {type = "toggle", text = "Enable Skinning",
        tooltip = "Master switch for every skin in " .. ns.TITLE .. ".",
        getValue = function() return not MasterOff() end,
        setValue = function(on) ns.DB().disabled = (not on) or nil; ns.SettingChanged(on, "these skins") end},
        -- Takes effect at once, no reload: it only gates the dev commands (Dev.lua).
        {type = "toggle", text = "Enable Debug Mode",
        tooltip = "Turns on the developer commands /eas dump, probe and perf. Off, they do nothing.",
        getValue = ns.DebugMode,
        setValue = function(on)
            ns.DB().debug = on and true or nil
            if not on then ns.profiling = false end
        end}); y = y - h
    -- Button style: the default here; each addon's own choice is in its cog. Live, no reload.
    _, h = W:DualRow(parent, y, ButtonDefaultRow(), DefaultFontSizeRow()); y = y - h
    _, h = W:Spacer(parent, y, 10); y = y - h
    _, h = W:SectionHeader(parent, "SKINS", y); y = y - h
    for _, entry in ipairs(ns.skinCatalog) do
        local row
        row, h = W:DualRow(parent, y, SkinRow(entry)); y = y - h
        if row and row._leftRegion and _G.EllesmereUI.BuildInlineCog then
            _G.EllesmereUI.BuildInlineCog(row._leftRegion, {title = entry.label .. " Settings",
                sections = PopupSections(entry), minWidth = 280, gap = 8})
        end
    end
    _, h = W:Spacer(parent, y, 10); y = y - h
    _, h = W:SectionHeader(parent, "ELLESMEREUI", y); y = y - h
    _, h = W:DualRow(parent, y, EllesmereRow("Border EllesmereUI windows", "euiWindows",
        "The border style set below on every window EllesmereUI's window engine skins, its Friends window and loot popups."),
        EllesmereRow("Border EllesmereUI bags", "euiBags", "The same border on EllesmereUI's bag, reagent bag and bank windows.")); y = y - h
    return math.abs(y)
end

local EUI = _G.EllesmereUI
if EUI and EUI.RegisterPlugin then
    local modules = {{key = "Skins", title = "Skins",
        description = "Turn skinning on or off, as a whole or per addon. /eas for status.",
        pages = {"Skins"}, buildPage = BuildSkins}}
    for _, page in ipairs(ns.OptionPages) do modules[#modules + 1] = page end
    EUI.RegisterPlugin(ADDON, {label = LABEL, modules = modules})
end

ns.SlashCommands = ns.SlashCommands or {}
for command, key in pairs({euiwindows = "euiWindows", euibags = "euiBags"}) do
    ns.SlashCommands[command] = function(_, Print)
        local on = not ns.EllesmereOption(key)
        ns.DB()[key] = on
        Print((on and "On" or "Off") .. ": EllesmereUI " .. (key == "euiBags" and "bag" or "window") .. " borders. Run /reload to apply.")
    end
end
ns.SlashCommands.options = function(_, Print)
    if not (EUI and EUI.OpenPlugin and EUI.OpenPlugin(ADDON)) then Print("Options unavailable: update EllesmereUI.") end
end
