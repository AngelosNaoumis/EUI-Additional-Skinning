local ADDON, ns = ...
-- Hunter's Field Guide. What is skinned, the frame map and the reasoning: docs/skins/HuntersFieldGuide.md.
local function DefineSkin()
-- Its windows by global name; the target panel and filter menu are backdrop panels, kept small.
local WINDOWS = {FieldGuideFrame = "window", FieldGuideExport = "window", FieldGuideTargetPanel = "controls"}

ns.Skin("HuntersFieldGuide", {
    label = "Hunter's Field Guide",
    available = function() return _G.HuntersFieldGuide ~= nil end,
    -- The journal is built once (CreateUI) and redrawn per page; each queues one pass.
    setup = function(C)
        local guide = _G.HuntersFieldGuide
        for _, method in ipairs({"CreateUI", "ToggleUI", "RefreshUI", "OpenBeast", "OpenAbility",
            "OpenJournalSettings", "ShowModel", "ShowTargetPanel", "ShowExport", "UpdateFilterButton"}) do
            C.H.Hook(guide, method, C.refresh)
        end
    end,
    before = function(C)
        for name, mode in pairs(WINDOWS) do
            local f = _G[name]
            if f then C.AddRoot(f, mode) end
        end
    end,
    visit = function(C, f, kind)
        local H, S = C.H, C.S
        -- Spellbook ink (dark brown, green, red) made readable on the dark shell, hue kept.
        for _, region in ipairs(H.Regions(f)) do
            if region.GetObjectType and region:GetObjectType() == "FontString" then H.Readable(region) end
        end
        local parent = f.GetParent and f:GetParent()
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
        -- Icon slots, the filter menu, the target panel: flat 1px edge, their colours kept.
        if kind == "Frame" and f.GetBackdrop and H.Once(f, "backdrop") then
            local backdrop = f:GetBackdrop()
            if backdrop and backdrop.bgFile then H.ThinBackdrop(f) end
        end
    end,
})
end
-- Runs once Hunter's Field Guide is enabled and loaded (Catalog.lua lists it).
ns.RegisterSkinDefinition("HuntersFieldGuide", DefineSkin)
