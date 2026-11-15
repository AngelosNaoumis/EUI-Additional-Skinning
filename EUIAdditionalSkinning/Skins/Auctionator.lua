local ADDON, ns = ...
-- Auctionator. What is skinned, the frame map and the reasoning: docs/skins/Auctionator.md.
local Headers -- set in build; the style below routes S.SortHeaderBar to it
local function DefineSkin()
ns.Skin("Auctionator", {
    available = function() return _G.Auctionator and _G.Auctionator.Tabs and _G.Auctionator.Tabs.State end,
    events = {"AUCTION_HOUSE_SHOW", "ADDON_LOADED"},
    -- Bordered controls inside the modern auction house, soft ones on AuctionFrame.
    style = function(S, module)
        local raw, soft = S, ns.CreateSoftSkin(S, module)
        return setmetatable({SortHeaderBar = function(list) Headers(list) end, RefreshSoftBorders = soft.RefreshSoftBorders},
            {__index = function(_, key) if _G.AuctionHouseFrame then return raw[key] end return soft[key] end})
    end,
    build = function(C)
        local S, H, refresh = C.S, C.H, C.refresh
        local A = _G.Auctionator

        -- 1. State, keyed by frame (one-off work is marked with H.Once instead)
        local headers, panels, stripAt, itemBorders, radioMarks = {}, {}, {}, {}, {}
        local rowWidths, refreshes, refreshHosts, coppers = {}, {}, {}, {}
        local zoneHost
        local discoveryDirty = true

        -- 2. Context
        local function Modern() return H.Allowed(_G.AuctionHouseFrame) end
        -- A tab panel inside the skinned auction house window gets no shell of its own.
        local function ContentMode() return Modern() and "controls" or "content" end
        -- Follow EUI's auction house style: stock under "off" or the Blizzard/Classic look.
        local function Stock()
            local EUI = _G.EllesmereUI
            if not (_G.AuctionHouseFrame and EUI and EUI.GetBlizzWindowStyle) then return false end
            local style = EUI.GetBlizzWindowStyle("auctionhouse")
            return style == "off" or style == "blizzard"
        end
        local function Remember(f, mode)
            if not f or not f.GetObjectType then return end
            C.AddRoot(f, mode == "content" and ContentMode() or mode)
            refresh()
        end

        -- 3. Panels and tables
        local function Panel(f)
            if H.Allowed(f) and not panels[f] then
                local artwork = H.Artwork(f)
                S.Panel(f)
                panels[f] = artwork
                if f.SetBackdrop then f:SetBackdrop(nil) end
            end
            if type(panels[f]) == "table" then
                for region, alpha in pairs(panels[f]) do region:SetAlpha(alpha) end
            end
        end
        local function Zone(f, wash)
            H.Strip(f)
            if wash then H.Wash(f) end
        end
        local function Row(row)
            if H.Once(row, "row") then
                if row.NormalTexture then H.Fade(row.NormalTexture) end
                if H.Texture(row.HighlightTexture) then row.HighlightTexture:SetColorTexture(1, 1, 1, 0.1) end
                if H.Texture(row.SelectedHighlight) then row.SelectedHighlight:SetColorTexture(1, 1, 1, 0.15) end
            end
            for _, cell in pairs(row.cells) do
                local icon = type(cell) == "table" and H.Texture(cell.Icon)
                if icon and H.Once(cell, "square") then
                    S.SquareIcon(icon)
                    if cell.IconBorder then H.Fade(cell.IconBorder) end
                end
            end
        end
        local function RowIfCells(row) if row.cells then Row(row) end end
        -- Header strip spanning the table's row area, so header and wash share corners.
        Headers = function(list)
            local container = list.HeaderContainer
            if not H.Allowed(container) or not container.CreateTexture then return end
            if not headers[container] then
                local strip = container:CreateTexture(nil, "BACKGROUND", nil, 1)
                strip:SetColorTexture(0.02, 0.02, 0.02, 0.5); strip:SetAllPoints(container)
                headers[container] = strip
            end
            local area = H.Allowed(list.ScrollArea) and list.ScrollArea or list
            local left, right, rowLeft, rowRight
            if area.GetLeft and container.GetLeft then
                left, right, rowLeft, rowRight = area:GetLeft(), area:GetRight(), container:GetLeft(), container:GetRight()
            end
            local at = stripAt[container]
            if left and right and rowLeft and rowRight
                and not (at and at[1] == left - rowLeft and at[2] == right - rowRight) then
                if not at then at = {}; stripAt[container] = at end
                at[1], at[2] = left - rowLeft, right - rowRight
                local strip = headers[container]
                strip:ClearAllPoints()
                strip:SetPoint("TOPLEFT", container, "TOPLEFT", at[1], 0)
                strip:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", at[2], 0)
            end
            for _, column in ipairs(H.Children(container)) do
                if H.Allowed(column) and column:GetObjectType() == "Button" then
                    if not headers[column] and column.CreateTexture then
                        for _, key in ipairs({"Left", "Middle", "Right"}) do H.Fade(column[key]) end
                        for _, region in ipairs(H.Regions(column)) do if H.Texture(region) then H.Fade(region) end end
                        local hover = column:CreateTexture(nil, "HIGHLIGHT")
                        hover:SetColorTexture(1, 1, 1, 0.1); hover:SetAllPoints(column)
                        headers[column] = hover
                    end
                    local label = column.GetFontString and column:GetFontString()
                    if label and S.White then S.White(label) end
                end
            end
            H.Pooled(list.ScrollArea and list.ScrollArea.ScrollBox, RowIfCells)
        end

        -- 4. Controls
        -- Inside one of Auctionator's settings frames (AuctionatorConfig*Frame); answered once per frame.
        local configs = setmetatable({}, {__mode = "k"})
        local function IsConfig(f)
            local known = configs[f]
            if known ~= nil then return known end
            local node = f
            known = false
            for _ = 1, 16 do
                if not H.Allowed(node) then break end
                local name = node.GetName and node:GetName()
                if type(name) == "string" and name:match("^AuctionatorConfig.*Frame$") then known = true; break end
                node = node.GetParent and node:GetParent()
            end
            configs[f] = known
            return known
        end
        local function Radio(button)
            if not H.Allowed(button) then return end
            S.Checkbox(button)
            if not button.CreateTexture or not button.GetChecked then return end
            if not radioMarks[button] then
                local mark = button:CreateTexture(nil, "OVERLAY", nil, 7)
                mark:SetSize(6, 6); mark:SetPoint("CENTER"); radioMarks[button] = mark
                if button.GetCheckedTexture then H.Fade(button:GetCheckedTexture()) end
                if button.GetDisabledCheckedTexture then H.Fade(button:GetDisabledCheckedTexture()) end
                H.Hook(button, "SetChecked", function() Radio(button) end)
                H.Script(button, "OnClick", function() Radio(button) end)
            end
            local r, g, b = S.GetAccentColor()
            radioMarks[button]:SetColorTexture(r, g, b, 1)
            radioMarks[button]:SetShown(button:GetChecked() and true or false)
        end
        -- Item buttons: square icon plus a 1px ring in the item's quality colour.
        local function Item(f, icon)
            local modern = Modern()
            local border = H.Texture(f.IconBorder)
            if border and not itemBorders[f] and f.CreateTexture then
                local lines = {}
                for _, side in ipairs({"Top", "Bottom", "Left", "Right"}) do
                    local line = f:CreateTexture(nil, "OVERLAY", nil, 6)
                    f["euiQuality" .. side] = line; lines[#lines + 1] = line
                    if modern then
                        if side == "Top" then line:SetPoint("BOTTOMLEFT", icon, "TOPLEFT", -1, 0); line:SetPoint("BOTTOMRIGHT", icon, "TOPRIGHT", 1, 0)
                        elseif side == "Bottom" then line:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", -1, 0); line:SetPoint("TOPRIGHT", icon, "BOTTOMRIGHT", 1, 0)
                        elseif side == "Left" then line:SetPoint("TOPRIGHT", icon, "TOPLEFT", 0, 1); line:SetPoint("BOTTOMRIGHT", icon, "BOTTOMLEFT", 0, -1)
                        else line:SetPoint("TOPLEFT", icon, "TOPRIGHT", 0, 1); line:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 0, -1) end
                        if side == "Top" or side == "Bottom" then line:SetHeight(1) else line:SetWidth(1) end
                    elseif side == "Top" or side == "Bottom" then
                        local edge = side:upper(); line:SetPoint(edge .. "LEFT"); line:SetPoint(edge .. "RIGHT"); line:SetHeight(1)
                    else
                        local edge = side:upper(); line:SetPoint("TOP" .. edge); line:SetPoint("BOTTOM" .. edge); line:SetWidth(1)
                    end
                end
                itemBorders[f] = lines
                H.Hook(border, "SetVertexColor", function() Item(f, icon) end)
            end
            -- Keep regions are registered after creation so EUI's restrip leaves them.
            H.Action(f, {"Icon", "icon", "IconSelectedHighlight", "Highlight",
                "euiQualityTop", "euiQualityBottom", "euiQualityLeft", "euiQualityRight"})
            icon:SetAlpha(1)
            if modern then H.Squared(f, icon) else S.SquareIcon(icon, f) end
            if H.Texture(f.EmptySlot) then H.Fade(f.EmptySlot) end
            H.Fade(border)
            if itemBorders[f] and border.GetVertexColor then
                local r, g, b, a = border:GetVertexColor()
                -- Grey and white (poor, common) rings fall back to the black edge.
                local plain = modern and math.max(r, g, b) - math.min(r, g, b) < 0.1
                for _, line in ipairs(itemBorders[f]) do line:SetColorTexture(r, g, b, a or 1); line:SetAlpha(plain and 0 or 1) end
            end
        end
        -- Option widgets wrap a dropdown whose arrow is a child button of its own.
        local function Dropdown(dropdown)
            if not H.Once(dropdown, "dropdown") then return end
            S.Dropdown(dropdown)
            for _, child in ipairs(H.Children(dropdown)) do
                if H.Allowed(child) and child:GetObjectType() == "Button" then
                    for _, region in ipairs(H.Regions(child)) do if H.Texture(region) then H.Fade(region) end end
                end
            end
        end
        -- Per-field reset buttons stay a bare icon (a block reads as a stray box when the icon hides).
        local function Reset(button)
            if not button.CreateTexture or not H.Once(button, "reset") then return end
            local icon = H.Texture(button.texture) or H.Texture(button.Icon)
            for _, region in ipairs(H.Regions(button)) do
                if H.Texture(region) and region ~= icon then H.Fade(region) end
            end
            if icon then icon:SetDrawLayer("OVERLAY") end
            local hover = button:CreateTexture(nil, "HIGHLIGHT")
            hover:SetColorTexture(1, 1, 1, 0.1); hover:SetAllPoints(button)
        end
        -- Number inputs draw their text with the EditBox's own font, which the walk (FontStrings only)
        -- never reaches: EUI's font, rewritten only when it differs.
        local function NumberFont(box)
            if not (S.Font and S.GetFont and box.GetFont) then return end
            local path, flags = S.GetFont()
            local current, _, currentFlags = box:GetFont()
            if current ~= path or (currentFlags or "") ~= (flags or "") then S.Font(box) end
        end
        local function Center(box)
            -- Auctionator 341+ wraps the quantity EditBox (Quantity.InputBox); older layouts expose
            -- the EditBox directly.
            if H.Allowed(box) and box:GetObjectType() ~= "EditBox" then box = box.InputBox end
            if not H.Allowed(box) or box:GetObjectType() ~= "EditBox" then return end
            NumberFont(box)
            if not H.Once(box, "center") then return end
            S.EditBox(box)
            box:SetJustifyH("CENTER")
            if box.SetJustifyV then box:SetJustifyV("MIDDLE") end
            box:SetTextInsets(0, 0, 0, 0)
            -- LargeInputBox templates can anchor the shown number on a FontString of their own:
            -- center that rectangle too. Field labels keep their place.
            for _, region in ipairs(H.Regions(box)) do
                if H.Allowed(region) and region:GetObjectType() == "FontString"
                    and region ~= box.Label and region ~= box.label then
                    region:ClearAllPoints()
                    region:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
                    region:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
                    region:SetJustifyH("CENTER")
                    if region.SetJustifyV then region:SetJustifyV("MIDDLE") end
                end
            end
        end
        -- Inner tabs: dark-active, or flat (no plate) where they sit above the main tab row.
        local function InnerTab(tab, selected, flat)
            if Modern() and S.Tab and H.Allowed(tab) and H.Once(tab, "inner") then
                if flat then
                    S.Tab(tab)
                    for _, region in ipairs(H.Regions(tab)) do
                        if H.Texture(region) and region:GetDrawLayer() == "BACKGROUND" then H.Fade(region) end
                    end
                else S.Tab(tab, {darkActive = true}) end
            end
            H.Tab(tab, selected or false)
            if tab.ActiveMarker then H.Fade(tab.ActiveMarker) end
            H.Script(tab, "OnClick", refresh)
        end

        -- 5. Sell form
        local MONEY_KEYS = {"GoldBox", "SilverBox", "CopperBox"}
        -- Coin icons are small square textures on each box; edge art is tall and thin.
        local function Money(f)
            for _, key in ipairs(MONEY_KEYS) do
                local box = f[key]
                if H.Allowed(box) then NumberFont(box) end
                if H.Allowed(box) and H.Once(box, "money") then
                    local coins = {}
                    for _, region in ipairs(H.Regions(box)) do
                        local w, h = region.GetSize and region:GetSize()
                        if H.Texture(region) and w and h and w > 0 and w <= 18 and math.abs(w - h) < 2 then coins[#coins + 1] = region end
                    end
                    S.EditBox(box)
                    local name = box.GetName and box:GetName()
                    if name then for _, suffix in ipairs({"Left", "Middle", "Right"}) do H.Fade(_G[name .. suffix]) end end
                    for _, coin in ipairs(coins) do coin:SetAlpha(1) end
                    -- EUI's sell inputs run 5px shorter than Blizzard's.
                    local height = box.GetHeight and box:GetHeight()
                    if height and height > 5 then box:SetHeight(height - 5) end
                end
            end
            if H.Allowed(f.CopperBox) and H.Once(f, "coppers") then coppers[#coppers + 1] = f.CopperBox end
        end
        -- 4px between a box and the button right of it, measured once the layout exists.
        local function Clear(box, scope)
            if not H.Allowed(box) or not box.GetRight then return end
            local left, right, top, bottom = box:GetLeft(), box:GetRight(), box:GetTop(), box:GetBottom()
            if not (left and right and top and bottom) or not H.Once(box, "clear") then return end
            local gap
            local function find(f, depth)
                for _, child in ipairs(H.Children(f)) do
                    if H.Allowed(child) and child ~= box and child:GetObjectType() == "Button" and child.GetLeft then
                        local l, t, b = child:GetLeft(), child:GetTop(), child:GetBottom()
                        if l and t and b and l > left and l < right + 4 and t > bottom and b < top and (not gap or l - right < gap) then gap = l - right end
                    end
                    if depth < 3 then find(child, depth + 1) end
                end
            end
            find(scope, 0)
            if not gap or gap >= 4 then return end
            local shrink, points, moved = 4 - gap, {}, false
            for index = 1, box:GetNumPoints() do points[index] = {box:GetPoint(index)} end
            for _, p in ipairs(points) do
                if p[1]:find("RIGHT") then p[4] = (p[4] or 0) - shrink; moved = true end
            end
            if moved then
                box:ClearAllPoints()
                for _, p in ipairs(points) do box:SetPoint(p[1], p[2], p[3], p[4] or 0, p[5] or 0) end
            else box:SetWidth(box:GetWidth() - shrink) end
        end
        -- Labels gold as on Blizzard's Sell tab: letters and no digits (values keep their colour).
        local function Gold(f, depth)
            if not H.Allowed(f) or depth > 6 then return end
            local kind = f:GetObjectType()
            if kind == "Button" or kind == "EditBox" or kind == "CheckButton" then return end
            local r, g, b = NORMAL_FONT_COLOR:GetRGB()
            for _, region in ipairs(H.Regions(f)) do
                if region:GetObjectType() == "FontString" then
                    local text = region:GetText()
                    local cr, cg, cb = region:GetTextColor()
                    if type(text) == "string" and text:find("%a") and not text:find("%d") and cr > 0.95 and cg > 0.95 and cb > 0.95 then
                        region:SetTextColor(r, g, b)
                    end
                end
            end
            for _, child in ipairs(H.Children(f)) do Gold(child, depth + 1) end
        end

        -- 6. Layout, measured once the frames exist
        local function AlignTabs(row, first, zone)
            if not (H.Allowed(row) and H.Allowed(first) and H.Allowed(zone)) or not first.GetLeft then return end
            local from, to = first:GetLeft(), zone:GetLeft()
            if not (from and to) or not H.Once(row, "align") then return end
            if math.abs(to - from) > 0.5 then H.Shift(row, to - from, 0) end
        end
        local function SearchGap(f)
            local options, tabs = f.SearchOptions, f.ContainerTabs
            if not (H.Allowed(options) and H.Allowed(options.SearchString) and tabs and H.Allowed(tabs.ListsTab))
                or not options.SearchString.GetBottom then return end
            local bottom, top = options.SearchString:GetBottom(), tabs.ListsTab:GetTop()
            if not (bottom and top) or not H.Once(options, "gap") then return end
            if bottom - top < 6 then H.Shift(options, 0, 6 - (bottom - top)) end
        end
        -- New List / Import / Export: equal widths, 4px apart, inside the lists column.
        local function ListButtons(f)
            local lists, buttons = f.ListsContainer, {f.NewListButton, f.ImportButton, f.ExportButton}
            if not (H.Allowed(lists) and lists.GetWidth) then return end
            for index = 1, 3 do if not H.Allowed(buttons[index]) then return end end
            local width = lists:GetWidth()
            if not width or width <= 8 or rowWidths[lists] == width then return end
            rowWidths[lists] = width
            local previous
            for _, button in ipairs(buttons) do
                button:ClearAllPoints(); button:SetWidth((width - 8) / 3)
                if previous then button:SetPoint("LEFT", previous, "RIGHT", 4, 0)
                else button:SetPoint("TOPLEFT", lists, "BOTTOMLEFT", 0, -6) end
                previous = button
            end
        end
        -- Legacy AuctionFrame: one search row, lists below it.
        local function SearchLayout(f)
            local options = f.SearchOptions
            if not _G.AuctionFrame or not options or not options.SearchLabel or not options.SearchString
                or not options.SearchButton or not options.SearchLabel.ClearAllPoints or not H.Once(f, "layout") then return end
            options.SearchLabel:ClearAllPoints(); options.SearchLabel:SetPoint("TOPLEFT", options, "TOPLEFT", 12, -10)
            options.SearchString:ClearAllPoints(); options.SearchString:SetPoint("LEFT", options.SearchLabel, "RIGHT", 12, 0)
            local previous = options.SearchString
            for _, key in ipairs({"ResetSearchStringButton", "SearchButton", "MoreButton", "AddToListButton", "FullScanButton"}) do
                local button = options[key]
                if H.Allowed(button) and button.ClearAllPoints then
                    button:ClearAllPoints(); button:SetPoint("LEFT", previous, "RIGHT", 6, 0); previous = button
                end
            end
            for _, key in ipairs({"ListsContainer", "RecentsContainer"}) do
                local list = f[key]
                if H.Allowed(list) and list.ClearAllPoints then
                    list:ClearAllPoints(); list:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -84)
                    list:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, key == "ListsContainer" and 35 or 10)
                end
            end
            if H.Allowed(f.ContainerTabs) and f.ListsContainer then
                f.ContainerTabs:ClearAllPoints(); f.ContainerTabs:SetPoint("BOTTOMLEFT", f.ListsContainer, "TOPLEFT", 0, 4)
            end
        end

        -- 7. Refresh buttons: by icon name, or as icon-only buttons on a known panel
        local REFRESH_HOSTS = {"AuctionatorCancellingFrame", "AuctionatorBuyItemFrame", "AuctionatorBuyCommodityFrame"}
        local function RefreshHost(host)
            if not H.Allowed(host) or refreshHosts[host] then return end
            refreshHosts[host] = true
            for _, child in ipairs(H.Children(host)) do refreshes[child] = nil end -- re-ask once the panel is known
        end
        local function PanelRefresh(button)
            if not (H.Allowed(button) and button:GetObjectType() == "Button" and H.Texture(button.Icon)) then return false end
            return not button.IconBorder and not button.EmptySlot and not (button.GetFontString and button:GetFontString())
        end
        local function Named(texture)
            if not H.Texture(texture) then return false end
            local atlas = texture.GetAtlas and texture:GetAtlas()
            local path = texture.GetTexture and texture:GetTexture()
            return type(atlas) == "string" and atlas:find("[Rr]efresh") ~= nil
                or type(path) == "string" and path:find("[Rr]efresh") ~= nil
        end
        local function IsRefresh(button)
            local known = refreshes[button]
            if known == nil then
                local parent = button.GetParent and button:GetParent()
                known = Named(button.Icon) or (button.GetNormalTexture and Named(button:GetNormalTexture()))
                    or (parent and refreshHosts[parent] and PanelRefresh(button)) or false
                refreshes[button] = known
            end
            return known
        end

        -- 8. Modern tab row and EUI's zone seams
        -- EUI's seams live on an unnamed auction house child: two 1px lines, two sub-frames.
        local function Zones(host, hidden)
            if not zoneHost then
                for _, child in ipairs(H.Children(host)) do
                    if child.GetName and not child:GetName() and child.GetNumRegions and child:GetNumRegions() == 2
                        and child.GetNumChildren and child:GetNumChildren() == 2 then
                        local seams = true
                        for _, region in ipairs(H.Regions(child)) do
                            local height = region.GetHeight and region:GetHeight()
                            if not H.Texture(region) or not height or height > 2 then seams = false end
                        end
                        if seams then zoneHost = child; break end
                    end
                end
            end
            if zoneHost and zoneHost:GetAlpha() ~= (hidden and 0 or 1) then zoneHost:SetAlpha(hidden and 0 or 1) end
        end
        local function ModernTabs()
            local host, container = _G.AuctionHouseFrame, _G.AuctionatorAHTabsContainer
            if not (Modern() and container and type(container.Tabs) == "table") then return end
            H.Hook(host, "SetDisplayMode", refresh)
            local previous = host.Tabs and host.Tabs[#host.Tabs]
            local active = false
            for _, tab in ipairs(container.Tabs) do
                if H.Allowed(tab) then
                    local view = tab.frameRef
                    local visible = view and view.IsShown and view:IsShown() or false
                    active = active or visible
                    H.Tab(tab, visible)
                    if previous and H.Once(tab, "chain") then
                        -- One physical pixel apart and 2px shorter, as EUI's own tab rows.
                        if tab.SetHitRectInsets then tab:SetHitRectInsets(0, 0, 0, 0) end
                        local height = tab:GetHeight(); if height and height > 2 then tab:SetHeight(height - 2) end
                        tab:ClearAllPoints(); tab:SetPoint("LEFT", previous, "RIGHT", H.Pixel(tab), 0)
                    end
                    previous = tab
                    H.Script(tab, "OnClick", refresh)
                    if view then H.Script(view, "OnShow", refresh); H.Script(view, "OnHide", refresh) end
                end
            end
            -- Auctionator clears the display mode, which EUI's own tab sync skips.
            if active and S.SetTabSelection then
                for _, tab in ipairs(host.Tabs or {}) do if H.Allowed(tab) then S.SetTabSelection(tab, false) end end
            end
            Zones(host, active)
        end

        -- 9. Visit: every frame under a root, every pass (constant lists live outside it)
        local PRICE_TABS = {"CurrentPricesTab", "PriceHistoryTab", "YourHistoryTab"}
        local LEGACY_TABS = {"HistoryButton", "CurrentPricesButton", "YourHistoryButton"}
        local ICON_BUTTONS = {"RefreshButton", "ResetSearchStringButton"}
        local CLEAR_INSETS = {"ShoppingResultsInset", "HistoricalPriceInset", "BagInset", "ListsContainer", "RecentsContainer"}
        local LEGACY_PANELS = {"ShoppingResultsInset", "BagInset", "HistoricalPriceInset", "ListsContainer", "RecentsContainer", "ScrollArea"}
        local MODERN_FONTS = {"Title", "NoResultsText", "ResultsText"}
        local LEGACY_FONTS = {"Title", "SearchLabel", "Deposit", "Total", "NoResultsText", "ResultsText"}
        local function Visit(_, f, kind)
            local modern = Modern()
            if kind == "Slider" then H.ScrollBar(f); return true end
            -- Settings inputs: the walk's padded EditBox moves the input's hit rectangle away from
            -- where Auctionator's settings canvas put it, so they get the plain one.
            if kind == "EditBox" and IsConfig(f) then S.EditBox(f); return true end
            if headers[f] then return true end
            if f.cells then Row(f); return true end
            if f.isAuctionatorRadio and H.Allowed(f.RadioButton) then Radio(f.RadioButton) end
            local dropdown = H.Allowed(f.DropDown) and f.DropDown:GetObjectType()
            if dropdown == "Button" or dropdown == "DropdownButton" then Dropdown(f.DropDown) end
            if H.Allowed(f.ResetButton) and f.ResetButton:GetObjectType() == "Button" then Reset(f.ResetButton) end
            if kind == "CheckButton" and f.GetParent then
                local parent = f:GetParent()
                if parent and parent.isAuctionatorRadio then Radio(f); return true end
            end
            if kind == "Button" then
                if modern and IsRefresh(f) then H.Glyph(f); return true end
                local icon = H.Icon(f)
                if icon and (f.IconBorder or f.EmptySlot or f.IconSelectedHighlight) then Item(f, icon); return true end
            end
            if modern then
                if f.GoldBox and f.SilverBox then Money(f) end
                Center(f.Quantity)
                ListButtons(f)
                SearchGap(f)
            end
            if f.ListsTab and f.RecentsTab then
                for _, tab in ipairs({f.ListsTab, f.RecentsTab}) do
                    InnerTab(tab, f.selectedTab and tab.GetID and f.selectedTab == tab:GetID())
                end
                H.Hook(f, "SetView", refresh)
            end
            if f.CurrentPricesTab and f.PriceHistoryTab then
                for _, key in ipairs(PRICE_TABS) do
                    local tab = f[key]
                    if H.Allowed(tab) then InnerTab(tab, f.selectedTab and tab.GetID and f.selectedTab == tab:GetID(), true) end
                end
                local panel = f.GetParent and f:GetParent()
                local listing = panel and panel.CurrentPricesListing
                if modern and listing then AlignTabs(f, f.CurrentPricesTab, listing.ScrollArea) end
            end
            for _, key in ipairs(LEGACY_TABS) do
                local button = f[key]
                if H.Allowed(button) then
                    local view = key == "HistoryButton" and f.HistoryPrices or key == "CurrentPricesButton" and f.CurrentPrices or f.YourHistory
                    H.Tab(button, view and view.IsShown and view:IsShown() or false)
                    if view then H.Script(view, "OnShow", refresh); H.Script(view, "OnHide", refresh) end
                end
            end
            for _, key in ipairs(ICON_BUTTONS) do
                local button = f[key]
                if H.Allowed(button) and button:GetObjectType() == "Button" then
                    if modern and key == "RefreshButton" then H.Glyph(button)
                    else
                        local icon = H.Texture(button.GetNormalTexture and button:GetNormalTexture())
                        if icon then
                            button.euiRefreshIcon = icon
                            H.Action(button, {"euiRefreshIcon"}); icon:SetAlpha(1); S.SquareIcon(icon)
                            local r, g, b = S.GetAccentColor(); if icon.SetVertexColor then icon:SetVertexColor(r, g, b) end
                        end
                    end
                end
            end
            SearchLayout(f)
            if modern then
                -- Insets clear; each results table washes its own row area.
                for _, key in ipairs(CLEAR_INSETS) do Zone(f[key]) end
                Zone(f.ScrollArea, f.HeaderContainer ~= nil)
            else
                for _, key in ipairs(LEGACY_PANELS) do Panel(f[key]) end
            end
            for _, key in ipairs(modern and MODERN_FONTS or LEGACY_FONTS) do
                H.Font(f[key], 0.9, 0.9, 0.92)
            end
            if H.Allowed(f.NineSlice) then S.FadeNineSlice(f.NineSlice) end
            if f.Bg then H.Fade(f.Bg) end
            if H.Allowed(f.Border) then
                S.FadeNineSlice(f.Border)
                for _, region in ipairs({f.Border:GetRegions()}) do
                    if region.GetTexture then H.Fade(region) end
                end
            end
            if modern and H.Allowed(f.Inset) then Zone(f.Inset)
            elseif H.Allowed(f.Inset) and not panels[f.Inset] then
                panels[f.Inset] = true
                S.Panel(f.Inset)
                if f.Inset.SetBackdrop then f.Inset:SetBackdrop(nil) end
            end
            if H.Allowed(f.CloseButton) then S.CloseButton(f.CloseButton) end
            H.ScrollBar(f.ScrollBar)
        end

        -- 10. Passes and install
        local TAB_METHODS = {"Selected", "DeselectTab"}
        local DIALOGS = {"AuctionatorShoppingTabItemFrame", "AuctionatorExportListFrame", "AuctionatorImportListFrame", "AuctionatorItemHistoryFrame"}
        local CRAFTING = {"AuctionatorCraftingInfo", "AuctionatorCraftingInfoObjectiveTrackerFrame", "AuctionatorCraftingInfoProfessionsFrame",
            "AuctionatorCraftingInfoProfessionsOrderFrame", "AuctionatorEnchantInfoFrame", "AuctionatorTradeSkillSearch"}
        local function Before()
            local active = false
            for _, details in ipairs(A.Tabs.State.knownTabs or {}) do
                local f = _G[details.tabFrameName]
                if f then C.AddRoot(f, ContentMode()) end
                local tab = _G["AuctionatorTabs_" .. details.name]
                if H.Allowed(tab) then
                    local visible = f and f.IsShown and f:IsShown()
                        and (not tab.wrapperFrame or not tab.wrapperFrame.IsShown or tab.wrapperFrame:IsShown()) or false
                    active = active or visible
                    H.Tab(tab, visible)
                    for _, method in ipairs(TAB_METHODS) do H.Hook(tab, method, refresh) end
                    H.Script(tab, "OnClick", refresh)
                    if tab.wrapperFrame then C.AddRoot(tab.wrapperFrame, ContentMode()) end
                    if f then H.Script(f, "OnHide", refresh); H.Script(f, "OnShow", refresh) end
                end
            end
            -- Legacy AuctionFrame: its wrapper does not always update selectedTab.
            if _G.AuctionFrame then
                for index = 1, 3 do
                    local tab = _G["AuctionFrameTab" .. index]
                    if H.Allowed(tab) and S.SetTabSelection then
                        if active then S.SetTabSelection(tab, false) else S.SetTabSelection(tab, nil) end
                    end
                end
            end
            ModernTabs()
            local selling = _G.AuctionatorSellingFrame
            for _, name in ipairs(REFRESH_HOSTS) do RefreshHost(_G[name]) end
            RefreshHost(selling and selling.SaleItemFrame)
            -- Config frames: addon-owned globals, searched only when something may have created one.
            if discoveryDirty then
                discoveryDirty = false
                for name, f in pairs(_G) do
                    if type(name) == "string" and name:match("^AuctionatorConfig.*Frame$") and (type(f) == "table" or type(f) == "userdata") then
                        C.AddRoot(f)
                    end
                end
            end
            for _, name in ipairs(DIALOGS) do C.AddRoot(_G[name], "dialog") end
            for _, name in ipairs(CRAFTING) do C.AddRoot(_G[name]) end
            local index = 1
            while _G["AuctionatorDialog" .. index] do
                C.AddRoot(_G["AuctionatorDialog" .. index], "window")
                index = index + 1
            end
        end
        local function After()
            local selling = _G.AuctionatorSellingFrame
            local sale = selling and selling.SaleItemFrame
            if Modern() and H.Allowed(sale) and H.Once(sale, "gold") then Gold(sale, 0) end
            for _, box in ipairs(coppers) do Clear(box, H.Allowed(sale) and sale or box:GetParent()) end
        end
        local function Setup()
            for _, entry in ipairs({
                {"AuctionatorTabContainerMixin", "OnLoad", "controls"},
                {"AuctionatorConfigFrameMixin", "OnLoad", "controls"},
                {"AuctionatorShoppingTabFrameMixin", "OnLoad", "content"},
                {"AuctionatorListExportFrameMixin", "OnLoad", "dialog"},
                {"AuctionatorListImportFrameMixin", "OnLoad", "dialog"},
                {"AuctionatorExportTextFrameMixin", "OnLoad", "dialog"},
            }) do
                H.Hook(_G[entry[1]], entry[2], function(f) Remember(f, entry[3]) end)
            end
            if A.Dialogs then
                for _, method in ipairs({"ShowEditBox", "ShowConfirm", "ShowConfirmAlt", "ShowMoney"}) do
                    H.Hook(A.Dialogs, method, refresh)
                end
            end
            for _, method in ipairs({"Initialize", "InitializeProfessionsFrame", "InitializeCustomerOrdersFrame", "InitializeObjectiveTrackerFrame"}) do
                H.Hook(A.CraftingInfo, method, refresh)
            end
            H.Hook(A.EnchantInfo, "Initialize", refresh)
            H.Hook(LibStub and LibStub("LibAHTab-1-0", true), "CreateTab", refresh)
            H.Hook(A.Config, "InternalInitializeFrames", function() discoveryDirty = true; refresh() end)
            -- Frames whose OnLoad ran before this skin was enabled.
            local shopping = _G.AuctionatorShoppingFrame
            if shopping then
                for _, key in ipairs({"exportCSVDialog", "exportDialog", "importDialog", "itemDialog", "itemHistoryDialog"}) do
                    C.AddRoot(shopping[key], "dialog")
                end
                C.AddRoot(shopping.exportDialog and shopping.exportDialog.copyTextDialog, "dialog")
            end
        end

        return {
            visit = Visit,
            before = Before,
            after = After,
            setup = Setup,
            active = function() return not Stock() end,
            event = function(_, event) if event == "ADDON_LOADED" then discoveryDirty = true end end,
        }
    end,
})
end
if ns.RegisterSkinDefinition then ns.RegisterSkinDefinition("Auctionator", DefineSkin) else DefineSkin() end
