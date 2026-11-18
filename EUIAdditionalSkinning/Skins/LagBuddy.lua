local ADDON, ns = ...

local function DefineSkin()
    ns.RegisterModule("LagBuddy", "LagBuddy", function()
        return ns.AddOnLoaded("LagBuddy") and SlashCmdList and type(SlashCmdList.LAGBUDDY) == "function"
    end, function(S, module)
        S = ns.StyledFacade(S, "LagBuddy")
        local H = ns.CreateSkinHelper(S, module)
        local roots, controls = setmetatable({}, {__mode = "k"}), setmetatable({}, {__mode = "k"})
        local waiting, StyleExisting

        local function Queue()
            H.Queue(module, StyleExisting)
        end

        local function IsResultsButton(frame)
            local label = frame.GetFontString and frame:GetFontString()
            return label and label.GetText and label:GetText() == "Analysis Results"
        end

        local function Walk(frame, repaint)
            if not H.Allowed(frame) or controls[frame] and not repaint then return end
            local fresh = not controls[frame]
            controls[frame] = true
            local kind = frame:GetObjectType()
            local backdrop = frame.GetBackdrop and frame:GetBackdrop()

            if backdrop then
                -- Preserve LagBuddy's semantic green/amber/red states and selected-tab fills, but
                -- replace its thick tooltip chrome with the project's flat one-pixel panel edge.
                H.ThinBackdrop(frame)
            end
            if kind == "StatusBar" and S.ApplyBarFill then
                S.ApplyBarFill(frame)
            elseif kind == "CheckButton" then
                S.Checkbox(frame)
            elseif kind == "EditBox" then
                S.EditBox(frame, {padInput = true})
            elseif kind == "DropdownButton" then
                S.Dropdown(frame)
            elseif kind == "Slider" and frame.GetThumbTexture then
                H.LegacySlider(frame)
            elseif kind == "Button" and not backdrop then
                local label = frame.GetFontString and frame:GetFontString()
                if label then
                    S.Button(frame)
                    if S.StateButtonLabel then S.StateButtonLabel(frame) end
                elseif frame.GetNormalTexture then
                    local texture = frame:GetNormalTexture()
                    local path = texture and texture.GetTexture and texture:GetTexture()
                    if type(path) == "string" and path:find("UI%-Panel%-MinimizeButton") then S.CloseButton(frame) end
                end
            end
            if kind == "ScrollFrame" and H.Allowed(frame.ScrollBar) then S.ScrollBar(frame.ScrollBar) end
            for _, region in ipairs(H.Regions(frame)) do H.Font(region) end

            if fresh and kind == "Button" and IsResultsButton(frame) then
                -- Manual results create the dialog inside OnClick. Automatic completion creates it
                -- before enabling this button. These two structural signals cover both paths
                -- without touching LagBuddy's profiler, metric refresh, countdown or OnUpdate.
                H.Script(frame, "OnClick", Queue)
                H.Script(frame, "OnEnable", Queue)
            end
            for _, child in ipairs(H.Children(frame)) do Walk(child, repaint) end
        end

        local function StyleRoot(frame, repaint)
            if not H.Allowed(frame) then return end
            if not roots[frame] then
                roots[frame] = true
                H.Shell(frame, Queue)
            end
            Walk(frame, repaint)
        end

        StyleExisting = function(repaint)
            if InCombatLockdown and InCombatLockdown() then waiting = true; return end
            waiting = false
            StyleRoot(_G.LagBuddyMainFrame, repaint)
            StyleRoot(_G.LagBuddyGameSettingsFrame, repaint)
            StyleRoot(_G.LagBuddyCaptureResultsFrame, repaint)
        end

        H.Hook(SlashCmdList, "LAGBUDDY", Queue)
        local events = CreateFrame("Frame")
        local REGEN = "PLAYER_" .. "REGEN_ENABLED"
        events:RegisterEvent("PLAYER_LOGIN")
        events:RegisterEvent(REGEN)
        -- lint-allow: setscript by Angelos: private event dispatcher frame, not a target frame
        events:SetScript("OnEvent", function(_, event)
            if ns.IsEnabled(module) and (event ~= REGEN or waiting) then Queue() end
        end)
        module.refresh = Queue
        if S.OnLooksChanged then
            S.OnLooksChanged(function() H.Queue(module, function() StyleExisting(true) end) end)
        end
        Queue()
    end)
end

if ns.RegisterSkinDefinition then ns.RegisterSkinDefinition("LagBuddy", DefineSkin)
else DefineSkin() end
