local ADDON, A = ...
-- "Naowh Forever Additional Settings" in EUI's options: Naowh Forever's look and components. The
-- Borders and Manual Border sections are built here but shown on the Skins page (A.BorderSections):
-- the border style is also what the EllesmereUI window and bag borders draw. Every change is saved
-- at once and applies after /reload.
local NS = A.Naowh
local Config = NS.Config

local function DB() return Config:Get() end
local function M() return Config:Manual() end
local function Changed(what) A.SettingChanged(true, what) end
local function Locked()
    if not A.IsEnabled() then return "Turn on Enable Skinning." end
    if not A.IsSwitchedOn("NaowhForever") then return "Turn on Naowh Forever on the Skins page." end
end
local function Disabled() return Locked() ~= nil end
-- The border style (copy or manual) is shared with the EllesmereUI window and bag borders, which
-- work without Naowh Forever: it locks only while skinning is off.
local function StyleLocked()
    if not A.IsEnabled() then return "Turn on Enable Skinning." end
end
local function StyleDisabled() return StyleLocked() ~= nil end
local function CopyOn() return DB().edgeMode == "actionbars" end
-- Manual border controls: available only while Main Action Bar 1's border is not copied.
local function ManualLocked()
    local why = StyleLocked()
    if why then return why end
    if CopyOn() then return "Copying Main Action Bar 1's border. Turn that off to set the border here." end
end
local function ManualDisabled() return ManualLocked() ~= nil end
-- Offsets and shifts exist for textured styles only (as on the action bar page).
local function TexturedLocked()
    local why = ManualLocked()
    if why then return why end
    if M().texture == "solid" then return "Textured border styles only." end
end
local function TexturedDisabled() return TexturedLocked() ~= nil end

local function Toggle(text, key, tooltip, get, set)
    return {type = "toggle", text = text, tooltip = tooltip,
        disabled = Disabled, disabledTooltip = Locked, rawTooltip = true,
        getValue = get or function() return DB()[key] end,
        setValue = set or function(on) DB()[key] = on and true or false; Changed("this change") end}
end
local function Slider(text, key, max, tooltip)
    return {type = "slider", text = text, tooltip = tooltip, min = 0, max = max, step = 1,
        disabled = Disabled, disabledTooltip = Locked, rawTooltip = true,
        getValue = function() return DB()[key] end,
        setValue = function(value) DB()[key] = math.floor(value + 0.5); Changed("this change") end}
end
local function Button(text, onClick)
    return {type = "button", text = text, buttonText = text, disabled = Disabled, onClick = onClick}
end
local function ManualCfg(cfg, textured)
    cfg.disabled = textured and TexturedDisabled or ManualDisabled
    cfg.disabledTooltip = textured and TexturedLocked or ManualLocked
    cfg.rawTooltip = true
    return cfg
end

-- The style's own offsets and shifts for the manual border's size (EllesmereUI's "actionbars"
-- registry, the one the renderer passes), shown while no override is set.
local function ShiftDefaults()
    local E = _G.EllesmereUI
    local m = M()
    if not E.GetBorderDefaults then return 0, 0 end
    local ok, _, _, sx, sy = pcall(E.GetBorderDefaults, "actionbars", m.texture, m.thickness)
    if not ok then return 0, 0 end
    return sx or 0, sy or 0
end
local function Shift(text, key, pick)
    return ManualCfg({type = "slider", text = text, min = -10, max = 10, step = 1,
        tooltip = "Moves the textured border. Matches the default unless changed.",
        getValue = function()
            local v = M()[key]
            if v ~= nil then return v end
            return pick(ShiftDefaults())
        end,
        setValue = function(v)
            v = math.floor(v + 0.5)
            M()[key] = (v ~= pick(ShiftDefaults())) and v or nil
            Changed("this border")
        end}, true)
end

