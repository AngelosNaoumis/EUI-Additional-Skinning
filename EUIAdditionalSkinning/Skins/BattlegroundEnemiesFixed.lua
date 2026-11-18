local ADDON, ns = ...

local function DefineSkin()
    ns.RegisterModule("BattlegroundEnemiesFixed", "BattlegroundEnemiesFixed", function()
        local addon = _G.BattleGroundEnemies
        local enemies = _G.BGEEnemies or addon and addon.Enemies
        return addon and enemies and type(enemies.SetupButtonForNewPlayer) == "function"
            and type(enemies.PlayerList) == "table"
    end, function(S, module)
        local H = ns.CreateSkinHelper(ns.StyledFacade(S, "BattlegroundEnemiesFixed"), module)
        local addon = _G.BattleGroundEnemies
        local enemies = _G.BGEEnemies or addon.Enemies
        local bordered = setmetatable({}, {__mode = "k"})
        local divided = setmetatable({}, {__mode = "k"})
        local iconBorders = setmetatable({}, {__mode = "k"})
        local drContainers = setmetatable({}, {__mode = "k"})
        local highlightStates = setmetatable({}, {__mode = "k"})
        local dividerHosts = setmetatable({}, {__mode = "k"})
        local pendingBorders = setmetatable({}, {__mode = "k"})
        local pendingDividers = setmetatable({}, {__mode = "k"})
        local pendingIcons = setmetatable({}, {__mode = "k"})
        local pendingHighlights = setmetatable({}, {__mode = "k"})

        local function Defer(bucket, object)
            bucket[object] = true
            module.combatDeferred = true
        end

        local function Valid(object)
            local kind = type(object)
            return (kind == "table" or kind == "userdata") and type(object.GetObjectType) == "function"
                and not (object.IsForbidden and object:IsForbidden())
        end

        local function Level(host, target, offset)
            if host.SetFrameStrata and target.GetFrameStrata then host:SetFrameStrata(target:GetFrameStrata()) end
            if host.SetFrameLevel and target.GetFrameLevel then
                host:SetFrameLevel(math.min(target:GetFrameLevel() + (offset or 2), 9000))
            end
        end

        -- The unit button itself is secure. Build its decorative host while unprotected, apply the
        -- configured EUI border once, and only then parent/anchor it out of combat. Return the frame
        -- that owns the border so target/focus can recolour that exact border in place.
        local function Border(target)
            if bordered[target] then return bordered[target] end
            if not Valid(target) or type(ns.ApplyConfiguredBorder) ~= "function" then return end
            local protected = target.IsProtected and target:IsProtected()
            if not protected then
                if ns.ApplyConfiguredBorder(target) then
                    bordered[target] = target
                    pendingBorders[target] = nil
                    return target
                end
                if InCombatLockdown and InCombatLockdown() then Defer(pendingBorders, target) end
                return
            end
            if InCombatLockdown and InCombatLockdown() then
                Defer(pendingBorders, target)
                return
            end

            local host = CreateFrame("Frame", nil, UIParent)
            host:EnableMouse(false)
            Level(host, target, 7)
            if not ns.ApplyConfiguredBorder(host) then host:Hide(); return end
            host:SetParent(target)
            host:SetAllPoints(target)
            if ns.OwnFrames then ns.OwnFrames[host] = true end
            bordered[target] = host
            pendingBorders[target] = nil
            return host
        end

        local function PowerDivider(power)
            if divided[power] or not Valid(power) or type(ns.ApplyConfiguredDividerH) ~= "function" then return end
            local protected = power.IsProtected and power:IsProtected()
            if protected and InCombatLockdown and InCombatLockdown() then
                Defer(pendingDividers, power)
                return
            end
            local host = dividerHosts[power]
            if not host then
                host = CreateFrame("Frame", nil, protected and UIParent or power)
                host:EnableMouse(false)
                Level(host, power, 3)
                dividerHosts[power] = host
            end
            if ns.ApplyConfiguredDividerH(host, true) then
                if protected then host:SetParent(power) end
                host:SetAllPoints(power)
                divided[power] = host
                pendingDividers[power] = nil
                if ns.OwnFrames then ns.OwnFrames[host] = true end
            else
                host:Hide()
                if InCombatLockdown and InCombatLockdown() then Defer(pendingDividers, power) end
            end
        end

        local function StyleDR(container)
            if not (Valid(container) and type(container.childFrames) == "table") then return end
            for index = 1, #container.childFrames do Border(container.childFrames[index]) end
        end

        local function ObserveDR(container)
            if not Valid(container) then return end
            StyleDR(container)
            if drContainers[container] then return end
            drContainers[container] = true
            H.Hook(container, "NewInput", function()
                H.Queue(container, function() StyleDR(container) end)
            end)
        end

        local function SafeShown(region)
            if not region then return false end
            local shown
            if type(region.IsVisible) == "function" then shown = region:IsVisible()
            elseif type(region.IsShown) == "function" then shown = region:IsShown()
            else return false end
            if issecretvalue and issecretvalue(shown) then return false end
            return shown and true or false
        end

        local function SelfShown(region)
            if not (region and type(region.IsShown) == "function") then return false end
            local shown = region:IsShown()
            if issecretvalue and issecretvalue(shown) then return false end
            return shown and true or false
        end

        local function VisibleAlpha(region)
            local getter = type(region.GetEffectiveAlpha) == "function" and region.GetEffectiveAlpha
                or region.GetAlpha
            local alpha = type(getter) == "function" and getter(region) or 1
            return type(alpha) == "number" and not (issecretvalue and issecretvalue(alpha)) and alpha > 0
        end

        local function VisibleIcon(container, icon)
            if not SafeShown(container) or not SafeShown(icon)
                or not VisibleAlpha(container) or not VisibleAlpha(icon) then return false end
            if type(icon.GetTexture) ~= "function" then return false end
            local texture = icon:GetTexture()
            if issecretvalue and issecretvalue(texture) then return false end
            return texture ~= nil
        end

        -- Objective/respawn and trinket modules keep their container allocated while their actual
        -- Icon texture is empty or alpha-hidden. Anchor one cached host to that texture and mirror
        -- only its effective visibility, so empty/recycled slots never leave a floating border.
        local function ObserveIcon(container)
            if not Valid(container) then return end
            local icon = container.Icon
            if not Valid(icon) then return end
            local data = iconBorders[container]
            if data and data.icon == icon and data.sync then data.sync(); return end
            if data and data.icon ~= icon then
                data.retired = true
                data.host:Hide()
                data = nil
            end
            local protected = container.IsProtected and container:IsProtected()
                or icon.IsProtected and icon:IsProtected()
            if protected and InCombatLockdown and InCombatLockdown() then
                Defer(pendingIcons, container)
                return
            end

            if not data then
                local host = CreateFrame("Frame", nil, container)
                host:EnableMouse(false)
                Level(host, container, 7)
                host:SetAllPoints(icon)
                data = {icon = icon, host = host}
                iconBorders[container] = data
                if ns.OwnFrames then ns.OwnFrames[host] = true end
            end
            local host = data.host
            if not Border(host) then
                host:Hide()
                if InCombatLockdown and InCombatLockdown() then Defer(pendingIcons, container) end
                return
            end
            pendingIcons[container] = nil
            local function Sync()
                if data.retired then return end
                local shown = VisibleIcon(container, icon)
                if data.shown == shown then return end
                data.shown = shown
                host:SetShown(shown)
            end
            data.sync = Sync
            for _, method in ipairs({"Show", "Hide", "SetShown"}) do
                H.Hook(container, method, Sync)
                H.Hook(icon, method, Sync)
            end
            H.Hook(icon, "SetTexture", Sync)
            H.Hook(icon, "SetAlpha", Sync)
            H.Hook(container, "SetAlpha", Sync)
            Sync()
        end

        local function HighlightColour(key)
            local profile = addon.db and addon.db.profile
            local colour = profile and profile[key]
            if type(colour) ~= "table" then return end
            local r, g, b, a = colour[1], colour[2], colour[3], colour[4]
            if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return end
            if issecretvalue and (issecretvalue(r) or issecretvalue(g) or issecretvalue(b)) then return end
            return r, g, b, type(a) == "number" and a or 1
        end

        local function SyncHighlight(data)
            if type(ns.SetConfiguredBorderColor) ~= "function" then return end
            local kind, r, g, b, a
            if data.target then
                kind = "target"
                r, g, b, a = HighlightColour("MyTarget_Color")
            elseif data.focus then
                kind = "focus"
                r, g, b, a = HighlightColour("MyFocus_Color")
            else
                kind = "normal"
            end
            if data.lastOuter == data.outer and data.lastKind == kind and data.lastR == r
                and data.lastG == g and data.lastB == b and data.lastA == a then return end
            data.lastOuter, data.lastKind = data.outer, kind
            data.lastR, data.lastG, data.lastB, data.lastA = r, g, b, a
            if r then ns.SetConfiguredBorderColor(data.outer, r, g, b, a)
            else ns.SetConfiguredBorderColor(data.outer) end
        end

        local function ObserveHighlight(data, frame, key)
            if not Valid(frame) then return end
            -- Keep BGE's own shown state as the source of truth, but make its extra square
            -- transparent once during setup. Target/focus events then perform colour-only writes
            -- on our unprotected outer host, including during combat.
            if frame.SetAlpha then frame:SetAlpha(0) end
            local function Changed(active)
                data[key] = active
                SyncHighlight(data)
            end
            H.Hook(frame, "Show", function() Changed(true) end)
            H.Hook(frame, "Hide", function() Changed(false) end)
            Changed(SelfShown(frame))
        end

        local function ObserveHighlights(button, outer)
            local data = highlightStates[button]
            if data then data.outer = outer; SyncHighlight(data); return end
            data = {outer = outer, target = false, focus = false}
            highlightStates[button] = data
            ObserveHighlight(data, button.MyTarget, "target")
            ObserveHighlight(data, button.MyFocus, "focus")
            SyncHighlight(data)
        end

        local function StyleAdditionalIcons(button)
            local combat = button.CombatIndicator
            ObserveIcon(button.Trinket)
            ObserveIcon(button.ObjectiveAndRespawn)
            -- Role and RaidTargetIcon deliberately retain their native, unbordered appearance.
            if combat then
                Border(combat.Combat)
                Border(combat.OutOfCombat)
            end
            ObserveDR(button.DRTracking)
        end

        local function StyleButton(button)
            if not Valid(button) or not button.PlayerIsEnemy then return end
            if ns.SkinFeature("BattlegroundEnemiesFixed", "frames") then
                local outer = Border(button)
                if outer then
                    pendingHighlights[button] = nil
                    ObserveHighlights(button, outer)
                elseif InCombatLockdown and InCombatLockdown() then
                    Defer(pendingHighlights, button)
                end
            end
            if ns.SkinFeature("BattlegroundEnemiesFixed", "dividers") then PowerDivider(button.Power) end
            -- BGE uses one SpecClassPriority surface for its class/spec portrait and secure CC
            -- debuff. A single border follows whichever of those mutually exclusive visuals owns it.
            if ns.SkinFeature("BattlegroundEnemiesFixed", "auras") then Border(button.SpecClassPriority) end
            if ns.SkinFeature("BattlegroundEnemiesFixed", "icons") then StyleAdditionalIcons(button) end
            -- Castbars are intentionally untouched and remain wholly owned by BGE.
        end

        local function StyleExisting()
            local list = enemies.PlayerList
            for index = 1, #list do StyleButton(list[index]) end
        end

        -- Only operations that could not safely create/attach decoration in combat reach this path.
        -- Existing hosts, visibility hooks and colour-only updates never wait for it.
        local function FlushDeferred()
            module.combatDeferred = nil
            for target in pairs(pendingBorders) do
                pendingBorders[target] = nil
                Border(target)
            end
            for power in pairs(pendingDividers) do
                pendingDividers[power] = nil
                PowerDivider(power)
            end
            for container in pairs(pendingIcons) do
                pendingIcons[container] = nil
                ObserveIcon(container)
            end
            for button in pairs(pendingHighlights) do
                pendingHighlights[button] = nil
                local outer = Border(button)
                if outer then ObserveHighlights(button, outer) end
            end
        end

        H.Hook(enemies, "SetupButtonForNewPlayer", function(self)
            local list = self.PlayerList
            StyleButton(list and list[#list])
        end)
        module.refresh = StyleExisting
        module.flushCombatDeferred = FlushDeferred
        StyleExisting()
    end)
end

if ns.RegisterSkinDefinition then ns.RegisterSkinDefinition("BattlegroundEnemiesFixed", DefineSkin)
else DefineSkin() end
