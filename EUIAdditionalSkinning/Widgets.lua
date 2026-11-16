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
    -- Fit the label of a styled text button without changing its geometry.
    function H.FitButtonText(button, options)
        if ns.FitButtonText then return ns.FitButtonText(button, options) end
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
    -- Themed window shell, once; refresh queued on show. AttachAccent is a compatibility no-op:
    -- Additional Skinning windows deliberately have no top-edge accent line.
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

-- Button labels are fitted only for controls a skin passes through S.Button. Each label keeps its
-- font path/flags and intended size; only an oversized label is reduced, never below nine pixels by
-- default. Per-button hooks recalculate after real text/width/font changes, with no global hook or
-- polling. Set button.euiasAllowMultiline (or the label field) for an intentional multiline control.
-- Values are weak too: on Lua 5.1 a weak-key table still retains an entry when its value points
-- back to the key. Hook closures keep live states reachable; dead button/label cycles can collect.
local fittedButtons = setmetatable({}, {__mode = "kv"})
local fittedLabels = setmetatable({}, {__mode = "kv"})
local EMPTY_TEXT_OPTIONS = {}
local DEFAULT_TEXT_PADDING, DEFAULT_MIN_TEXT_SIZE, DEFAULT_ICON_GAP = 8, 9, 4

local function PlainNumber(value)
    return type(value) == "number" and not (issecretvalue and issecretvalue(value))
end

local function ButtonLabel(button)
    if type(button) ~= "table" and type(button) ~= "userdata" then return end
    local label = button.GetFontString and button:GetFontString() or button.Text or button.text
    if label and label.GetObjectType and label:GetObjectType() == "FontString" then return label end
end

local function SetLabelFont(state, path, size, flags)
    if not state.label.SetFont then return end
    state.settingFont = true
    state.label:SetFont(path, size, flags or "")
    state.settingFont = false
end

local function RestoreLabelFont(state)
    if not (state.basePath and state.baseSize) then return end
    local path, size, flags = state.label:GetFont()
    if path ~= state.basePath or size ~= state.baseSize or (flags or "") ~= state.baseFlags then
        SetLabelFont(state, state.basePath, state.baseSize, state.baseFlags)
    end
end

local function RestoreLabelLayout(state)
    local label = state.label
    if state.baseWordWrap ~= nil and label.GetWordWrap and label.SetWordWrap
        and label:GetWordWrap() ~= state.baseWordWrap then label:SetWordWrap(state.baseWordWrap) end
    if state.baseMaxLines ~= nil and label.GetMaxLines and label.SetMaxLines
        and label:GetMaxLines() ~= state.baseMaxLines then label:SetMaxLines(state.baseMaxLines) end
end

local function VisibleIconWidth(state)
    local button = state.button
    local icon = state.icon or button.icon or button.Icon
    if not icon or icon == state.label or not icon.GetWidth then return 0 end
    if icon.IsShown and not icon:IsShown() then return 0 end
    local width = icon:GetWidth()
    if not PlainNumber(width) or width <= 0 then return 0 end
    return width + state.iconGap
end

local function MeasureLabel(label)
    local width
    if label.GetUnboundedStringWidth then width = label:GetUnboundedStringWidth()
    elseif label.GetStringWidth then width = label:GetStringWidth() end
    local height = label.GetStringHeight and label:GetStringHeight()
    return width, height
end

