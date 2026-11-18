local ADDON, ns = ...

local function DefineSkin()
    ns.RegisterModule("DeadlyBossMods", "Deadly Boss Mods", function()
        local DBT = _G.DBT
        return DBT and type(DBT.CreateBar) == "function" and type(DBT.GetBar) == "function"
    end, function(S, module)
        local H = ns.CreateSkinHelper(ns.StyledFacade(S, "DeadlyBossMods"), module)
        local DBT = _G.DBT
        local BORDER_SIDES = {"Top", "Bottom", "Left", "Right"}
        local composites = setmetatable({}, {__mode = "k"})
        local observed = setmetatable({}, {__mode = "k"})

        local function Shown(icon)
            if not H.Allowed(icon) or type(icon.IsShown) ~= "function" then return false end
            local shown = icon:IsShown()
            if issecretvalue and issecretvalue(shown) then return false end
            return shown and true or false
        end

        local function Height(region)
            if not region or type(region.GetHeight) ~= "function" then return 0 end
            local height = region:GetHeight()
            if type(height) ~= "number" or issecretvalue and issecretvalue(height) then return 0 end
            return height
        end

        local function FadeNativeBorder(name)
            for _, side in ipairs(BORDER_SIDES) do H.Fade(_G[name .. "BarBorder" .. side]) end
        end

        local function Divider(data, key, icon, iconOnRight)
            local divider = data[key]
            if not divider then
                divider = CreateFrame("Frame", nil, data.hull)
                divider:SetAllPoints(icon)
                divider:SetFrameLevel(math.min(data.hull:GetFrameLevel() + 2, 9000))
                divider:EnableMouse(false)
                data[key] = divider
                if type(ns.ApplyConfiguredDividerV) == "function" then
                    ns.ApplyConfiguredDividerV(divider, iconOnRight)
                end
                if ns.OwnFrames then ns.OwnFrames[divider] = true end
            end
            divider:Show()
        end

        local function HideDivider(data, key)
            local divider = data[key]
            if divider then divider:Hide() end
        end

        local function Composite(object, frame, bar, icon1, icon2)
            local data = composites[object]
            if not data then
                local hull = CreateFrame("Frame", nil, frame)
                hull:SetFrameLevel(math.min(frame:GetFrameLevel() + 2, 9000))
                hull:EnableMouse(false)
                data = {hull = hull}
                composites[object] = data
                if ns.OwnFrames then ns.OwnFrames[hull] = true end
            end

            local leftShown, rightShown = Shown(icon1), Shown(icon2)
            local left = leftShown and icon1 or bar
            local right = rightShown and icon2 or bar
            local vertical, height = bar, Height(bar)
            local leftHeight = leftShown and Height(icon1) or 0
            local rightHeight = rightShown and Height(icon2) or 0
            if leftHeight > height then vertical, height = icon1, leftHeight end
            if rightHeight > height then vertical = icon2 end

            -- These four anchors follow DBM's own icon/bar anchors during width animation. They
            -- are only rewritten when ApplyStyle changes which pieces are visible or tallest.
            if data.left ~= left or data.right ~= right or data.vertical ~= vertical then
                data.hull:ClearAllPoints()
                data.hull:SetPoint("LEFT", left, "LEFT")
                data.hull:SetPoint("RIGHT", right, "RIGHT")
                data.hull:SetPoint("TOP", vertical, "TOP")
                data.hull:SetPoint("BOTTOM", vertical, "BOTTOM")
                data.left, data.right, data.vertical = left, right, vertical
            end
            if not data.borderTried then
                data.borderTried = true
                data.bordered = type(ns.ApplyConfiguredBorder) == "function" and ns.ApplyConfiguredBorder(data.hull)
            end
            if not data.bordered then data.hull:Hide(); return end
            data.hull:Show()

            if ns.SkinFeature("DeadlyBossMods", "icons") then
                if leftShown then Divider(data, "leftDivider", icon1, false) else HideDivider(data, "leftDivider") end
                if rightShown then Divider(data, "rightDivider", icon2, true) else HideDivider(data, "rightDivider") end
            else
                HideDivider(data, "leftDivider")
                HideDivider(data, "rightDivider")
            end
        end

        local function StyleBar(object)
            -- Secret encounter-timeline bars may carry protected text and textures. DBM keeps a
            -- separate pool for them; leave that pool entirely under DBM's ownership.
            if type(object) ~= "table" or object.isSecret or not H.Allowed(object.frame) then return end
            if not ns.SkinFeature("DeadlyBossMods", "bars") then return end
            local frame = object.frame
            local name = frame:GetName()
            if type(name) ~= "string" then return end
            local bar = _G[name .. "Bar"]
            if not H.Allowed(bar) then return end
            Composite(object, frame, bar, _G[name .. "BarIcon1"], _G[name .. "BarIcon2"])
            FadeNativeBorder(name)
        end

        local function ObserveBar(object)
            if type(object) ~= "table" then return end
            if not observed[object] then
                observed[object] = true
                -- DBM's pooled objects share this prototype. One hook catches icon/layout changes
                -- and lazily-created native edges without touching the frequent timer update path.
                local meta = getmetatable(object)
                local methods = meta and meta.__index
                if type(methods) == "table" and type(methods.ApplyStyle) == "function" then
                    H.Hook(methods, "ApplyStyle", function(bar) StyleBar(bar) end)
                elseif type(object.ApplyStyle) == "function" then
                    H.Hook(object, "ApplyStyle", function() StyleBar(object) end)
                end
            end
            StyleBar(object)
        end

        local function StyleActiveBars()
            if not DBT.GetBarIterator then return end
            local iterator, state, first = DBT:GetBarIterator()
            if not iterator then return end
            for object in iterator, state, first do ObserveBar(object) end
        end

        H.Hook(DBT, "CreateBar", function(_, _, id)
            if issecretvalue and issecretvalue(id) then return end
            ObserveBar(DBT:GetBar(id))
        end)
        module.refresh = StyleActiveBars
        StyleActiveBars()
    end)
end

if ns.RegisterSkinDefinition then ns.RegisterSkinDefinition("DeadlyBossMods", DefineSkin)
else DefineSkin() end
