-- Auctionator on the legacy AuctionFrame: wrappers, controls, pooled inventory rows and accents.
local enabled, combat, accent, timers, events = true, false, 0.4, {}, {}
local ns = {IsEnabled = function() return enabled end, AttachAccent = function(_, f) f.accent = true end}
C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end}
InCombatLockdown = function() return combat end
geterrorhandler = function() return function(e) error(e) end end
hooksecurefunc = function(object, name, callback)
    local original = object[name]
    object[name] = function(...)
        local values = table.pack(original(...)); callback(...); return table.unpack(values, 1, values.n)
    end
end
local function texture(kind, parent)
    local t = {kind = kind or 'Texture', alpha = 1, path = 'native', parent = parent, points = {}}
    function t:GetObjectType() return self.kind end
    function t:GetTexture() return self.path end
    function t:SetTexture(v) self.path = v end
    function t:GetAlpha() return self.alpha end
    function t:SetAlpha(v) self.alpha = v end
    function t:GetDrawLayer() return self.layer or 'ARTWORK' end
    function t:SetColorTexture(...) self.color = {...}; self.path = 'solid' end
    function t:SetVertexColor(...) self.color = {...} end
    function t:SetPoint(...) self.points[#self.points + 1] = {...} end
    function t:SetAllPoints() end
    function t:ClearAllPoints() self.points = {} end
    function t:SetShown(v) self.shown = v end
    function t:GetVertexColor() return table.unpack(self.color or {1, 1, 1, 1}) end
    function t:SetSize(w, h) self.width, self.height = w, h end
    function t:SetHeight(h) self.height = h end
    function t:SetWidth(w) self.width = w end
    function t:SetTexCoord(...) self.crop = {...} end
    function t:GetNumMaskTextures() return self.masked and 1 or 0 end
    function t:SetText(s) assert(self.font, "FontString:SetText(): Font not set"); self.text = s end
    function t:GetFont() return self.font, self.font and 12, '' end
    function t:SetFont(v) self.font = v; self.fontWrites = (self.fontWrites or 0) + 1 end
    function t:SetFontObject(v) self.font = v end
    function t:SetTextColor(...) self.textColor = {...} end
    function t:GetTextColor() return table.unpack(self.textColor or {1, 1, 1, 1}) end
    function t:GetParent() return self.parent end
    return t
end
local function frame(kind, name, parent)
    local f = {kind = kind or 'Frame', name = name, parent = parent, regions = {}, children = {}, hooks = {}}
    function f:GetObjectType() return self.kind end
    function f:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = {...} end
    function f:ClearAllPoints() self.points = {} end
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:SetWidth(w) self.width = w end
    function f:GetID() return self.id end
    function f:IsShown() return not self.hidden end
    function f:IsEnabled() return not self.disabled end
    function f:Enable() self.disabled = false end
    function f:Disable() self.disabled = true end
    function f:SetChecked(v) self.checked = v end
    function f:GetChecked() return self.checked end
    function f:GetName() return self.name end
    function f:GetParent() return self.parent end
    function f:IsForbidden() return self.forbidden end
    function f:IsProtected() return self.protected end
    function f:GetChildren() return table.unpack(self.children) end
    function f:GetRegions() return table.unpack(self.regions) end
    function f:HookScript(event, fn) self.hooks[event] = fn end
    function f:RegisterEvent(e) self.events = self.events or {}; self.events[e] = true end
    function f:SetScript(e, fn) self.hooks[e] = fn end
    function f:GetBackdrop() return self.backdrop end
    function f:SetBackdrop(b) assert(not combat); self.backdrop = b; self.color, self.border = {0, 0, 0, 1}, {0, 0, 0, 1} end
    function f:GetBackdropColor() return table.unpack(self.color) end
    function f:GetBackdropBorderColor() return table.unpack(self.border) end
    function f:SetBackdropColor(...) self.color = {...} end
    function f:SetBackdropBorderColor(...) self.border = {...} end
    function f:CreateTexture() local t = texture(nil, self); self.regions[#self.regions + 1] = t; return t end
    function f:CreateFontString(_, _, template) local t = texture('FontString', self); t.font = template; self.regions[#self.regions + 1] = t; return t end
    function f:GetNormalTexture() return self.normal end
    function f:GetWidth() return 24 end
    function f:GetHeight() return 24 end
    function f:GetFontString() return self.label end
    if parent then parent.children[#parent.children + 1] = f end
    if name then _G[name] = f end
    return f
end
CreateFrame = function(kind, name, parent) local f = frame(kind, name, parent); events[#events + 1] = f; return f end
local S = {GetAccentColor = function() return accent, 0.6, 0.7 end}
function S.Font(t, r, g, b) t:SetFont('eui'); if r then t:SetTextColor(r, g, b) end end
function S.Button(f, keys)
    local keep = {}; for _, key in ipairs(keys or {}) do keep[f[key] or false] = true end
    for _, t in ipairs(f.regions) do if t.kind == 'Texture' and not keep[t] then t:SetAlpha(0) end end
    f.button = true
end
function S.SquareIcon(t, parent) if t:GetNumMaskTextures() > 0 then return end; t:SetTexCoord(0.08, 0.92, 0.08, 0.92); t.borderParent = parent end
function S.PageButton(f, label) f.glyph = label end
function S.ScrollBar(f) f.scroll = true end
function S.Panel(f, options) f.panel = true; f.panelOptions = options end
function S.Shell(f, options) f.shell = true; f.shellOptions = options end
function S.Tab(f) f.tab = true end
function S.SetTabSelection(f, selected) f.selected = selected end
function S.CloseButton(f) f.close = true end
function S.Checkbox(f) f.checkbox = true end
function S.EditBox(f, options) f.input = true; f.inputOptions = options end
function S.Dropdown(f) f.dropdown = true end
function S.FadeNineSlice() end
SetPortraitTexture = function(t) t:SetTexture('player-face') end
assert(loadfile('EUIAdditionalSkinning/Widgets.lua'))('EUIAdditionalSkinning', ns)
assert(loadfile('EUIAdditionalSkinning/Helpers.lua'))('EUIAdditionalSkinning', ns)
local function flush()
    while #timers > 0 do local batch = timers; timers = {}; for _, fn in ipairs(batch) do fn() end end
end
local modules = {}
function ns.RegisterModule(id, _, available, install) modules[id] = {available = available, install = install} end
-- Auctionator legacy templates: wrappers, controls and pooled inventory rows.
assert(loadfile('EUIAdditionalSkinning/Skin.lua'))('EUIAdditionalSkinning', ns)
assert(loadfile('EUIAdditionalSkinning/Skins/Auctionator.lua'))('EUIAdditionalSkinning', ns)
AuctionFrame = frame(); AuctionFrame.selectedTab = 1
AuctionFrameTab1 = frame('Button'); AuctionFrameTab2 = frame('Button'); AuctionFrameTab3 = frame('Button')
Auctionator = {Tabs = {State = {knownTabs = {{name = 'Shopping', tabFrameName = 'AuctionatorShoppingFrame'}}}}}
AuctionatorShoppingFrame = frame(); local shopping = AuctionatorShoppingFrame
AuctionatorTabs_Shopping = frame('Button'); local tab = AuctionatorTabs_Shopping
local wrapper = frame(); tab.wrapperFrame = wrapper
wrapper.Title = wrapper:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
tab.Selected = function() wrapper.hidden = false end; tab.DeselectTab = function() wrapper.hidden = true end
shopping.SearchOptions = frame('Frame', nil, shopping); local options = shopping.SearchOptions
options.SearchLabel = options:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
options.SearchString = frame('EditBox', nil, options); options.SearchButton = frame('Button', nil, options)
shopping.ListsContainer = frame('Frame', nil, shopping); shopping.RecentsContainer = frame('Frame', nil, shopping)
shopping.ContainerTabs = frame('Frame', nil, shopping); local mini = shopping.ContainerTabs
mini.ListsTab = frame('Button', nil, mini); mini.ListsTab.id = 1
mini.RecentsTab = frame('Button', nil, mini); mini.RecentsTab.id = 2
mini.selectedTab = 2; mini.SetView = function(self, id) self.selectedTab = id end
shopping.Refresh = function() return 'native-refresh-result' end
local results = frame('Frame', nil, shopping); results.ScrollBar = frame('Frame', nil, results)
local cap = results.ScrollBar:CreateTexture()
results.ScrollArea = frame('Frame', nil, results); local spinner = results.ScrollArea:CreateTexture(); spinner.layer = 'OVERLAY'
local radio = frame('Frame', nil, shopping); radio.isAuctionatorRadio = true
radio.RadioButton = frame('CheckButton', nil, radio); radio.RadioButton.checked = true
radio.RadioButton.action = function() return 'native-duration' end
local item = frame('Button', nil, shopping); item.Icon = item:CreateTexture(); item.Icon.path = 'item-art'
item.IconBorder = item:CreateTexture(); item.IconBorder:SetVertexColor(0.3, 0.6, 1, 1)
item.Text = item:CreateFontString(nil, 'OVERLAY', 'GameFontNormal'); item.Text:SetText('34')
item.IconSelectedHighlight = item:CreateTexture(); item.action = function() return 'native-item-drag' end
local prices = frame('Frame', nil, shopping); prices.CurrentPrices = frame('Frame', nil, prices)
prices.HistoryPrices = frame('Frame', nil, prices); prices.HistoryPrices.hidden = true
prices.HistoryButton = frame('Button', nil, prices)
modules.Auctionator.install(S, modules.Auctionator); flush()
assert(shopping.shellOptions.noBorder and shopping.ListsContainer.panelOptions.noBorder and shopping.ListsContainer.panelOptions.inset)
assert(options.SearchString.inputOptions.noBorder and options.SearchString.inputOptions.padInput)
assert(shopping.Refresh() == 'native-refresh-result')
assert(tab.selected and AuctionFrameTab1.selected == false and AuctionFrame.selectedTab == 1)
assert(options.SearchButton.points[1][1] == 'LEFT' and shopping.ListsContainer.points[1][5] == -84)
assert(mini.RecentsTab.selected and not mini.ListsTab.selected and cap.alpha == 0 and results.ScrollBar.scroll)
assert(radio.RadioButton.checkbox and radio.RadioButton.regions[1].shown and radio.RadioButton.action() == 'native-duration')
assert(item.Icon.path == 'item-art' and item.Icon.crop and item.IconBorder.alpha == 0 and item.Text.text == '34')
assert(item.euiQualityTop.color[3] == 1 and item.IconSelectedHighlight.alpha == 1 and item.action() == 'native-item-drag')
item.IconBorder:SetVertexColor(1, 0.5, 0, 1); assert(item.euiQualityTop.color[1] == 1 and item.euiQualityTop.color[2] == 0.5)
radio.RadioButton:SetChecked(false); assert(not radio.RadioButton.regions[1].shown)
mini:SetView(1); tab:DeselectTab(); flush()
assert(not tab.selected and AuctionFrameTab1.selected == nil and mini.ListsTab.selected and not mini.RecentsTab.selected)
assert(not prices.HistoryButton.selected)
prices.HistoryPrices.hidden = false; modules.Auctionator.refresh(); flush(); assert(prices.HistoryButton.selected)
local count = #item.regions + #radio.RadioButton.regions
accent = 0.2; spinner:SetAlpha(0); modules.Auctionator.refresh(); flush()
assert(spinner.alpha == 1 and radio.RadioButton.regions[1].color[1] == accent)
print('PASS: Auctionator legacy wrappers, search layout, radios, item quality borders, price tabs, accents and warm reuse')