local function FitLabel(state)
    if not state.active or state.settingFont then return end
    local button, label = state.button, state.label
    if InCombatLockdown and InCombatLockdown() and button.IsProtected and button:IsProtected() then return end
    local width, height = button.GetWidth and button:GetWidth(), button.GetHeight and button:GetHeight()
    if not PlainNumber(width) or not PlainNumber(height) or width <= 0 or height <= 0 then return end
    local text = label.GetText and label:GetText()
    if text == nil or issecretvalue and issecretvalue(text) then return end
    text = tostring(text)
    local iconWidth = VisibleIconWidth(state)
    local availableWidth = width - state.padding * 2 - iconWidth
    local availableHeight = height - state.verticalPadding * 2
    if availableWidth <= 0 or availableHeight <= 0 then return end

    local maxLines = label.GetMaxLines and label:GetMaxLines()
    if button.euiasAllowMultiline or label.euiasAllowMultiline
        or PlainNumber(maxLines) and maxLines > 1 then
        RestoreLabelFont(state); RestoreLabelLayout(state)
        button.euiasTextFitSize, button.euiasTextFitOverflow = nil, nil
        state.lastText = nil
        return
    end
    if state.lastText == text and state.lastWidth == availableWidth and state.lastHeight == availableHeight
        and state.lastPath == state.basePath and state.lastSize == state.baseSize
        and state.lastFlags == state.baseFlags and state.lastMin == state.minSize then return end
    local currentHeight = label.GetStringHeight and label:GetStringHeight()
    if height >= 36 and PlainNumber(currentHeight) and currentHeight > state.baseSize * 1.5 then return end

    RestoreLabelFont(state)
    local size = state.baseSize
    local minSize = math.min(size, state.minSize)
    local measuredWidth, measuredHeight = MeasureLabel(label)
    local needsFit = not PlainNumber(measuredWidth) or measuredWidth > availableWidth
        or PlainNumber(measuredHeight) and measuredHeight > availableHeight
    if not needsFit then
        RestoreLabelLayout(state)
        button.euiasTextFitSize, button.euiasTextFitOverflow = size, nil
        state.lastText, state.lastWidth, state.lastHeight = text, availableWidth, availableHeight
        state.lastPath, state.lastSize, state.lastFlags = state.basePath, state.baseSize, state.baseFlags
        state.lastMin = state.minSize
        return
    end
    if label.SetWordWrap then label:SetWordWrap(false) end
    if label.SetMaxLines then label:SetMaxLines(1) end
    measuredWidth, measuredHeight = MeasureLabel(label)
    while size > minSize and (not PlainNumber(measuredWidth) or measuredWidth > availableWidth
        or PlainNumber(measuredHeight) and measuredHeight > availableHeight) do
        size = math.max(minSize, size - 1)
        SetLabelFont(state, state.basePath, size, state.baseFlags)
        measuredWidth, measuredHeight = MeasureLabel(label)
    end
    local overflow = not PlainNumber(measuredWidth) or measuredWidth > availableWidth
        or PlainNumber(measuredHeight) and measuredHeight > availableHeight
    button.euiasTextFitSize = size
    button.euiasTextFitOverflow = overflow or nil
    state.lastText, state.lastWidth, state.lastHeight = text, availableWidth, availableHeight
    state.lastPath, state.lastSize, state.lastFlags = state.basePath, state.baseSize, state.baseFlags
    state.lastMin = state.minSize
end

local function InvalidateFit(state)
    state.lastText = nil
    FitLabel(state)
end

local function HookFit(object, method, callback)
    if object and type(object[method]) == "function" then hooksecurefunc(object, method, callback) end
end

-- Shrink an oversized styled button label to fit its current width and height. Options: padding
-- (horizontal, default 8), verticalPadding (default 2), minSize (default 9), icon and iconGap.
function ns.FitButtonText(button, options)
    local label = ButtonLabel(button)
    if not label or not label.GetFont or not label.SetFont or not label.GetText then return end
    local state = fittedButtons[button]
    if state and state.label ~= label then
        RestoreLabelFont(state); state.active = false; fittedLabels[state.label] = nil; state = nil
    end
    if not state then
        local path, size, flags = label:GetFont()
        if not path or not PlainNumber(size) then return end
        state = {button = button, label = label, active = true, basePath = path, baseSize = size,
            baseFlags = flags or "", baseWordWrap = label.GetWordWrap and label:GetWordWrap(),
            baseMaxLines = label.GetMaxLines and label:GetMaxLines()}
        fittedButtons[button], fittedLabels[label] = state, state
        local changed = function() InvalidateFit(state) end
        HookFit(button, "SetText", changed)
        HookFit(button, "SetWidth", changed)
        HookFit(button, "SetHeight", changed)
        HookFit(button, "SetSize", changed)
        HookFit(label, "SetText", changed)
        local fontChanged = function()
            if state.settingFont or not state.active then return end
            local fontPath, fontSize, fontFlags = label:GetFont()
            if fontPath and PlainNumber(fontSize) then
                state.basePath, state.baseSize, state.baseFlags = fontPath, fontSize, fontFlags or ""
                InvalidateFit(state)
            end
        end
        HookFit(label, "SetFont", fontChanged)
        HookFit(label, "SetFontObject", fontChanged)
    end
    options = options or EMPTY_TEXT_OPTIONS
    state.padding = PlainNumber(options.padding) and math.max(0, options.padding) or DEFAULT_TEXT_PADDING
    state.verticalPadding = PlainNumber(options.verticalPadding) and math.max(0, options.verticalPadding) or 2
    state.minSize = PlainNumber(options.minSize) and math.max(1, options.minSize) or DEFAULT_MIN_TEXT_SIZE
    state.icon, state.iconGap = options.icon, PlainNumber(options.iconGap) and options.iconGap or DEFAULT_ICON_GAP
    FitLabel(state)
    return state
end

local function RestoreFittedLabel(text)
    local state = fittedLabels[text]
    if state and state.active then RestoreLabelFont(state); state.lastText = nil end
    return state
end

