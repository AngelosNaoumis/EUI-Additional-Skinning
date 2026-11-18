local ADDON, ns = ...

-- Shared configured-border service for standalone skins. The style provider is installed by the
-- border settings runtime, but these frames, caches and lifecycle rules are not owned by (or gated
-- on) any target addon integration.
ns.OwnFrames = ns.OwnFrames or setmetatable({}, {__mode = "k"})

local styleProvider
local borders = setmetatable({}, {__mode = "k"})
local tints = setmetatable({}, {__mode = "k"})
local vertical = setmetatable({}, {__mode = "k"})
local horizontal = setmetatable({}, {__mode = "k"})

function ns.SetConfiguredBorderStyleProvider(provider)
    if type(provider) == "function" then styleProvider = provider end
end

local function Style()
    if not styleProvider then return end
    local style = styleProvider()
    if type(style) ~= "table" or type(style.size) ~= "number" or style.size <= 0 then return end
    return style
end

local function Valid(frame)
    local kind = type(frame)
    return (kind == "table" or kind == "userdata") and type(frame.GetObjectType) == "function"
        and not (frame.IsForbidden and frame:IsForbidden())
        and not (frame.IsProtected and frame:IsProtected())
end

local function BorderFrames(frame)
    local E = _G.EllesmereUI
    local pp = E.PP and E.PP.GetBorders and E.PP.GetBorders(frame)
    local bd = E._bdBorderData and E._bdBorderData[frame]
    return pp, bd
end

local function Paint(frame, colour)
    local E = _G.EllesmereUI
    if not E.SetBorderStyleColor then return end
    local style = colour or Style()
    if style then pcall(E.SetBorderStyleColor, frame, style.r, style.g, style.b, style.a or 1) end
end

-- One configured border per unprotected decorative host. Repeated calls are read-only fast paths.
function ns.ApplyConfiguredBorder(frame)
    if not Valid(frame) then return false end
    if borders[frame] then return true end
    local E, style = _G.EllesmereUI, Style()
    if not style then return false end
    local shown = frame.IsShown and frame:IsShown()
    local ok
    if E.ApplyBorderStyle then
        ok = pcall(E.ApplyBorderStyle, frame, style.size, style.r, style.g, style.b, style.a,
            style.texture, style.offX, style.offY, style.shiftX, style.shiftY, "actionbars",
            style.sizeKey, nil, style.px)
    elseif E.PP and E.PP.CreateBorder then
        ok = pcall(E.PP.CreateBorder, frame, style.r, style.g, style.b, style.a, style.size, "OVERLAY", 7)
    end
    if not ok then return false end
    if shown == false then frame:Hide() end
    borders[frame] = true
    return true
end

-- Recolour an existing shared border without changing its geometry or creating a highlight frame.
-- Passing no colour restores the configured style.
function ns.SetConfiguredBorderColor(frame, r, g, b, a)
    if not borders[frame] then return false end
    local colour
    if type(r) == "number" and type(g) == "number" and type(b) == "number" then
        colour = tints[frame]
        if colour then colour.r, colour.g, colour.b, colour.a = r, g, b, a or 1
        else colour = {r = r, g = g, b = b, a = a or 1}; tints[frame] = colour end
    else
        tints[frame] = nil
    end
    Paint(frame, colour)
    return true
end

local function Divider(frame, cache, side, verticalLine)
    if not Valid(frame) or type(frame.CreateTexture) ~= "function" then return false end
    local data = cache[frame]
    if data and data.side == side then return true end
    local style = Style()
    if not style then return false end
    if not data then
        data = {texture = frame:CreateTexture(nil, "OVERLAY", nil, 7)}
        cache[frame] = data
    end
    local E, texture = _G.EllesmereUI, data.texture
    local placed = false
    if verticalLine and style.texture ~= "solid" and E.PlaceBorderDividerV and E.GetBorderCompanion
        and E.GetBorderCompanion(style.texture, "sepV") then
        placed = pcall(E.PlaceBorderDividerV, texture, frame, side, true, style.texture, style.size,
            style.px, frame:GetEffectiveScale())
    end
    if placed then
        texture:SetVertexColor(style.r, style.g, style.b, style.a)
    else
        local px = (E.PP and E.PP.mult or 1) * math.max(1, style.size)
        texture:SetColorTexture(style.r, style.g, style.b, style.a)
        texture:ClearAllPoints()
        if verticalLine then
            texture:SetPoint("TOP", frame, side and "TOPLEFT" or "TOPRIGHT")
            texture:SetPoint("BOTTOM", frame, side and "BOTTOMLEFT" or "BOTTOMRIGHT")
            texture:SetWidth(px)
        else
            texture:SetPoint("LEFT", frame, side and "TOPLEFT" or "BOTTOMLEFT")
            texture:SetPoint("RIGHT", frame, side and "TOPRIGHT" or "BOTTOMRIGHT")
            texture:SetHeight(px)
        end
    end
    texture:Show()
    data.side = side
    return true
end

function ns.ApplyConfiguredDividerV(frame, iconOnRight)
    return Divider(frame, vertical, iconOnRight and true or false, true)
end

function ns.ApplyConfiguredDividerH(frame, atTop)
    return Divider(frame, horizontal, atTop and true or false, false)
end
