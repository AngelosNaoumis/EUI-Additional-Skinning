local ADDON, ns = ...
-- Hunter's Field Guide. What is skinned, the frame map and the reasoning: docs/skins/HuntersFieldGuide.md.
local function DefineSkin()
-- Its windows by global name; both movable panels use the EUI panel fill.
local WINDOWS = {FieldGuideFrame = "window", FieldGuideExport = "window"}
local TARGET_PANEL, TOAST_PANEL = "FieldGuideTargetPanel", "FieldGuideToast"
local PANELS = {TARGET_PANEL, TOAST_PANEL}
local NATIVE_BORDER = {"TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "TopLeftCorner",
    "TopRightCorner", "BottomLeftCorner", "BottomRightCorner"}
local PORTRAIT_X, PORTRAIT_Y = 8, -8
local popupPanels = setmetatable({}, {__mode = "k"})

-- BackdropTemplate draws the parchment in Center and its ornate edge in eight named textures.
-- Both panels replace it with the normal dark EUI panel fill. Native regions are alpha-locked so
-- the addon cannot reveal them again. The configured border is owned by the movable panel and
-- therefore follows every visibility, alpha, size, strata and anchor change.
local function StylePopupPanel(H, S, frame, name)
    if not H.Allowed(frame) then return end
    popupPanels[frame] = true
    if name == TARGET_PANEL then
        S.Panel(frame, {noBorder = true})
        H.Fade(frame.Center)
    end
    if name == TOAST_PANEL then
        S.Panel(frame, {noBorder = true})
        H.Fade(frame.Center)
    end
    for _, key in ipairs(NATIVE_BORDER) do H.Fade(frame[key]) end
    if type(ns.ApplyConfiguredBorder) == "function" then ns.ApplyConfiguredBorder(frame) end
end

-- PortraitFrameTemplate seats its PortraitContainer partly outside the top-left corner. The
-- journal's portrait and its home-button hit target are children/anchors of this container, so
-- moving the container preserves both the original masked artwork and the click/tooltip region.
local function PositionPortrait(frame)
    local portrait = frame and frame.PortraitContainer
    if not (portrait and portrait.GetPoint and portrait.GetNumPoints
        and portrait.ClearAllPoints and portrait.SetPoint) then return end
    local point, relative, relativePoint, x, y = portrait:GetPoint(1)
    if portrait:GetNumPoints() == 1 and point == "TOPLEFT" and relative == frame
        and relativePoint == "TOPLEFT" and x == PORTRAIT_X and y == PORTRAIT_Y then return end
    portrait:ClearAllPoints()
    portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", PORTRAIT_X, PORTRAIT_Y)
end

ns.Skin("HuntersFieldGuide", {
    label = "Hunter's Field Guide",
    available = function() return _G.HuntersFieldGuide ~= nil end,
    -- The journal is built once (CreateUI) and redrawn per page; each queues one pass.
    setup = function(C)
        local guide = _G.HuntersFieldGuide
        for _, method in ipairs({"CreateUI", "ToggleUI", "RefreshUI", "OpenBeast", "OpenAbility",
            "OpenJournalSettings", "ShowModel", "CreateTargetPanel", "ShowTargetPanel", "CreateToast",
            "ShowExport", "UpdateFilterButton"}) do
            C.H.Hook(guide, method, C.refresh)
        end
    end,
    before = function(C)
        for name, mode in pairs(WINDOWS) do
            local f = _G[name]
            if f then
                if name == "FieldGuideFrame" then PositionPortrait(f) end
                C.AddRoot(f, mode)
            end
        end
        for _, name in ipairs(PANELS) do
            local panel = _G[name]
            if panel then
                StylePopupPanel(C.H, C.S, panel, name)
                C.AddRoot(panel, "controls")
            end
        end
    end,
    visit = function(C, f, kind)
        local H, S = C.H, C.S
        -- Spellbook ink (dark brown, green, red) made readable on the dark shell, hue kept.
        for _, region in ipairs(H.Regions(f)) do
            if region.GetObjectType and region:GetObjectType() == "FontString" then H.Readable(region) end
        end
        local parent = f.GetParent and f:GetParent()
        -- The panel's native regions, fill choice and configured outer border are handled above.
        -- Claim the root so the generic backdrop rule cannot add a competing 1px edge.
        if popupPanels[f] then return true end
        if kind == "Button" then
            if parent and parent.CloseButton == f then S.CloseButton(f); return true end
            -- Beast entries (spellbook item art), icon tabs and the portrait's home button keep the
            -- journal's own look: their art carries the selection, elite and tamed marks.
            if f.backplate or f.band or f.active or (parent and parent.home == f) then return true end
        end
        -- The category header's spellbook backplate would sit as a brown smear on the shell.
        if f.text and f.GetParent and parent and parent.header == f and H.Once(f, "plate") then
            for _, region in ipairs(H.Regions(f)) do
                if region.GetAtlas and region:GetAtlas() == "spellbook-list-backplate" then H.Fade(region) end
            end
        end
        -- Icon slots and the filter menu: flat 1px edge, their colours kept.
        if kind == "Frame" and f.GetBackdrop and H.Once(f, "backdrop") then
            local backdrop = f:GetBackdrop()
            if backdrop and backdrop.bgFile then H.ThinBackdrop(f) end
        end
    end,
})
end
-- Runs once Hunter's Field Guide is enabled and loaded (Catalog.lua lists it).
ns.RegisterSkinDefinition("HuntersFieldGuide", DefineSkin)