-- Button style (Skins page): "window" (the default) keeps EllesmereUI's window button; "gamemenu"
-- draws every button a skin styles through
-- the facade like EllesmereUI's Game Menu buttons: an inset 2px inside the button, filled with the
-- Popup Menu button colour and given its configured border (the calls the Game Menu uses);
-- EllesmereUI's window-button fill and border are hidden, not removed. Each skin can override the default (buttonStyles[id]). Switching is live
-- (ns.RefreshButtonStyle). Without those EllesmereUI calls every button keeps the window style.
local function Valid(style) return style == "gamemenu" or style == "window" end
-- The style for a skin's buttons (id), or the default (no id).
function ns.ButtonStyle(id)
    local db = EUIAdditionalSkinningDB
    local own = id and db and type(db.buttonStyles) == "table" and db.buttonStyles[id]
    if Valid(own) then return own end
    return db and db.buttonStyle == "gamemenu" and "gamemenu" or "window"
end
-- A skin's own setting: "gamemenu", "window", or "default" (follows the default style).
function ns.SkinButtonSetting(id)
    local db = EUIAdditionalSkinningDB
    local own = db and type(db.buttonStyles) == "table" and db.buttonStyles[id]
    return Valid(own) and own or "default"
end

local buttonState = setmetatable({}, {__mode = "k"}) -- button -> applied style
local buttonInsets = setmetatable({}, {__mode = "k"}) -- button -> its Game Menu inset
local buttonOwners = setmetatable({}, {__mode = "k"}) -- button -> the skin id that styled it

local function ButtonParts(btn)
    local E = _G.EllesmereUI
    local bs = E and E._ModuleNS and E._ModuleNS.EllesmereUIBlizzardSkin
    local ws = bs and bs.WSkin
    local data = ws and ws.GetFFD and ws.GetFFD(btn)
    return E, data and data.bg, E and (E.PanelPP or E.PP), data and data.hover
end

local function PaintButton(btn)
    local E, fill, pp, hover = ButtonParts(btn)
    local menu = ns.ButtonStyle(buttonOwners[btn]) == "gamemenu" and E and E._applyBlizzardConfiguredBorder ~= nil
    local style = menu and "gamemenu" or "window"
    if buttonState[btn] == style then return end
    local inset = buttonInsets[btn]
    if menu then
        if not inset then
            -- A new child of a protected button can't be made in combat; the next pass does it.
            if InCombatLockdown and InCombatLockdown() and btn.IsProtected and btn:IsProtected() then return end
            inset = CreateFrame("Frame", nil, btn)
            inset:SetPoint("TOPLEFT", 2, -2)
            inset:SetPoint("BOTTOMRIGHT", -2, 2)
            inset:SetFrameLevel(btn:GetFrameLevel())
            inset:EnableMouse(false)
            inset.bg = inset:CreateTexture(nil, "BACKGROUND", nil, -6)
            inset.bg:SetAllPoints()
            buttonInsets[btn] = inset
            ns.OwnFrames = ns.OwnFrames or setmetatable({}, {__mode = "k"})
            ns.OwnFrames[inset] = true
        end
        local db = EllesmereUIDB
        local c = db and db.popupMenuButtonBackgroundColor or {r = 0.1, g = 0.1, b = 0.1, a = 0.8}
        inset.bg:SetColorTexture(c.r or 0.1, c.g or 0.1, c.b or 0.1, c.a == nil and 0.8 or c.a)
        E._applyBlizzardConfiguredBorder(inset, "popupMenuButton", 1)
        inset:Show()
        -- The hover wash covers the inset only, as on the Game Menu: on the whole button it showed
        -- in the 2px margin around the inset's border (the corners).
        if hover then hover:ClearAllPoints(); hover:SetAllPoints(inset) end
        if fill then fill:SetAlpha(0) end
        if pp and pp.HideBorder then pp.HideBorder(btn) end
    else
        if inset then inset:Hide() end
        if hover and inset then hover:ClearAllPoints(); hover:SetAllPoints(btn) end
        if fill then fill:SetAlpha(1) end
        if pp and pp.ShowBorder and buttonState[btn] then pp.ShowBorder(btn) end
    end
    buttonState[btn] = style
end

-- The facade skin id receives, with S.Button drawing that skin's button style afterwards.
function ns.StyledFacade(S, id)
    if type(S) ~= "table" or type(S.Button) ~= "function" then return S end
    local button, font = S.Button, S.Font
    return setmetatable({Button = function(btn, ...)
        local result = button(btn, ...)
        if type(btn) == "table" and btn.GetObjectType then
            buttonOwners[btn] = id
            PaintButton(btn)
            ns.FitButtonText(btn)
        end
        return result
    end, Font = font and function(text, ...)
        local state = RestoreFittedLabel(text)
        local result = font(text, ...)
        if state then FitLabel(state) end
        return result
    end or nil}, {__index = S})
end

-- Re-draws every styled button in the current style (the Skins page's Button style setting).
function ns.RefreshButtonStyle()
    for btn in pairs(buttonState) do buttonState[btn] = buttonState[btn] and "stale" or nil; PaintButton(btn) end
end
