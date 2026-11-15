-- Auctionator integration: lazy AH controls, preserved constructors/callbacks, combat and global discovery.
local timers, errors, modules, looks, events = {}, {}, {}, {}, {}
local enabled, combat = true, false
local ns = {IsEnabled = function() return enabled end,
    AttachAccent = function(_, f) f.accent = true end}
function ns.RegisterModule(id, _, available, install, options) modules[id] = {available = available, install = install} end
C_Timer = {}
C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
InCombatLockdown = function() return combat end
geterrorhandler = function() return function(e) errors[#errors + 1] = e end end
hooksecurefunc = function(obj, key, callback)
    local original = obj[key]
    obj[key] = function(...)
        local result = table.pack(original(...)); callback(...); return table.unpack(result, 1, result.n)
    end
end
local function flush()
    local rounds = 0
    while #timers > 0 do
        local batch = timers; timers = {}; for _, fn in ipairs(batch) do fn() end
        rounds = rounds + 1; assert(rounds < 20, 'refresh loop')
    end
end
local function frame(kind, parent)
    local f = {kind = kind or 'Frame', children = {}, regions = {}, hooks = {}, scripts = {}, shown = true}
    function f:GetObjectType() return self.kind end
    function f:IsForbidden() return self.forbidden end
    function f:IsProtected() return self.protected end
    function f:GetChildren() return table.unpack(self.children) end
    function f:GetRegions() return table.unpack(self.regions) end
    function f:GetFrameLevel() return 4 end
    function f:SetFrameLevel(v) self.level = v end
    function f:SetAllPoints() end
    function f:EnableMouse(v) self.mouse = v end
    function f:SetBackdrop(v) assert(not combat); self.backdrop = v end
    function f:HookScript(key, fn) self.hooks[key] = fn end
    function f:SetScript(key, fn) self.scripts[key] = fn end
    function f:RegisterEvent(e) self.events = self.events or {}; self.events[e] = true end
    function f:IsShown() return self.shown end
    function f:GetName() return self.name end
    function f:GetParent() return self.parent end
    if parent then parent.children[#parent.children + 1] = f; f.parent = parent end
    return f
end
CreateFrame = function(kind, name, parent)
    local f = frame(kind, parent)
    if name then _G[name] = f end
    if not parent then events[#events + 1] = f end
    return f
end
local config = {OpenFrames = {}, FeedGroup = function() end}
LibStub = function() return config end
local S = {OnLooksChanged = function(fn) looks[#looks + 1] = fn end}
function S.Shell(f, opts) assert(not combat); f.shell = true; f.shellOptions = opts end
function S.Panel(f) assert(not f.protected); f.panel = true end
function S.Tab(f) assert(not f.protected); f.tab = true end
function S.SetTabSelection(f, v) f.selected = v end
function S.CloseButton(f) f.close = true end
function S.PageButton(f, glyph) f.glyph = glyph end
function S.EditBox(f, opts) assert(not f.protected); f.input = true; f.padded = opts and opts.padInput; f.inputOptions = opts end
function S.Button(f) f.button = true end
function S.ScrollBar(f) f.scroll = true end
function S.Font() end
function S.FadeNineSlice() end
function S.Checkbox() end
function S.StateButtonLabel() end
function S.Dropdown() end
assert(loadfile('EUIAdditionalSkinning/Widgets.lua'))('EUIAdditionalSkinning', ns)
assert(loadfile('EUIAdditionalSkinning/Helpers.lua'))('EUIAdditionalSkinning', ns)
Auctionator = nil
assert(loadfile('EUIAdditionalSkinning/Skin.lua'))('EUIAdditionalSkinning', ns)
assert(loadfile('EUIAdditionalSkinning/Skins/Auctionator.lua'))('EUIAdditionalSkinning', ns)
assert(not modules.Auctionator.available())
Auctionator = {Tabs = {State = {knownTabs = {{name = 'Shopping', tabFrameName = 'AuctionatorShoppingFrame'}}}},
    Dialogs = {}, Config = {InternalInitializeFrames = function() end}}
AuctionatorTabContainerMixin = {OnLoad = function() return 'constructor-result' end}
AuctionatorExportTextFrameMixin = {OnLoad = function() end}
Auctionator.Dialogs.ShowConfirm = function()
    AuctionatorDialog1 = frame(); AuctionatorDialog1.children = {frame('EditBox')}
    AuctionatorDialog1.callback = function() return 'purchase-original' end
    return 17
end
modules.Auctionator.install(S, modules.Auctionator); flush()
assert(AuctionatorShoppingFrame == nil, 'skin must not open the AH')
AuctionatorShoppingFrame = frame()
AuctionatorShoppingFrame.ScrollBar = frame('EventFrame')
local input = frame('EditBox', AuctionatorShoppingFrame)
AuctionatorTabs_Shopping = frame('Button')
AuctionatorTabs_Shopping.Selected = function() return 19 end
AuctionatorTabs_Shopping.DeselectTab = function() AuctionatorShoppingFrame.shown = false end
assert(AuctionatorTabContainerMixin.OnLoad(frame()) == 'constructor-result'); flush()
assert(AuctionatorShoppingFrame.shell and input.padded and AuctionatorShoppingFrame.ScrollBar.scroll)
assert(AuctionatorTabs_Shopping.tab and AuctionatorTabs_Shopping.selected)
assert(AuctionatorTabs_Shopping:Selected() == 19)
AuctionatorTabs_Shopping:DeselectTab(); flush(); assert(not AuctionatorTabs_Shopping.selected)
assert(Auctionator.Dialogs.ShowConfirm() == 17); flush()
assert(AuctionatorDialog1.shell and AuctionatorDialog1.callback() == 'purchase-original')
local export = frame(); AuctionatorExportTextFrameMixin.OnLoad(export); flush(); assert(export.shell)
combat = true
local late = frame(); AuctionatorExportTextFrameMixin.OnLoad(late); flush(); assert(not late.shell)
combat = false
for _, f in ipairs(events) do if f.events and f.events.PLAYER_REGEN_ENABLED then f.scripts.OnEvent(f, 'PLAYER_REGEN_ENABLED') end end
flush(); assert(late.shell)
-- Global discovery runs at initialization/load boundaries, not each repaint.
local nativePairs, globalWalks = pairs, 0
pairs = function(t)
    if t == _G then globalWalks = globalWalks + 1 end
    return nativePairs(t)
end
for _ = 1, 25 do modules.Auctionator.refresh(); flush() end
assert(globalWalks == 0, 'warm refresh searched all globals')
AuctionatorConfigLazyFrame = frame(); AuctionatorConfigLazyFrame.name = 'AuctionatorConfigLazyFrame'
local lazyInput = frame('EditBox', AuctionatorConfigLazyFrame)
Auctionator.Config:InternalInitializeFrames(); flush()
-- Settings inputs are styled without the walk's padding, which would move their hit rectangle (04215f6).
assert(globalWalks == 1 and lazyInput.input and not lazyInput.padded, 'late config discovery lost, or settings input padded')
AuctionatorConfigLoadedFrame = frame(); AuctionatorConfigLoadedFrame.name = 'AuctionatorConfigLoadedFrame'
local loadedInput = frame('EditBox', AuctionatorConfigLoadedFrame)
for _, f in ipairs(events) do
    if f.events and f.events.ADDON_LOADED then f.scripts.OnEvent(f, 'ADDON_LOADED') end
end
flush(); assert(globalWalks == 2 and loadedInput.input and not loadedInput.padded, 'addon-load discovery lost')
pairs = nativePairs
print('PASS: Auctionator lazy tabs/dialogs/scrollbars, preserved constructors/actions, combat deferral, global discovery, unpadded settings inputs')
