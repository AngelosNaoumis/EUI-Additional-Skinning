local ADDON, ns = ...
-- GearQuest Forever. What is skinned, the frame map and the reasoning: docs/skins/GearQuestForever.md.
local function DefineSkin()
-- Its windows and the panels and menus inside them, by global name.
local WINDOWS = {GearQuestLogFrame = "window", GearQuestSimulateDialog = "window", GearQuestLanguageMenu = "controls"}
local METAL_EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"
local PORTRAIT_X, PORTRAIT_Y = 8, -8
local NATIVE_PORTRAIT_X, NATIVE_PORTRAIT_Y = -6, 7
local alignedWashes = setmetatable({}, {__mode = "k"})
local dragHooked = setmetatable({}, {__mode = "k"})

local function Anchor(frame, point, relative, relativePoint, x, y)
    if not (frame and frame.GetPoint and frame.GetNumPoints and frame.ClearAllPoints and frame.SetPoint) then return end
    local current, currentRelative, currentRelativePoint, currentX, currentY = frame:GetPoint(1)
    if frame:GetNumPoints() == 1 and current == point and currentRelative == relative
        and currentRelativePoint == relativePoint and currentX == x and currentY == y then return end
    frame:ClearAllPoints()
    frame:SetPoint(point, relative, relativePoint, x, y)
end

local function PositionPortrait(frame, guide)
    if not frame then return end
    local portrait = frame.PortraitContainer or frame.gqPortraitHolder
    Anchor(portrait, "TOPLEFT", frame, "TOPLEFT", PORTRAIT_X, PORTRAIT_Y)
    -- GearQuest's transparent guide button and full-size pulse are separate from the portrait
    -- container. Move the existing button with the art; its scripts, tooltip and glow stay intact.
    if guide then Anchor(guide.hit, "TOPLEFT", frame, "TOPLEFT", PORTRAIT_X, PORTRAIT_Y) end
end

local function PositionGuideBubble(guide, frame)
    local bubble = guide and guide.bubble
    if not (bubble and frame and bubble._blX and bubble._blY and UIParent) then return end
    local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if not frameScale or not parentScale or frameScale <= 0 or parentScale <= 0 then return end
    local scale = frameScale / parentScale
    local x = bubble._blX + (PORTRAIT_X - NATIVE_PORTRAIT_X) * scale
    local y = bubble._blY + (PORTRAIT_Y - NATIVE_PORTRAIT_Y) * scale
    Anchor(bubble, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end

local function PositionMainGuideBubble(frame)
    local gq = _G.GearQuest
    PositionGuideBubble(gq and gq.PortraitGuide, frame)
end

local function FillAnimatedButton(button)
    local wash = button and button.introWash
    if not wash or alignedWashes[wash] or not wash.ClearAllPoints or not wash.SetPoint then return end
    alignedWashes[wash] = true
    wash:ClearAllPoints()
    -- Two pixels is the button border. The native five-pixel inset was visibly nested inside the
    -- EUI button fill; this makes the existing animation cover that whole fill without replacing it.
    wash:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    wash:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
end

ns.Skin("GearQuestForever", {
    label = "GearQuest Forever",
    available = function() local gq = _G.GearQuest; return type(gq) == "table" and gq.Log ~= nil end,
    -- The window is built once (Log:Init) and redrawn by its own methods; each queues one pass.
    setup = function(C)
        local gq = _G.GearQuest
        -- SetPageTab synchronously calls one of the refresh methods below. Hooking it as well is
        -- redundant, and its native LayoutSideTabs pass must remain the sole owner of tab geometry.
        for _, method in ipairs({"Init", "Show", "Toggle", "Refresh", "RefreshSettings",
            "RefreshSimulator", "RefreshLookup", "ToggleSourceFilterMenu", "ToggleSpecPicker",
            "TogglePlayStylePanel", "ShowWeaponMenu", "ShowRangedMenu"}) do
            C.H.Hook(gq.Log, method, C.refresh)
        end
        if gq.Preview then C.H.Hook(gq.Preview, "EnsureDialog", C.refresh) end
        if gq.PortraitGuide then
            local function PlaceGuide(_, frame)
                PositionGuideBubble(gq.PortraitGuide, frame or gq.Log.frame)
            end
            C.H.Hook(gq.PortraitGuide, "Begin", PlaceGuide)
            C.H.Hook(gq.PortraitGuide, "Open", PlaceGuide)
        end
    end,
    before = function(C)
        local gq = _G.GearQuest
        for name, mode in pairs(WINDOWS) do
            local f = _G[name]
            if f then
                if name == "GearQuestLogFrame" then
                    PositionPortrait(f, gq and gq.PortraitGuide)
                    PositionGuideBubble(gq and gq.PortraitGuide, f)
                    if not dragHooked[f] then
                        dragHooked[f] = true
                        C.H.Script(f, "OnDragStop", PositionMainGuideBubble)
                    end
                    FillAnimatedButton(f.playStyleBtn)
                    FillAnimatedButton(f.trackBtn)
                end
                C.AddRoot(f, mode)
            end
        end
        -- The simulate dialog re-applies its own backdrop chrome each time it is opened.
        local dialog = _G.GearQuestSimulateDialog
        if dialog and dialog.GetBackdrop and dialog:GetBackdrop() then dialog:SetBackdrop(nil) end
    end,
    visit = function(C, f, kind)
        local H, S = C.H, C.S
        -- Dark text drawn for the parchment (detail, lore) made readable on the dark panels.
        for _, region in ipairs(H.Regions(f)) do
            if region.GetObjectType and region:GetObjectType() == "FontString" then H.Readable(region) end
        end
        local parent = f.GetParent and f:GetParent()
        if kind == "Button" then
            -- The window's X: a close button only (its 32px art would read as an icon button).
            if parent and parent.CloseButton == f then S.CloseButton(f); return true end
            -- Hunt rows and tabs keep GearQuest's own art: their fill shows selection and quality.
            local name = f.GetName and f:GetName()
            if f.gqFill or (name and name:find("^GearQuestLogRow")) then return true end
        end
        if kind == "Slider" and f.GetOrientation and f:GetOrientation() == "HORIZONTAL" then
            H.LegacySlider(f); return true
        end
        -- The parchment under the detail text is faded: the panel shows the shell's dark fill.
        if f.gqParchment and H.Once(f, "parchment") then H.Fade(f.gqParchment) end
        -- Metal-edged panels (list, detail, settings, simulator): the gold tooltip edge becomes a 1px
        -- grey line (EUI's border colour); no fill is added, so nothing can cover the content. The
        -- window's own fallback border frame is dropped (the shell has one). Backdrop menus and
        -- panels with a fill keep their colours with a 1px flat edge.
        if kind == "Frame" and f.GetBackdrop and H.Once(f, "backdrop") then
            local backdrop = f:GetBackdrop()
            if backdrop and backdrop.bgFile then
                H.ThinBackdrop(f)
            elseif backdrop and backdrop.edgeFile == METAL_EDGE then
                if parent and parent.gqOuterBorder == f then
                    f:SetBackdrop(nil)
                else
                    f:SetBackdrop({edgeFile = "Interface/Buttons/WHITE8X8", edgeSize = 1})
                    f:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
                end
            end
        end
    end,
})
end
-- Runs once GearQuest Forever is enabled and loaded (Catalog.lua lists it).
ns.RegisterSkinDefinition("GearQuestForever", DefineSkin)