-- A style pick resets what EllesmereUI's action bar page resets: offsets, shifts and exact size,
-- and takes the style's default size, colour and Show Behind.
local function PickStyle(v)
    local E = _G.EllesmereUI
    local m = M()
    m.texture = v
    m.offX, m.offY, m.shiftX, m.shiftY, m.px = nil, nil, nil, nil, false
    if E.GetBorderDefaultSize then
        local ok, size = pcall(E.GetBorderDefaultSize, "actionbars", v)
        if ok and type(size) == "number" then size = Config.LABEL_OF_STEP[size] end
        if ok and Config.STEP_OF[size] then m.thickness = size end
    end
    if E.GetBorderStyleSelectDefaults then
        local ok, color, behind = pcall(E.GetBorderStyleSelectDefaults, v)
        if ok and type(color) == "table" then
            m.r, m.g, m.b, m.a, m.classColor = color.r or 0, color.g or 0, color.b or 0, 1, false
            m.behind = behind == true
        end
    end
    Changed("this border")
end

-- Main Action Bar 1's border option set (EllesmereUI's Bar Appearance page), built from
-- EllesmereUI's own border controls, which exist once its options are loaded (page build time).
local function ManualRows()
    local E = _G.EllesmereUI
    local rows = {}
    local values, order
    if E.GetBorderTextureDropdown then values, order = E.GetBorderTextureDropdown() end
    rows[#rows + 1] = ManualCfg({type = "dropdown", text = "Border Style", values = values or {solid = "Solid"},
        order = order or {"solid"}, getValue = function() return M().texture end, setValue = PickStyle})
    local function Step() return Config.STEP_OF[M().thickness] or 1 end
    if E.BorderPxSliderCfg then
        rows[#rows + 1] = ManualCfg(E.BorderPxSliderCfg{text = "Border Size",
            getStep = Step, setStep = function(step) M().thickness = Config.LABEL_OF_STEP[step] or "thin" end,
            getTex = function() return M().texture end,
            getPx = function() return M().px end, setPx = function(v) M().px = v end,
            apply = function() Changed("this border") end})
    end
    if E.BorderOffsetRowCfgs then
        local width, height = E.BorderOffsetRowCfgs{addonKey = "actionbars",
            getTex = function() return M().texture end, getStep = Step,
            getSizeKey = function() return M().thickness end, getPx = function() return M().px end,
            getX = function() return M().offX end, setX = function(v) M().offX = v end,
            getY = function() return M().offY end, setY = function(v) M().offY = v end,
            apply = function() Changed("this border") end}
        rows[#rows + 1] = ManualCfg(width, true)
        rows[#rows + 1] = ManualCfg(height, true)
    end
    rows[#rows + 1] = Shift("Shift X", "shiftX", function(x) return x end)
    rows[#rows + 1] = Shift("Shift Y", "shiftY", function(_, y) return y end)
    rows[#rows + 1] = ManualCfg({type = "colorpicker", text = "Border Color", hasAlpha = true,
        getValue = function() local m = M(); return m.r, m.g, m.b, m.a end,
        setValue = function(r, g, b, a)
            local m = M()
            m.r, m.g, m.b, m.a, m.classColor = r, g, b, a or m.a, false
            Changed("this border")
        end})
    rows[#rows + 1] = ManualCfg({type = "toggle", text = "Class Color", tooltip = "Draw the border in your class colour.",
        getValue = function() return M().classColor end,
        setValue = function(on) M().classColor = on and true or false; Changed("this border") end})
    rows[#rows + 1] = ManualCfg({type = "toggle", text = "Show Behind",
        tooltip = "Draw the border under the element's content instead of above it.",
        getValue = function() return M().behind end,
        setValue = function(on) M().behind = on and true or false; Changed("this border") end})
    return rows
end

-- Rows in pairs. A section's rows may be a function, built when the page is.
local function CopyRow()
    local row = Toggle("Copy Main Action Bar 1 border", "edgeMode",
        "Draw the border of your EllesmereUI Main Action Bar 1 on Naowh Forever and the EllesmereUI window and bag borders. Turn off to set the border below; those settings are kept either way.",
        CopyOn,
        function(on) DB().edgeMode = on and "actionbars" or "solid"; Changed("this change") end)
    row.disabled, row.disabledTooltip = StyleDisabled, StyleLocked
    return row
end
-- Shown on the Skins page (Options.lua), after its EllesmereUI section.
A.BorderSections = {
    {"BORDERS", {
        Toggle("Enable custom borders", "useEdges", "EllesmereUI-style borders on Naowh Forever's elements."),
        CopyRow(),
        Slider("Divider strength", "borderAlpha", Config.PERCENT, "Naowh Forever's divider and inner line strength, in percent."),
        Slider("Button-border strength", "buttonBorderAlpha", Config.PERCENT, "Naowh Forever's button border strength, in percent."),
    }},
    {"MANUAL BORDER", ManualRows},
}
local SECTIONS = {
    {"APPEARANCE", {
        Toggle("Use EllesmereUI font", "useFont", "Use EllesmereUI's selected font in Naowh Forever."),
        Toggle("Use EllesmereUI colors", "useColors", "Apply EllesmereUI's palette and accent colors."),
        Toggle("Use EllesmereUI window shells", "useShell", "Apply EllesmereUI backdrops to supported Naowh windows."),
        Toggle("Dark item-button plates", "itemPlates", "Place a dark slot behind supported item buttons."),
    }},
    {"SKINNED COMPONENTS", {
        Toggle("Naowh window borders", "windowBorders", "Borders on Naowh windows that use the EllesmereUI shell."),
        Toggle("General element borders", "genericBorders", "Other supported Naowh buttons, bars and outlined elements."),
        Toggle("Item-button borders", "itemBorders", "Borders on consumable and other item-bar buttons."),
        Toggle("HUD and tracker borders", "hudBorders", "Supported HUD cards, timers, trackers and status elements."),
        Toggle("PvP and Raid aura borders", "auraBorders", "Aura icons, during their safe initialization phase."),
        Toggle("Focus cast-bar border", "focusCastBorder", "One joined border around the focus cast bar and icon."),
        Toggle("GCD tracker borders", "gcdBorders", "Dynamically pooled GCD tracker icons."),
        Toggle("Top-bar group borders", "topBarBorders", "The left, center and right top-bar groups."),
    }},
    {"ALL SETTINGS", {
        Button("Enable All", function() Config:SetAll(true); Changed("these changes") end),
        Button("Disable All", function() Config:SetAll(false); A.SettingChanged(false, "these changes") end),
        Button("Reset to Defaults", function() Config:Reset(); Changed("the defaults") end),
    }},
}

-- Sections as headers and paired rows, from y; returns the new y. Shared with the Skins page.
-- Also run by EUI's search pre-build with a stub factory: it only builds rows.
function A.BuildSections(sections, parent, y)
    local W = _G.EllesmereUI.Widgets
    local _, h
    for index, section in ipairs(sections) do
        if index > 1 then _, h = W:Spacer(parent, y, 10); y = y - h end
        _, h = W:SectionHeader(parent, section[1], y); y = y - h
        local rows = section[2]
        if type(rows) == "function" then rows = rows() end
        for i = 1, #rows, 2 do
            _, h = W:DualRow(parent, y, rows[i], rows[i + 1] or {type = "label", text = ""}); y = y - h
        end
    end
    return y
end

local function Build(_, parent, y)
    return math.abs(A.BuildSections(SECTIONS, parent, y))
end

A.OptionPages = A.OptionPages or {}
A.OptionPages[#A.OptionPages + 1] = {key = "NaowhForever", title = "Naowh Forever Additional Settings",
    description = "Only what changes Naowh Forever: colors, font, window shells and which elements get borders (the border settings are on the Skins page). Changes apply after a reload. /easnf debug for status.",
    pages = {"Naowh Forever"}, buildPage = Build}
