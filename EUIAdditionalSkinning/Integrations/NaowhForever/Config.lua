local ADDON, A = ...
-- The Naowh Forever integration: its namespace, settings and the
-- small colour helpers. Runtime.lua is the styling engine; Auras.lua the aura-icon borders;
-- Options.lua its page in EUI's options. Settings live in EUIAdditionalSkinningDB.naowh and
-- apply after a /reload.
local NS = {Modules = {}}
A.Naowh = NS
NS.NAOWH = "NaowhForever"
NS.NAOWH_COMBAT = "NaowhForever_Combat"

function NS:RegisterModule(name, module)
    assert(type(name) == "string" and type(module) == "table", "invalid module registration")
    assert(not self.Modules[name], "duplicate module: " .. name)
    self.Modules[name] = module
end

function NS:Print(text)
    A.Print("Naowh Forever: " .. tostring(text))
end

function NS:Report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

-- True while the integration may do anything: skinning on and its row on.
function NS.Live()
    return A.IsEnabled() and A.IsSwitchedOn("NaowhForever")
end

-------------------------------------------------------------------------------
--  Colour helpers
-------------------------------------------------------------------------------
local Utils = {}
NS.Utils = Utils

function Utils.Rgb(r, g, b)
    return { r = r, g = g, b = b }
end

function Utils.Blend(base, over, alpha)
    return Utils.Rgb(
        base.r + (over.r - base.r) * alpha,
        base.g + (over.g - base.g) * alpha,
        base.b + (over.b - base.b) * alpha
    )
end

function Utils.IsAccessibleFrame(frame)
    if not frame then return false end
    return not (frame.IsForbidden and frame:IsForbidden())
end

-------------------------------------------------------------------------------
--  Settings
-------------------------------------------------------------------------------
local Config = {}
NS.Config = Config

Config.EDGE_MAX = 4
Config.PERCENT = 100
Config.FEATURE_KEYS = {
    "useFont", "useColors", "useShell", "itemPlates", "useEdges", "windowBorders",
    "genericBorders", "itemBorders", "hudBorders", "auraBorders", "focusCastBorder",
    "gcdBorders", "topBarBorders",
}

Config.DEFAULTS = {
    useFont = true,
    useColors = true,
    useShell = true,
    itemPlates = true,
    useEdges = true,
    edgeMode = "actionbars",
    edgeSize = 1,
    edgeR = 0,
    edgeG = 0,
    edgeB = 0,
    windowBorders = true,
    genericBorders = true,
    itemBorders = true,
    hudBorders = true,
    auraBorders = true,
    focusCastBorder = true,
    gcdBorders = true,
    topBarBorders = true,
    borderAlpha = 12,
    buttonBorderAlpha = 30,
}

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

-- The validated settings table: missing or wrongly typed values get their default, numbers clamp.
function Config:Load()
    local root = A.DB()
    if type(root.naowh) ~= "table" then root.naowh = {} end
    local db = root.naowh

    for key, default in pairs(self.DEFAULTS) do
        if type(db[key]) ~= type(default) then db[key] = default end
    end

    db.edgeMode = db.edgeMode == "solid" and "solid" or "actionbars"
    db.edgeSize = Clamp(math.floor(db.edgeSize + 0.5), 0, self.EDGE_MAX)
    db.borderAlpha = Clamp(math.floor(db.borderAlpha + 0.5), 0, self.PERCENT)
    db.buttonBorderAlpha = Clamp(math.floor(db.buttonBorderAlpha + 0.5), 0, self.PERCENT)
    db.edgeR = Clamp(db.edgeR, 0, 1)
    db.edgeG = Clamp(db.edgeG, 0, 1)
    db.edgeB = Clamp(db.edgeB, 0, 1)

    self.db = db
    return db
end

function Config:Get()
    return self.db or self:Load()
end

-- Border size steps, as EllesmereUI.BORDER_LABEL_OF_STEP (copied: this loads before its options).
Config.LABEL_OF_STEP = { [0] = "none", "thin", "normal", "heavy", "strong" }
Config.STEP_OF = { none = 0, thin = 1, normal = 2, heavy = 3, strong = 4 }

-- The manual border, used while "Copy Main Action Bar 1 border" is off (edgeMode "solid"): the
-- option set EllesmereUI's action bars expose for a bar's border, under its keys' meanings.
-- texture: border style key; thickness: size step label; px: exact pixels (EllesmereUI.BorderPx
-- string, or false); r, g, b, a: colour; classColor; offX, offY: width/height offset overrides;
-- shiftX, shiftY; behind: Show Behind. Unset overrides are nil (the style's own defaults).
-- Kept while copying is on; first seeded from the plain edge this page used to set.
function Config:Manual()
    local db = self:Get()
    local m = db.manual
    if type(m) ~= "table" then
        m = { texture = "solid", thickness = self.LABEL_OF_STEP[db.edgeSize] or "thin",
            r = db.edgeR, g = db.edgeG, b = db.edgeB, a = 1, classColor = false, behind = false }
        db.manual = m
    end
    if type(m.texture) ~= "string" or m.texture == "" then m.texture = "solid" end
    if not self.STEP_OF[m.thickness] then m.thickness = "thin" end
    if type(m.px) ~= "string" and type(m.px) ~= "number" then m.px = false end
    for _, key in ipairs({ "r", "g", "b" }) do
        if type(m[key]) ~= "number" then m[key] = 0 end
        m[key] = Clamp(m[key], 0, 1)
    end
    if type(m.a) ~= "number" then m.a = 1 end
    m.a = Clamp(m.a, 0, 1)
    m.classColor = m.classColor == true
    m.behind = m.behind == true
    for _, key in ipairs({ "offX", "offY", "shiftX", "shiftY" }) do
        if type(m[key]) ~= "number" then m[key] = nil end
    end
    return m
end

function Config:Reset()
    local db = self:Get()
    for key, value in pairs(self.DEFAULTS) do db[key] = value end
    db.manual = nil
end

function Config:SetAll(enabled)
    local db = self:Get()
    for _, key in ipairs(self.FEATURE_KEYS) do db[key] = enabled end
    if enabled and db.edgeSize == 0 then db.edgeSize = self.DEFAULTS.edgeSize end
end
