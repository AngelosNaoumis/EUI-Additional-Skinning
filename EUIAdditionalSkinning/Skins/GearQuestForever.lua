local ADDON, ns = ...
-- GearQuest Forever. What is skinned, the frame map and the reasoning: docs/skins/GearQuestForever.md.
local function DefineSkin()
-- Its windows and the panels and menus inside them, by global name.
local WINDOWS = {GearQuestLogFrame = "window", GearQuestSimulateDialog = "window", GearQuestLanguageMenu = "controls"}
local METAL_EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"

ns.Skin("GearQuestForever", {
    label = "GearQuest Forever",
    available = function() local gq = _G.GearQuest; return type(gq) == "table" and gq.Log ~= nil end,
    -- The window is built once (Log:Init) and redrawn by its own methods; each queues one pass.
    setup = function(C)
        local gq = _G.GearQuest
        for _, method in ipairs({"Init", "Show", "Toggle", "Refresh", "SetPageTab", "RefreshSettings",
            "RefreshSimulator", "RefreshLookup", "ToggleSourceFilterMenu", "ToggleSpecPicker",
            "TogglePlayStylePanel", "ShowWeaponMenu", "ShowRangedMenu"}) do
            C.H.Hook(gq.Log, method, C.refresh)
        end
        if gq.Preview then C.H.Hook(gq.Preview, "EnsureDialog", C.refresh) end
    end,
    before = function(C)
        for name, mode in pairs(WINDOWS) do
            local f = _G[name]
            if f then C.AddRoot(f, mode) end
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
