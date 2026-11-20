local ADDON, ns = ...
-- Angler's Field Guide. What is skinned, the frame map and the reasoning: docs/skins/AnglersFieldGuide.md.
local function DefineSkin()
local WINDOWS = {AnglerGuideFrame = "window", AnglerGuideExport = "window"}
local TOAST_PANEL = "AnglerGuideToast"
local NATIVE_BORDER = {"TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "TopLeftCorner",
    "TopRightCorner", "BottomLeftCorner", "BottomRightCorner"}
local PORTRAIT_X, PORTRAIT_Y = 8, -8
local popupPanels = setmetatable({}, {__mode = "k"})

-- The singleton toast uses BackdropTemplate's inset parchment Center and ornate edge. Replace
-- those regions with one owner-sized EUI panel fill and one configured border. Direct ownership
-- makes the border follow every fade, visibility, strata and anchor change without lifecycle hooks.
local function StyleToast(H, S, frame)
    if not H.Allowed(frame) then return end
    popupPanels[frame] = true
    S.Panel(frame, {noBorder = true})
    H.Fade(frame.Center)
    for _, key in ipairs(NATIVE_BORDER) do H.Fade(frame[key]) end
    if type(ns.ApplyConfiguredBorder) == "function" then ns.ApplyConfiguredBorder(frame) end
end

-- The Forever look uses PortraitFrameTemplate; keep its custom masked fishing icon and the home
-- hit target attached to the container while moving the complete unit inside the themed shell.
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

local function KeepsNativeButton(frame, parent, kind)
    -- Catch entries, icon tabs, the portrait home target, favourites and icon choices carry state
    -- in their own art. Page/map arrows and the gear button also keep their native icon states.
    if frame.backplate or frame.band or frame.active or frame.icon or frame.tex or frame.selected
        or (parent and parent.home == frame) then return true end
    if kind == "CheckButton" and parent == _G.AnglerGuideFrame then return true end
    local normal = frame.GetNormalTexture and frame:GetNormalTexture()
    local path = normal and normal.GetTexture and normal:GetTexture()
    return type(path) == "string" and (path:find("UI%-SpellbookIcon%-") or path:find("Gear_64Grey"))
end

ns.Skin("AnglersFieldGuide", {
    label = "Angler's Field Guide",
    available = function() return _G.AnglersFieldGuide ~= nil end,
    setup = function(C)
        local guide = _G.AnglersFieldGuide
        for _, method in ipairs({"CreateUI", "ToggleUI", "RefreshUI", "OpenCatch", "OpenZone",
            "OpenJournalSettings", "CreateToast", "ShowExport", "UpdateFilterButton"}) do
            C.H.Hook(guide, method, C.refresh)
        end
    end,
    before = function(C)
        for name, mode in pairs(WINDOWS) do
            local frame = _G[name]
            if frame then
                if name == "AnglerGuideFrame" then PositionPortrait(frame) end
                C.AddRoot(frame, mode)
            end
        end
        local toast = _G[TOAST_PANEL]
        if toast then
            StyleToast(C.H, C.S, toast)
            C.AddRoot(toast, "controls")
        end
    end,
    visit = function(C, frame, kind)
        local H, S = C.H, C.S
        for _, region in ipairs(H.Regions(frame)) do
            if region.GetObjectType and region:GetObjectType() == "FontString" then H.Readable(region) end
        end
        local parent = frame.GetParent and frame:GetParent()
        if popupPanels[frame] then return true end
        if kind == "Button" or kind == "CheckButton" then
            if parent and (parent.CloseButton == frame or parent.closeButton == frame) then
                S.CloseButton(frame); return true
            end
            if KeepsNativeButton(frame, parent, kind) then return true end
        end
        -- The Forever category header keeps its divider but loses the parchment backplate.
        if frame.text and parent and parent.header == frame and H.Once(frame, "plate") then
            for _, region in ipairs(H.Regions(frame)) do
                if region.GetAtlas and region:GetAtlas() == "spellbook-list-backplate" then H.Fade(region) end
            end
        end
        -- Icon slots and the filter menu keep their fill and receive the standard flat edge.
        if kind == "Frame" and frame.GetBackdrop and H.Once(frame, "backdrop") then
            local backdrop = frame:GetBackdrop()
            if backdrop and backdrop.bgFile then H.ThinBackdrop(frame) end
        end
    end,
})
end

-- Runs once Angler's Field Guide is enabled and loaded (Catalog.lua lists it).
ns.RegisterSkinDefinition("AnglersFieldGuide", DefineSkin)
