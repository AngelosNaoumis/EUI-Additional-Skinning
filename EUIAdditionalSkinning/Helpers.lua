local ADDON, ns = ...
-- Building blocks every skin gets on its H: patterns lifted from real skins (SKIN-DEVELOPMENT.md,
-- "Helpers"; docs/API.md lists them). ns.CreateSkinHelper calls this for each skin.
function ns.AddSkinHelpers(H, S)
    local once, washed, glyphs, squared, squaring, pooled, aceChecks = {}, {}, {}, {}, {}, {}, {}
    -- True the first time for this frame and key; for one-off work on a frame.
    function H.Once(f, key)
        local done = once[f]
        if not done then done = {}; once[f] = done end
        if done[key] then return false end
        done[key] = true
        return true
    end
    -- One physical pixel at the frame's scale.
    function H.Pixel(f)
        if PixelUtil and f.GetEffectiveScale then return PixelUtil.GetNearestPixelSize(1, f:GetEffectiveScale(), 1) end
        return 1
    end
    -- Move a frame by an offset, keeping every anchor.
    function H.Shift(f, dx, dy)
        local points = {}
        for index = 1, f:GetNumPoints() do points[index] = {f:GetPoint(index)} end
        f:ClearAllPoints()
        for _, p in ipairs(points) do f:SetPoint(p[1], p[2], p[3], (p[4] or 0) + dx, (p[5] or 0) + dy) end
    end
    -- Foreground art (spinners, icons) on a panel, with its alpha, to restore after a fade.
    function H.Artwork(f)
        local artwork = {}
        for _, region in ipairs(H.Regions(f)) do
            if region.GetTexture and region.GetDrawLayer then
                local layer = region:GetDrawLayer()
                if layer == "ARTWORK" or layer == "OVERLAY" then artwork[region] = region:GetAlpha() end
            end
        end
        return artwork
    end
    -- Text drawn for a light page (parchment, spellbook ink) made readable on EUI's dark panels: a
    -- dark colour (luminance under 0.3) turns white when near-grey, else a light tint of its hue.
    -- Light and coloured text (rarity, class, gold) is left alone. Compared before writing.
    function H.Readable(text)
        if not text or not text.GetTextColor or not text.SetTextColor then return end
        local r, g, b, a = text:GetTextColor()
        if type(r) ~= "number" or (issecretvalue and issecretvalue(r)) then return end
        if r * 0.299 + g * 0.587 + b * 0.114 >= 0.3 then return end
        local high, low = math.max(r, g, b), math.min(r, g, b)
        if high - low < 0.2 or high <= 0 then text:SetTextColor(1, 1, 1, a); return end
        r, g, b = r / high, g / high, b / high
        text:SetTextColor(r + (1 - r) * 0.4, g + (1 - g) * 0.4, b + (1 - b) * 0.4, a)
    end
    -- Strip an inset or list panel to nothing, keeping its foreground art. Once per frame.
    function H.Strip(f)
        if not H.Allowed(f) or not H.Once(f, "strip") then return end
        local artwork = H.Artwork(f)
        S.Inset(f)
        for region, alpha in pairs(artwork) do region:SetAlpha(alpha) end
        if f.SetBackdrop then f:SetBackdrop(nil) end
    end
    -- EUI's results wash: a 2% white fill edged by 1px seams on the top and left. It
    -- sits on a child layer because EUI restrips the frame's own textures. Once per frame.
    function H.Wash(f)
        if not H.Allowed(f) or washed[f] then return washed[f] end
        local layer = CreateFrame("Frame", nil, f)
        layer:SetAllPoints(f); layer:SetFrameLevel(f:GetFrameLevel())
        local fill = layer:CreateTexture(nil, "BACKGROUND")
        fill:SetColorTexture(1, 1, 1, 0.02); fill:SetAllPoints(layer)
        local px = H.Pixel(f)
        local top = layer:CreateTexture(nil, "ARTWORK")
        top:SetColorTexture(0.15, 0.15, 0.15, 1); top:SetHeight(px)
        top:SetPoint("TOPLEFT", f, "TOPLEFT", -px, 0); top:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
        local side = layer:CreateTexture(nil, "ARTWORK")
        side:SetColorTexture(0.15, 0.15, 0.15, 1); side:SetWidth(px)
        side:SetPoint("TOPRIGHT", f, "TOPLEFT", 0, 0); side:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", 0, 0)
        washed[f] = layer
        return layer
    end
    -- Scroll bars of both generations: classic Slider bars, and WowTrimScrollBar whose end
    -- caps sit on the bar itself and whose track art sits on a Background child.
    function H.ScrollBar(bar)
        if not H.Allowed(bar) then return end
        if bar.GetThumbTexture then H.LegacySlider(bar); return end
        if H.Once(bar, "trim") then
            for _, region in ipairs(H.Regions(bar)) do if region.GetTexture then H.Fade(region) end end
            if H.Allowed(bar.Background) then
                for _, region in ipairs(H.Regions(bar.Background)) do if region.GetTexture then H.Fade(region) end end
            end
        end
        S.ScrollBar(bar)
    end
    -- EUI's refresh glyph: the button's own art faded, a desaturated white refresh icon on
    -- top. Without the atlas the button stays native rather than going blank.
    function H.Glyph(button)
        if glyphs[button] or not (H.Allowed(button) and button.CreateTexture) then return glyphs[button] end
        if C_Texture and C_Texture.GetAtlasInfo and not C_Texture.GetAtlasInfo("UI-RefreshButton") then return end
        for _, region in ipairs(H.Regions(button)) do if H.Texture(region) then H.Fade(region) end end
        local glyph = button:CreateTexture(nil, "OVERLAY")
        glyph:SetAtlas("UI-RefreshButton", false); glyph:SetSize(16, 16); glyph:SetPoint("CENTER")
        glyph:SetDesaturated(true); glyph:SetVertexColor(1, 1, 1, 0.9)
        glyphs[button] = glyph
        H.Script(button, "OnEnter", function() glyph:SetVertexColor(1, 1, 1, 1) end)
        H.Script(button, "OnLeave", function() glyph:SetVertexColor(1, 1, 1, 0.9) end)
        return glyph
    end
    -- A square icon inset in its slot, kept square while a pooled button is refilled: the
    -- target re-masks and re-crops the icon on every fill, so its own setters re-apply it.
    local function Square(f, icon, inset)
        if squaring[f] then return end
        squaring[f] = true
        if icon.GetNumMaskTextures then
            for index = icon:GetNumMaskTextures(), 1, -1 do icon:RemoveMaskTexture(icon:GetMaskTexture(index)) end
        end
        if f.IconMask and f.IconMask.Hide then f.IconMask:Hide() end
        icon:ClearAllPoints(); icon:SetPoint("TOPLEFT", inset, -inset); icon:SetPoint("BOTTOMRIGHT", -inset, inset)
        S.SquareIcon(icon, f)
        squaring[f] = nil
    end
    -- Square, inset icon on a pooled button, re-applied whenever the button is refilled.
    function H.Squared(f, icon, inset)
        inset = inset or 2
        if not squared[f] then
            squared[f] = true
            if f.GetNormalTexture and f:GetNormalTexture() then H.Fade(f:GetNormalTexture()) end
            for _, method in ipairs({"SetTexture", "SetAtlas", "AddMaskTexture", "SetTexCoord", "SetAllPoints"}) do
                H.Hook(icon, method, function() Square(f, icon, inset) end)
            end
        end
        Square(f, icon, inset)
    end
    -- Restyle a ScrollBox's rows whenever it refills them (rows are pooled and reused);
    -- only this box is touched, not a whole skin pass.
    function H.Pooled(box, styleRow)
        if not (H.Allowed(box) and box.ForEachFrame) or pooled[box] then return end
        pooled[box] = true
        H.Hook(box, "Update", function() box:ForEachFrame(styleRow) end)
    end
    -- AceGUI widget frames (f.obj.frame == f): style the dropdown or checkbox the widget wraps,
    -- recheck on SetType/SetDisabled. True when f was such a widget; ns.Skin's ace flag uses it.
    function H.Ace(f, refresh)
        local widget = f.obj
        if not (type(widget) == "table" and widget.frame == f) then return false end
        if widget.type == "Dropdown" and H.Allowed(widget.dropdown) then
            S.Dropdown(widget.dropdown)
            if H.Allowed(widget.button) then
                for _, region in ipairs(H.Regions(widget.button)) do if region.GetTexture then H.Fade(region) end end
            end
            return true
        end
        if widget.type == "CheckBox" and widget.checkbg and widget.check then
            widget.checkbg:SetColorTexture(0.02, 0.02, 0.02, 1)
            local r, g, b = S.GetAccentColor()
            if widget.disabled then widget.check:SetVertexColor(0.5, 0.5, 0.5, 1) else widget.check:SetVertexColor(r, g, b, 1) end
            if not aceChecks[f] and f.CreateTexture then
                aceChecks[f] = true
                for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
                    local edge = f:CreateTexture(nil, "ARTWORK")
                    edge:SetColorTexture(0.25, 0.25, 0.25, 1)
                    if side == "TOP" or side == "BOTTOM" then
                        edge:SetPoint(side .. "LEFT", widget.checkbg, side .. "LEFT"); edge:SetPoint(side .. "RIGHT", widget.checkbg, side .. "RIGHT"); edge:SetHeight(1)
                    else
                        edge:SetPoint("TOP" .. side, widget.checkbg, "TOP" .. side); edge:SetPoint("BOTTOM" .. side, widget.checkbg, "BOTTOM" .. side); edge:SetWidth(1)
                    end
                end
                if refresh then H.Hook(widget, "SetType", refresh); H.Hook(widget, "SetDisabled", refresh) end
            end
            H.Font(widget.text)
            return true
        end
        return false
    end
    -- For the scoped skins.
    local thin, toggles, portraits, grips = {}, {}, {}, {}
    local BUTTON_TEXTURES = {"GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture"}
    -- Re-draw a backdrop frame with a 1px flat edge, keeping its colours (and again if the addon resets it).
    function H.ThinBackdrop(f)
        if not H.Allowed(f) or not f.SetBackdrop or not f.GetBackdrop then return end
        local backdrop = f:GetBackdrop()
        if not backdrop then return end -- Spacer nodes intentionally have no fill.
        if backdrop.edgeFile == "Interface/Buttons/WHITE8X8" and backdrop.edgeSize == 1 then return end
        local color = f.GetBackdropColor and {f:GetBackdropColor()}
        local border = f.GetBackdropBorderColor and {f:GetBackdropBorderColor()}
        f:SetBackdrop({bgFile = backdrop.bgFile or "Interface/Buttons/WHITE8X8",
            edgeFile = "Interface/Buttons/WHITE8X8", edgeSize = 1,
            insets = {left = 1, right = 1, top = 1, bottom = 1}})
        local unpack = unpack or table.unpack
        if color and f.SetBackdropColor then f:SetBackdropColor(unpack(color)) end
        if border and f.SetBackdropBorderColor then f:SetBackdropBorderColor(unpack(border)) end
        if not thin[f] then
            thin[f] = true
            H.Hook(f, "SetBackdrop", function(_, value) if value then H.ThinBackdrop(f) end end)
        end
    end
    -- A flat button with an accent fill while selected (tree rows, list entries).
    function H.Selection(f, selected)
        if not H.Allowed(f) then return end
        if not f.euiSelection and f.CreateTexture then
            local fill = f:CreateTexture(nil, "BACKGROUND", nil, 6)
            fill:SetAllPoints(f); f.euiSelection = fill
        end
        H.Action(f, {"icon", "Icon", "euiSelection"})
        if f.euiSelection then
            local r, g, b = S.GetAccentColor()
            f.euiSelection:SetColorTexture(r, g, b, selected and 0.2 or 0)
        end
    end
    -- An expand/collapse button drawn as a "+" or "-" glyph over its faded art.
    function H.Toggle(f, expanded)
        if not H.Allowed(f) then return end
        H.Action(f)
        local text = toggles[f]
        if not text and f.CreateFontString then
            text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal"); toggles[f] = text
            text:SetPoint("CENTER")
        end
        if text then
            H.Font(text, 1, 1, 1)
            text:SetText(expanded and "-" or "+")
        end
        for _, getter in ipairs(BUTTON_TEXTURES) do
            local t = f[getter] and f[getter](f)
            if t then H.Fade(t) end
        end
    end
    -- A window's round portrait replaced by a square one (player = the player's portrait); returns
    -- the icon. size: its side in pixels (default 28), centred in EUI's 25px title strip when it fits.
    function H.Portrait(f, player, noAccent, size)
        if not H.Allowed(f) or InCombatLockdown and InCombatLockdown() then return end
        local pc = f.PortraitContainer
        local original = pc and pc.portrait or f.Portrait or f.portrait
        if type(original) == "table" and not original.GetTexture then original = original.portrait end
        if not original or not original.GetTexture or not f.CreateTexture then return end
        local entry = portraits[f]
        if not entry then
            local icon = f:CreateTexture(nil, "OVERLAY", nil, 6)
            size = size or 28
            icon:SetSize(size, size)
            icon:SetPoint("TOPLEFT", f, "TOPLEFT", 8, size < 25 and -math.floor((25 - size) / 2) or -6)
            entry = {icon = icon}; portraits[f] = entry
        end
        if player and SetPortraitTexture then SetPortraitTexture(entry.icon, "player")
        else entry.icon:SetTexture(original:GetTexture()) end
        entry.icon:SetAlpha(1)
        S.SquareIcon(entry.icon, f)
        if player and entry.icon.SetTexCoord then entry.icon:SetTexCoord(0.2, 0.8, 0.2, 0.8) end
        if pc and pc.GetRegions then
            for _, t in ipairs(H.Regions(pc)) do if t.GetTexture then H.Fade(t) end end
        end
        H.Fade(original)
        -- Our unmasked texture never inherits PortraitFrameTemplate's round mask. AttachAccent is
        -- retained as a compatibility no-op; Additional Skinning windows have no top accent line.
        if not noAccent then ns.AttachAccent(S, f) end
        return entry.icon
    end
    -- A size-grabber's art faded and replaced by a small "+" (force: fade every texture).
    function H.Resize(f, force)
        if not H.Allowed(f) then return end
        local found = force
        for _, region in ipairs(H.Regions(f)) do
            local path = region.GetTexture and region:GetTexture()
            if region.GetTexture and (force or type(path) == "string" and path:find("SizeGrabber")) then H.Fade(region); found = true end
        end
        if not found and not grips[f] then return end
        if not grips[f] and f.CreateFontString then
            local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal"); label:SetPoint("BOTTOMRIGHT", -2, 2)
            H.Font(label, 0.65, 0.65, 0.68)
            label:SetText("+"); grips[f] = label
        end
        if grips[f] then H.Font(grips[f], 0.65, 0.65, 0.68) end
    end
end
