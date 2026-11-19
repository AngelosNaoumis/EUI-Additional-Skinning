local ADDON, ns = ...
-- Declarative per-skin settings. Options.lua renders these definitions through EllesmereUI's
-- shared cog popup; runtime helpers read only the compact saved values below.

local registry = {}
ns.skinSettings = registry

local function Number(value, fallback, minimum, maximum)
    if type(value) ~= "number" then return fallback end
    value = math.floor(value + 0.5)
    return math.max(minimum, math.min(maximum, value))
end

local function Saved(id, create)
    local db = ns.DB()
    if type(db.skinSettings) ~= "table" then
        if not create then return end
        db.skinSettings = {}
    end
    local saved = db.skinSettings[id]
    if type(saved) ~= "table" then
        if not create then return end
        saved = {}
        db.skinSettings[id] = saved
    end
    return saved
end

function ns.SupportsButtonTypography(id)
    local entry = ns.skinCatalogByID[id]
    return entry and entry.typography == true or false
end

-- Register sections for a skin's three-dot popup. A section is
-- {title = "TYPOGRAPHY", settings = {...}}; rows may use the native EllesmereUI cog types.
function ns.RegisterSkinSettings(id, sections, options)
    if not ns.skinCatalogByID[id] then error("Unknown skin settings: " .. tostring(id)) end
    if registry[id] then error("Duplicate skin settings: " .. tostring(id)) end
    registry[id] = {sections = sections or {}, reset = options and options.reset,
        reload = options and options.reload == true}
end

-- A simple registered setting's saved value, or its default. Custom rows may keep their existing
-- SavedVariables by supplying get/set functions instead.
function ns.SkinSetting(id, key, default)
    local saved = Saved(id)
    local value = saved and saved[key]
    if value == nil or type(value) ~= type(default) then return default end
    return value
end

-- Save only values that differ from the default, so new defaults and old SavedVariables remain
-- independent per skin and empty tables disappear.
function ns.SetSkinSetting(id, key, value, default)
    local saved = Saved(id, value ~= default)
    if not saved then return end
    saved[key] = value ~= default and value or nil
    if next(saved) == nil then
        ns.DB().skinSettings[id] = nil
        if next(ns.DB().skinSettings) == nil then ns.DB().skinSettings = nil end
    end
end

-- Global default plus the per-skin inheritance choice. An absent per-skin value means Default;
-- existing numeric values remain explicit overrides, including a deliberately selected 8.
function ns.DefaultButtonFontSize()
    return Number(ns.DB().defaultButtonFontSize, 8, 4, 32)
end

function ns.SetDefaultButtonFontSize(value)
    value = Number(value, 8, 4, 32)
    ns.DB().defaultButtonFontSize = value ~= 8 and value or nil
end

function ns.ButtonFontSelection(id)
    local saved = Saved(id)
    local value = saved and saved.buttonFontSize
    if value == "addon" then return "addon" end
    if type(value) == "number" then return Number(value, 8, 4, 32) end
    return "default"
end

function ns.SetButtonFontSelection(id, value)
    if type(value) == "string" and value ~= "default" and value ~= "addon" then value = tonumber(value) end
    if type(value) == "number" then value = Number(value, 8, 4, 32)
    elseif value ~= "addon" then value = "default" end
    ns.SetSkinSetting(id, "buttonFontSize", value, "default")
end

function ns.ResolveButtonFontSize(id, originalSize)
    local selection = ns.ButtonFontSelection(id)
    if selection == "addon" then return "addon", originalSize end
    if selection == "default" then return "default", ns.DefaultButtonFontSize() end
    return "fixed", selection
end

-- Global wrapping opt-out, off when absent.
function ns.DisableButtonTextWrapping()
    return ns.DB().disableButtonTextWrapping == true
end

-- Persist the global wrapping opt-out compactly.
function ns.SetDisableButtonTextWrapping(on)
    ns.DB().disableButtonTextWrapping = on and true or nil
end

-- A typography-capable skin's Default, Enabled or Disabled selection.
function ns.ButtonTextWrappingSelection(id)
    if not ns.SupportsButtonTypography(id) then return "default" end
    local saved = Saved(id)
    local value = saved and saved.buttonTextWrapping
    if value == "enabled" or value == "disabled" then return value end
    return "default"
end

-- Save one wrapping selection; invalid values become Default.
function ns.SetButtonTextWrappingSelection(id, value)
    if not ns.SupportsButtonTypography(id) then return end
    if value ~= "enabled" and value ~= "disabled" then value = "default" end
    ns.SetSkinSetting(id, "buttonTextWrapping", value, "default")
end

-- Resolve Default through the global opt-out; ineligible skins always remain native.
function ns.ButtonTextWrappingDisabled(id)
    if not ns.SupportsButtonTypography(id) then return false end
    local selection = ns.ButtonTextWrappingSelection(id)
    if selection == "enabled" then return false end
    if selection == "disabled" then return true end
    return ns.DisableButtonTextWrapping()
end

-- Configured auto-resize is what the options panel displays. Active auto-resize is snapshotted at
-- load so choosing Reload Later cannot partially change already-created or newly-created buttons.
local activeAutoResize, activeAutoKnown = {}, {}
local function ConfiguredAutoResize(id)
    return ns.SkinSetting(id, "autoResizeButtonText", false) == true
end
for _, entry in ipairs(ns.skinCatalog) do
    if entry.typography then
        activeAutoResize[entry.id] = ConfiguredAutoResize(entry.id)
        activeAutoKnown[entry.id] = true
    end
end

function ns.ConfiguredAutoResizeButtonText(id)
    return ns.SupportsButtonTypography(id) and ConfiguredAutoResize(id) or false
end

function ns.AutoResizeButtonText(id)
    if not ns.SupportsButtonTypography(id) then return false end
    if not activeAutoKnown[id] then
        activeAutoResize[id], activeAutoKnown[id] = ConfiguredAutoResize(id), true
    end
    return activeAutoResize[id]
end

function ns.ButtonFontSelectionLocked(id)
    return ns.ConfiguredAutoResizeButtonText(id) or ns.AutoResizeButtonText(id)
end

function ns.MinimumAutoFontSize(id)
    return Number(ns.SkinSetting(id, "minimumAutoFontSize", 8), 8, 4, 32)
end

-- Clear only this skin's options. Legacy button-style/component tables are retained in their old
-- locations for compatibility, but participate in the same reset action.
function ns.ResetSkinSettings(id)
    local db = ns.DB()
    if type(db.skinSettings) == "table" then
        db.skinSettings[id] = nil
        if next(db.skinSettings) == nil then db.skinSettings = nil end
    end
    if type(db.buttonStyles) == "table" then
        db.buttonStyles[id] = nil
        if next(db.buttonStyles) == nil then db.buttonStyles = nil end
    end
    if type(db.skinFeatures) == "table" then
        db.skinFeatures[id] = nil
        if next(db.skinFeatures) == nil then db.skinFeatures = nil end
    end
    local definition = registry[id]
    if definition and definition.reset then definition.reset() end
    if ns.RefreshButtonStyle then ns.RefreshButtonStyle(id) end
    if ns.RefreshButtonTypography then ns.RefreshButtonTypography(id) end
end
