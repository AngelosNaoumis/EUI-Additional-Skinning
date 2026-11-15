local ADDON, ns = ...
-- "Additional Skinning" in EUI's options sidebar (EllesmereUI's PLUGINS_API.md). The Skins page
-- holds the master switch and one toggle per catalog entry; an integration with settings of its
-- own adds a page through ns.OptionPages. EUI refuses section labels starting with "EUI".
-- Every change asks for a reload: a skin's hooks stay until one. Switching on is also applied at
-- once, so choosing Later still shows the skin.
local LABEL = "Additional Skinning"
ns.OptionPages = ns.OptionPages or {}

local function MasterOff() return ns.DB().disabled and true or false end

-- Offer EUI's reload popup once the player stops changing things (a slider drag calls this on
-- every step); turning something on is applied at once as well.
local generation = 0
function ns.SettingChanged(on, what)
    local EUI = _G.EllesmereUI
    if on then ns.Apply() end
    if EUI.RefreshPage then EUI:RefreshPage() end
    generation = generation + 1
    local mine = generation
    C_Timer.After(0.4, function()
        if mine ~= generation or not EUI.ShowConfirmPopup then return end
        EUI:ShowConfirmPopup({title = "Reload Required",
            message = (on and "Applying " or "Removing ") .. what .. " requires a UI reload.",
            confirmText = "Reload Now", cancelText = "Later", reload = true})
    end)
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
    _, h = W:Spacer(parent, y, 10); y = y - h
    _, h = W:SectionHeader(parent, "SKINS", y); y = y - h
    local rows = {}
    for _, entry in ipairs(ns.skinCatalog) do rows[#rows + 1] = SkinRow(entry) end
    for index = 1, #rows, 2 do
        _, h = W:DualRow(parent, y, rows[index], rows[index + 1] or {type = "label", text = ""}); y = y - h
    end
    _, h = W:Spacer(parent, y, 10); y = y - h
    _, h = W:SectionHeader(parent, "ELLESMEREUI", y); y = y - h
    _, h = W:DualRow(parent, y, EllesmereRow("Border EllesmereUI windows", "euiWindows",
        "The border style set below on every window EllesmereUI's window engine skins, its Friends window and loot popups."),
        EllesmereRow("Border EllesmereUI bags", "euiBags", "The same border on EllesmereUI's bag, reagent bag and bank windows.")); y = y - h
    -- The border style (copy Main Action Bar 1's, or manual) and Naowh Forever's border switches,
    -- from Integrations/NaowhForever/Options.lua.
    if ns.BorderSections then
        _, h = W:Spacer(parent, y, 10); y = y - h
        y = ns.BuildSections(ns.BorderSections, parent, y)
    end
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
