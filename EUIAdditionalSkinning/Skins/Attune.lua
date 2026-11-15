local ADDON, ns = ...
-- Notes: docs/skins/Attune.md.
local function DefineSkin()
ns.RegisterScopedSkin("Attune", "Attune", {
    softBorders = true,
    available = function() return _G.Attune ~= nil end,
    roots = function()
        local result = ns.SkinRoots({"Attune_MainFrame", "AttuneBronzeChrome", "Attune_MainRaidFrame", "Attune_SurveyMenuFrame",
            "Attune_SyncProgress_Frame", "AttuneQuestRewardFrame", "AttuneQuestDetail"})
        -- No footer band (bottomBar): it drew a dark strip under the status line.
        for _, target in ipairs(result) do
            -- AttuneBronzeChrome is a see-through PortraitFrameTemplate laid one level above the
            -- window (Attune_MainFrame, shelled here): a shell on it covered the window's own
            -- level-100 content with a second background and added a second border (local change).
            if target.frame == _G.AttuneBronzeChrome then target.mode = "controls" end
            target.exclude = {}
            if target.frame ~= _G.AttuneBronzeChrome and _G.AttuneBronzeChrome then target.exclude[_G.AttuneBronzeChrome] = true end
            -- Traverse named graph controls; never paint the graph canvas or its lines.
            if target.frame.map then target.exclude[target.frame.map] = true end
        end
        return result
    end,
    hooks = function(C, refresh)
        for _, method in ipairs({"Attune_Frame", "Attune_RaidPlannerFrame", "Attune_ShowQuestRewards", "Attune_ShowQuestDetail",
            "Attune_ShowWebsiteURL", "Attune_UpdateTreeGroup", "Attune_ShowResultList", "Attune_ShowProfileList", "Attune_StartSync", "Attune_RaidPlannerRoster",
            "Attune_CreateNode", "Attune_CreateZoomSlider", "Attune_UpdateWindowPortrait"}) do C.H.Hook(_G, method, refresh) end
    end,
    visit = function(C, f, kind, refresh)
        local H, S = C.H, C.S
        local name = f.GetName and f:GetName() or ""
        if f == _G.AttuneBronzeChrome then
            if f.NineSlice then S.FadeNineSlice(f.NineSlice) end
            if f.CloseButton then S.CloseButton(f.CloseButton) end
            -- 16px, in the gap Attune leaves for the portrait left of its list/grid view toggle (the
            -- band under the title strip), anchored to the toggle so it follows it (local change).
            local icon = H.Portrait(f, false, false, 16)
            local host = f.GetParent and f:GetParent()
            local toggle = host and host.obj and host.obj.attuneViewToggle
            if icon and toggle and C.portraitAnchor ~= toggle then
                C.portraitAnchor = toggle
                icon:ClearAllPoints()
                icon:SetPoint("RIGHT", toggle, "LEFT", -12, 0)
            end
            -- Keep the title's original drag handlers.
        end
        if name:match("^Attune_Node_") then
            H.ThinBackdrop(f)
            for _, r in ipairs(H.Regions(f)) do H.Font(r) end
            return true
        end
        if name:match("^Attune_Icon_") then
            local icon = f.GetNormalTexture and f:GetNormalTexture()
            if icon then S.SquareIcon(icon, f) end
            return true
        end
        local ancestor = f
        while ancestor do
            if ancestor == _G.Attune_GraphRoot then return true end
            ancestor = ancestor.GetParent and ancestor:GetParent()
        end
        if kind == "Slider" then H.LegacySlider(f); return true end
        if f.treeline and f.toggle then
            H.Selection(f, f.selected == true)
            H.Font(f.text)
            local expanded = f.toggle.GetNormalTexture and f.toggle:GetNormalTexture()
            local path = expanded and expanded.GetTexture and expanded:GetTexture()
            H.Toggle(f.toggle, path == 130821 or type(path) == "string" and path:find("MinusButton"))
            if f.obj then H.Hook(f.obj, "RefreshTree", refresh) end
            return true
        end
        local widget = f.obj
        if widget and widget.frame == f then
            local status = widget.statustext and widget.statustext.GetParent and widget.statustext:GetParent()
            -- The status line sits on the window itself: its box's backdrop faded, not painted as a
            -- dark panel along the bottom (local change).
            if status and status.SetBackdropColor and status.GetBackdropColor then
                local _, _, _, a = status:GetBackdropColor()
                if a ~= 0 then
                    status:SetBackdropColor(0, 0, 0, 0)
                    if status.SetBackdropBorderColor then status:SetBackdropBorderColor(0, 0, 0, 0) end
                end
            end
            if status then H.Font(widget.statustext) end
            if widget.sizer_se then
                H.Resize(widget.sizer_se, true)
            end
        end
        H.Resize(f)
    end,
})

end
if ns.RegisterSkinDefinition then ns.RegisterSkinDefinition("Attune", DefineSkin)
else DefineSkin() end
