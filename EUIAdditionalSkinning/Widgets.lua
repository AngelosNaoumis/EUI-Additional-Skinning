local ADDON, ns = ...

-- The helper H every skin gets: queue, scoped walk, hooks, fades, fonts. Walks only the skin's roots, never UIParent.
function ns.CreateSkinHelper(S, module)
    local H = {}
    local known, hooks, shells, tabs = {}, {}, {}, {}
    local pending, queued = {}, false
    local failures = {}
    local empty, faded, scrolls = {}, {}, {}
    -- A frame's children as a list (a shared empty list when it has none).
    function H.Children(f)
        if f.GetNumChildren and f:GetNumChildren() == 0 then return empty end
        return {f:GetChildren()}
    end
    -- A frame's regions as a list (a shared empty list when it has none).
    function H.Regions(f)
        if f.GetNumRegions and f:GetNumRegions() == 0 then return empty end
        return {f:GetRegions()}
    end
    -- A real UI object that is neither forbidden nor protected, nor one of this addon's own border
    -- frames (ns.OwnFrames, Naowh Runtime.lua); check before touching any frame. A scan stops there,
    -- so a skin never styles our borders (Attune painted an EllesmereUI window border's backdrop
    -- frame, raised above the window's content, as a panel: the dark overlay; local change).
    function H.Allowed(f)
        local kind = type(f)
        return (kind == "table" or kind == "userdata") and type(f.GetObjectType) == "function"
            and not (ns.OwnFrames and ns.OwnFrames[f])
            and not (f.IsForbidden and f:IsForbidden())
            and not (f.IsProtected and f:IsProtected())
    end
    -- Call fn, reporting each distinct error once instead of breaking the caller.
    function H.Safe(fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok and not failures[tostring(err)] then
            failures[tostring(err)] = true
            geterrorhandler()(ADDON .. ": " .. tostring(err))
        end
    end
    -- Post-hook object.name once; runs only while the skin is enabled, errors isolated.
    function H.Hook(object, name, callback)
        local kind = type(object)
        if (kind ~= "table" and kind ~= "userdata") or type(object[name]) ~= "function" then return end
        local h = hooks[object]
        if not h then h = {}; hooks[object] = h end
        if h[name] then return end
        h[name] = true
        hooksecurefunc(object, name, function(...)
            if ns.IsEnabled(module) then H.Safe(callback, ...) end
        end)
    end
    -- Post-hook a frame script once (HookScript, never SetScript); enabled-only, errors isolated.
    function H.Script(f, name, callback)
        if not H.Allowed(f) or not f.HookScript then return end
        if f.HasScript and not f:HasScript(name) then return end
        local h = hooks[f]
        if not h then h = {}; hooks[f] = h end
        local key = "script:" .. name
        if h[key] then return end
        h[key] = true
        f:HookScript(name, function(...)
            if ns.IsEnabled(module) then H.Safe(callback, ...) end
        end)
    end
    -- Run callback once on the next frame, coalescing repeats under key (C.refresh uses this).
    function H.Queue(key, callback)
        if not ns.IsEnabled(module) then return end
        pending[key] = callback
        if queued then return end
        queued = true
        C_Timer.After(0, function()
            queued = false
            local batch = pending; pending = {}
            if not ns.IsEnabled(module) then return end
            for key, fn in pairs(batch) do
                -- A queued full skin pass already covers scroll subtrees.
                if not (batch[module] and scrolls[key]) then H.Safe(fn) end
            end
        end)
    end
    -- Alpha 0, kept at 0 if the target re-shows it. Never Hide another addon's art.
    function H.Fade(texture)
        local kind = type(texture)
        if (kind ~= "table" and kind ~= "userdata") or type(texture.SetAlpha) ~= "function" then return end
        if not texture.GetAlpha or texture:GetAlpha() ~= 0 then texture:SetAlpha(0) end
        if faded[texture] then return end
        faded[texture] = true
        local lock = false
        H.Hook(texture, "SetAlpha", function(_, value)
            if value == 0 or lock then return end
            lock = true; texture:SetAlpha(0); lock = false
        end)
    end
    -- Fonts are re-checked on every pass; re-apply only when the EUI font, its
    -- flags or the requested colour are not already in place.
    function H.Font(text, r, g, b)
        if not (H.Allowed(text) and text:GetObjectType() == "FontString") then return end
        if S.GetFont and text.GetFont then
            local path, flags = S.GetFont()
            local current, _, currentFlags = text:GetFont()
            if path and current == path and (currentFlags or "") == (flags or "") then
                if r == nil then return end
                local cr, cg, cb = text:GetTextColor()
                if cr == r and cg == g and cb == b then return end
            end
        end
        S.Font(text, r, g, b)
    end
    -- value when it is a Texture region, else nil.
    function H.Texture(value)
        local kind = type(value)
        if (kind == "table" or kind == "userdata") and H.Allowed(value)
            and value:GetObjectType() == "Texture" then return value end
    end
    -- A button's icon Texture (.icon or .Icon), else nil.
    function H.Icon(f)
        -- Some addons store an asset ID in .icon and the Texture in .Icon.
        return H.Texture(f.icon) or H.Texture(f.Icon)
    end
    -- Themed window shell plus accent bar (options.noAccent: none), once; refresh queued on show.
    function H.Shell(f, refresh, options)
        if not H.Allowed(f) then return end
        if not shells[f] then
            shells[f] = true
            local icons = {}
            for _, region in ipairs(H.Regions(f)) do
                if region.GetTexture then
                    local path = region:GetTexture()
                    if type(path) == "string" and path:lower():find("interface[/\\]icons") then
                        icons[region] = region:GetAlpha()
                    end
                end
            end
            S.Shell(f, options)
            if not (options and options.noAccent) then ns.AttachAccent(S, f) end
            for region, alpha in pairs(icons) do region:SetAlpha(alpha) end
            -- BackdropTemplate backgrounds are separate from the engine's new shell.
            if f.SetBackdrop then f:SetBackdrop(nil) end
            if f.NineSlice then S.FadeNineSlice(f.NineSlice) end
        end
        H.Script(f, "OnShow", refresh)
    end
    -- House tab with an explicit selected state (true, false, or nil for native).
    function H.Tab(f, selected)
        if not H.Allowed(f) or not S.Tab then return false end
        if not tabs[f] then S.Tab(f); tabs[f] = true end
        if S.SetTabSelection then S.SetTabSelection(f, selected) end
        return true
    end
    -- Walk root's tree: auto-style controls by kind, call visit(f, kind), hook refreshes.
    function H.Scan(root, refresh, visit, exclude)
        -- Update existing scroll contexts even when an ancestor becomes excluded.
        for _, context in pairs(scrolls) do
            if context.root == root then
                context.refresh, context.visit, context.exclude = refresh, visit, exclude
            end
        end
        local function walk(f, depth)
            if depth > 16 or not H.Allowed(f) or (exclude and exclude[f]) then return end
            local kind = f:GetObjectType()
            if kind == "GameTooltip" or kind == "PlayerModel" or kind == "ModelScene" then return end
            if kind == "ScrollFrame" then
                local context = scrolls[f]
                if not context then
                    context = {root = root}; scrolls[f] = context
                    context.apply = function() H.Scan(f, context.refresh, context.visit, context.exclude) end
                    H.Script(f, "OnVerticalScroll", function()
                        -- Exclusions can belong to ancestors outside this subtree.
                        if context.exclude then context.refresh() else H.Queue(f, context.apply) end
                    end)
                end
                context.refresh, context.visit, context.exclude = refresh, visit, exclude
            end
            local handled = visit and visit(f, kind)
            if not known[f] then
                known[f] = true
                if handled then -- The skin's visit styled it.
                elseif kind == "StatusBar" and S.ApplyBarFill then
                    S.ApplyBarFill(f)
                    local painting = false
                    H.Hook(f, "SetStatusBarColor", function()
                        if painting then return end
                        painting = true; S.ApplyBarFill(f); painting = false
                    end)
                elseif kind == "CheckButton" then S.Checkbox(f)
                elseif kind == "EditBox" then S.EditBox(f, {padInput = true})
                elseif kind == "DropdownButton" then S.Dropdown(f)
                elseif kind == "Slider" and f.GetThumbTexture and f.GetOrientation and f:GetOrientation() == "VERTICAL" then S.ScrollBar(f)
                elseif kind == "Button" then
                    local label = f.GetFontString and f:GetFontString()
                    -- A real template label identifies an ordinary text button.
                    -- Custom icon/item/quest rows are left to the skin's visit.
                    if label and not f.icon and not f.Icon then
                        S.Button(f); if S.StateButtonLabel then S.StateButtonLabel(f) end
                    elseif f.GetNormalTexture then
                        local t = f:GetNormalTexture()
                        local path = t and t.GetTexture and t:GetTexture()
                        if type(path) == "string" and path:find("UI%-Panel%-MinimizeButton") then S.CloseButton(f) end
                    end
                end
                -- A button the skin's visit claimed is styled already (a faded plus/minus art keyed
                -- Icon must not get a square crop and border box around it; local change).
                local icon = kind == "Button" and not handled and H.Icon(f)
                if S.SquareIcon and icon then
                    -- The optional border surrounds the supplied frame. Only
                    -- use it for square icon controls, never full-width item rows.
                    local square = f.GetWidth and f.GetHeight and f:GetWidth() == f:GetHeight()
                    S.SquareIcon(icon, square and f or nil)
                end
                for _, region in ipairs(H.Regions(f)) do
                    if region:GetObjectType() == "FontString" then S.Font(region) end
                end
                if kind == "Button" or kind == "CheckButton" then
                    H.Script(f, "OnClick", refresh)
                    H.Script(f, "OnEnable", refresh)
                    H.Script(f, "OnDisable", refresh)
                end
                H.Script(f, "OnShow", refresh)
                if kind == "ScrollFrame" then
                    if f.ScrollBar then S.ScrollBar(f.ScrollBar) end
                end
            end
            if S.SortHeaderBar and f.HeaderContainer and f.HeaderContainer.GetChildren then S.SortHeaderBar(f) end

            for _, child in ipairs(H.Children(f)) do walk(child, depth + 1) end
        end
        if ns.IsEnabled(module) then walk(root, 0) end
    end
    -- Legacy controls (backdrop buttons, classic sliders). Preserve actions.
    local actions, sliders = {}, {}
    -- Flat button for backdrop-template buttons, keeping the named regions.
    function H.Action(f, keep)
        if not H.Allowed(f) then return end
        S.Button(f, keep)
        if f.SetBackdrop then
            f:SetBackdrop(nil)
            if not actions[f] then
                actions[f] = true
                H.Hook(f, "SetBackdrop", function(_, value)
                    if value and H.Allowed(f) then f:SetBackdrop(nil) end
                end)
            end
        end
        for _, r in ipairs(H.Regions(f)) do H.Font(r) end
    end
    -- Classic Slider scroll bar: thin track, accent thumb, page arrows.
    function H.LegacySlider(f, keep)
        if not H.Allowed(f) then return end
        if not f.GetThumbTexture then if S.ScrollBar then S.ScrollBar(f) end; return end
        local thumb = f:GetThumbTexture()
        if not thumb then return end
        for _, r in ipairs(H.Regions(f)) do if r ~= thumb and r ~= sliders[f] and r ~= keep and r.GetTexture then H.Fade(r) end end
        if f.SetBackdrop then f:SetBackdrop(nil) end
        local r, g, b = S.GetAccentColor()
        if thumb.SetColorTexture then thumb:SetColorTexture(r, g, b, 0.8) end
        local horizontal = f.GetOrientation and f:GetOrientation() == "HORIZONTAL"
        -- A horizontal slider (a zoom or value slider, not a scroll bar) keeps a compact handle:
        -- its native thumb art is 32x32, which as a solid block covered the value labels.
        if horizontal and thumb.SetSize and thumb.GetWidth and thumb:GetWidth() ~= 8 then thumb:SetSize(8, 14) end
        local track = sliders[f]
        if not track and f.CreateTexture then
            track = f:CreateTexture(nil, "BACKGROUND"); sliders[f] = track
            if horizontal then
                track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(2)
            else
                track:SetPoint("TOP"); track:SetPoint("BOTTOM"); track:SetWidth(2)
            end
        end
        if track then track:SetColorTexture(0.2, 0.2, 0.22, 1) end
        local name = f.GetName and f:GetName()
        local up = f.ScrollUpButton or (name and _G[name .. "ScrollUpButton"])
        local down = f.ScrollDownButton or (name and _G[name .. "ScrollDownButton"])
        if up and S.PageButton then S.PageButton(up, "^") end
        if down and S.PageButton then S.PageButton(down, "v") end
    end
    -- The building blocks in Helpers.lua (Strip, Wash, Glyph, Squared, Pooled, Ace, ...).
    if ns.AddSkinHelpers then ns.AddSkinHelpers(H, S) end
    return H
end

-- Opt-in treatment for owned addon controls. Keep EUI primitives and their
-- fills/hover states; soften only their newly created pixel-border containers.
-- borderless(f): true for controls whose soft edge (and square-icon edge) stays hidden.
function ns.CreateSoftSkin(S, module, borderless)
    local H = ns.CreateSkinHelper(S, module)
    local proxy, inspected, paints = {}, {}, {}
    local function Options(options, inset)
        local out = {}
        for k, v in pairs(options or {}) do out[k] = v end
        out.noBorder = true
        if inset and out.inset == nil then out.inset = true end
        return out
    end
    for _, name in ipairs({"Shell", "Panel", "EditBox"}) do
        if S[name] then
            proxy[name] = function(f, options) return S[name](f, Options(options, name == "Panel")) end
        end
    end
    for _, name in ipairs({"Button", "Dropdown", "Checkbox", "SoftPageButton"}) do
        local method = name == "SoftPageButton" and "PageButton" or name
        if S[method] then
            proxy[name] = function(f, ...)
                if not H.Allowed(f) then return end
                local before
                if not inspected[f] then
                    before = {}
                    for _, child in ipairs(H.Children(f)) do before[child] = true end
                end
                S[method](f, ...)
                if not before then return end
                inspected[f] = true
                for _, child in ipairs(H.Children(f)) do
                    if not before[child] and H.Allowed(child) and child:GetObjectType() == "Frame" then
                        local edges = H.Regions(child)
                        local border = #edges == 4
                        for _, edge in ipairs(edges) do
                            local layer = edge.GetDrawLayer and edge:GetDrawLayer()
                            local w, h = edge.GetWidth and edge:GetWidth(), edge.GetHeight and edge:GetHeight()
                            if not H.Texture(edge) or layer ~= "BORDER" or not w or not h
                                or not ((w > 0 and w <= 4) or (h > 0 and h <= 4)) then border = false; break end
                        end
                        if border then
                            for _, edge in ipairs(edges) do
                                local painting = false
                                local function Paint()
                                    if painting then return end
                                    if InCombatLockdown and InCombatLockdown() then
                                        if module.refresh then module.refresh() end
                                        return
                                    end
                                    painting = true
                                    edge:SetColorTexture(0.055, 0.055, 0.055, borderless and borderless(f) and 0 or 1)
                                    painting = false
                                end
                                paints[#paints + 1] = Paint
                                Paint()
                                H.Hook(edge, "SetColorTexture", Paint)
                            end
                        end
                    end
                end
            end
        end
    end
    if borderless and S.SquareIcon then
        proxy.SquareIcon = function(icon, parent)
            return S.SquareIcon(icon, parent and not borderless(parent) and parent or nil)
        end
    end
    function proxy.RefreshSoftBorders()
        for _, Paint in ipairs(paints) do Paint() end
    end
    -- ScrollBar/PageButton/SquareIcon and accent/status primitives pass through.
    return setmetatable(proxy, {__index = S})
end
