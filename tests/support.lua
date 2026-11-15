-- Shared fakes for skin specs. A spec starts with:
--   local T = dofile('tests/support.lua')
--   local ns = T.Load('Skins/MyAddon.lua')   -- the TOC's shared files, then the skin
-- then builds frames with T.Frame, installs with T.Install('MyAddon') and checks what
-- the recording facade wrote on each frame (f.skin.Button, f.skin.Shell, ...).
local T = {timers = {}, combat = false, events = {}, registered = {}, loaded = {}, chat = {},
    DIR = 'EUIAdditionalSkinning/', TOC = 'EUIAdditionalSkinning/EUIAdditionalSkinning.toc', ADDON = 'EUIAdditionalSkinning', PREFIX = 'EUI Additional Skinning - '}

-- WoW API surface the addon touches.
C_Timer = {After = function(_, fn) T.timers[#T.timers + 1] = fn end}
InCombatLockdown = function() return T.combat end
geterrorhandler = function() return function(e) error(e, 0) end end
hooksecurefunc = function(object, key, callback)
    local original = object[key]
    object[key] = function(...)
        local values = table.pack(original(...)); callback(...); return table.unpack(values, 1, values.n)
    end
end
-- T.loaded[name]: loaded this session; T.enabled[name]: enabled for the character but not loaded.
T.enabled = {}
C_AddOns = {
    IsAddOnLoaded = function(name) return T.loaded[name] or false end,
    GetAddOnInfo = function(name) if T.loaded[name] or T.enabled[name] then return name end end,
    GetAddOnEnableState = function(name) return (T.loaded[name] or T.enabled[name]) and 2 or 0 end,
}
UnitGUID = function() return 'Player-Test' end
UnitName = function() return 'Tester' end
DEFAULT_CHAT_FRAME = {AddMessage = function(_, message) T.chat[#T.chat + 1] = message end}
SlashCmdList = {}
NORMAL_FONT_COLOR = {GetRGB = function() return 1, 0.82, 0 end}
debugprofilestop = function() return os.clock() * 1000 end
wipe = function(t) for key in pairs(t) do t[key] = nil end; return t end
strtrim = function(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end
EllesmereUI = {RegisterSkin = function(name, callback) T.registered[name] = callback end}

-- Run every queued pass (H.Queue coalesces into C_Timer.After(0)).
function T.Flush()
    local rounds = 0
    while #T.timers > 0 do
        local batch = T.timers; T.timers = {}
        for _, fn in ipairs(batch) do fn() end
        rounds = rounds + 1; assert(rounds < 25, 'refresh loop')
    end
end

-- Deliver an event to every frame registered for it.
function T.Fire(event, ...)
    for _, f in ipairs(T.events) do
        if f.registered[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end

local Texture = {}
Texture.__index = Texture
function Texture:GetObjectType() return self.kind end
function Texture:IsForbidden() return false end
function Texture:IsProtected() return false end
function Texture:GetParent() return self.parent end
function Texture:GetDrawLayer() return self.layer or 'ARTWORK', self.sublevel or 0 end
function Texture:SetDrawLayer(layer) self.layer = layer end
function Texture:GetTexture() return self.path end
function Texture:SetTexture(path) self.path = path end
function Texture:GetAtlas() return self.atlas end
function Texture:SetAtlas(atlas) self.atlas = atlas end
function Texture:SetColorTexture(...) self.color = {...} end
function Texture:SetVertexColor(...) self.vertex = {...} end
function Texture:GetVertexColor() return table.unpack(self.vertex or {1, 1, 1, 1}) end
function Texture:SetDesaturated(v) self.desaturated = v end
function Texture:GetAlpha() return self.alpha end
function Texture:SetAlpha(a) self.alpha = a end
function Texture:SetShown(v) self.shown = v end
function Texture:Show() self.shown = true end
function Texture:Hide() self.shown = false end
function Texture:SetTexCoord(...) self.crop = {...} end
function Texture:GetNumMaskTextures() return #(self.masks or {}) end
function Texture:GetMaskTexture(i) return (self.masks or {})[i] end
function Texture:AddMaskTexture(mask) self.masks = self.masks or {}; self.masks[#self.masks + 1] = mask end
function Texture:RemoveMaskTexture(mask)
    for i, m in ipairs(self.masks or {}) do if m == mask then table.remove(self.masks, i); return end end
end
function Texture:GetSize() return self.width or 16, self.height or 16 end
function Texture:GetRect() if self.rect then return table.unpack(self.rect) end end
function Texture:IsVisible() return self.shown ~= false and (not self.parent or self.parent:IsVisible()) end
function Texture:GetWidth() return self.width or 16 end
function Texture:GetHeight() return self.height or 16 end
function Texture:SetSize(w, h) self.width, self.height = w, h end
function Texture:SetWidth(w) self.width = w end
function Texture:SetHeight(h) self.height = h end
function Texture:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = {...} end
function Texture:ClearAllPoints() self.points = {} end
function Texture:SetAllPoints(rel) self.all = rel or true end
-- FontString extras.
function Texture:GetText() return self.text end
function Texture:SetText(text) self.text = text end
function Texture:GetFont() return self.font, self.size or 12, self.flags end
function Texture:SetFont(font, size, flags) self.font, self.size, self.flags = font, size, flags; self.fontWrites = (self.fontWrites or 0) + 1 end
function Texture:SetFontObject(font) self.font = font end
function Texture:GetTextColor() return table.unpack(self.textColor or {1, 1, 1, 1}) end
function Texture:SetTextColor(...) self.textColor = {...} end

function T.Texture(parent, layer, kind)
    local t = setmetatable({kind = kind or 'Texture', parent = parent, layer = layer, alpha = 1}, Texture)
    if parent then parent.regions[#parent.regions + 1] = t end
    return t
end
function T.FontString(parent, text)
    local fs = T.Texture(parent, 'OVERLAY', 'FontString')
    fs.text, fs.font = text, 'native'
    return fs
end

local Frame = {}
Frame.__index = Frame
function Frame:GetObjectType() return self.kind end
function Frame:IsObjectType(kind) return self.kind == kind end
function Frame:IsForbidden() return self.forbidden end
function Frame:IsProtected() return self.protected end
function Frame:GetName() return self.name end
function Frame:GetParent() return self.parent end
function Frame:GetChildren() return table.unpack(self.children) end
function Frame:GetRegions() return table.unpack(self.regions) end
function Frame:GetNumChildren() return #self.children end
function Frame:GetNumRegions() return #self.regions end
function Frame:IsShown() return self.shown end
function Frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
-- Show/Hide run the hooked OnShow/OnHide, as WoW does.
function Frame:Show() if not self.shown then self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end end
function Frame:Hide() if self.shown then self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end end
function Frame:SetShown(v) if v then self:Show() else self:Hide() end end
function Frame:HasScript() return true end
function Frame:GetScript(key) return self.scripts[key] end
function Frame:SetScript(key, fn) self.scripts[key] = fn end
function Frame:HookScript(key, fn)
    local original = self.scripts[key]
    self.scripts[key] = function(...) if original then original(...) end; fn(...) end
end
function Frame:RegisterEvent(event) self.registered[event] = true end
function Frame:UnregisterEvent(event) self.registered[event] = nil end
-- Unit events record their unit, as the client filters on it.
function Frame:RegisterUnitEvent(event, unit) self.registered[event] = unit or true end
function Frame:CreateTexture(_, layer) return T.Texture(self, layer) end
function Frame:CreateFontString(_, layer) return T.FontString(self) end
function Frame:GetFontString() return self.label end
function Frame:GetNormalTexture() return self.normal end
function Frame:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = {...} end
function Frame:ClearAllPoints() self.points = {} end
function Frame:GetNumPoints() return #(self.points or {}) end
function Frame:GetPoint(i) if self.points and self.points[i or 1] then return table.unpack(self.points[i or 1]) end end
function Frame:SetAllPoints(rel) self.all = rel or true end
function Frame:GetWidth() return self.width or 100 end
function Frame:GetSize() return self.width or 100, self.height or 24 end
function Frame:GetHeight() return self.height or 24 end
function Frame:SetWidth(w) self.width = w end
function Frame:SetHeight(h) self.height = h end
function Frame:SetSize(w, h) self.width, self.height = w, h end
function Frame:GetLeft() return self.left end
function Frame:GetRight() return self.right end
function Frame:GetTop() return self.top end
function Frame:GetBottom() return self.bottom end
function Frame:GetFrameLevel() return self.level or 1 end
function Frame:GetFrameStrata() return self.strata or 'MEDIUM' end
function Frame:GetRect() if self.rect then return table.unpack(self.rect) end end
function Frame:GetEffectiveAlpha() return (self.alpha or 1) * (self.parent and self.parent:GetEffectiveAlpha() or 1) end
function Frame:SetFrameLevel(level) self.level = level end
function Frame:GetEffectiveScale() return 1 end
function Frame:GetAlpha() return self.alpha or 1 end
function Frame:SetAlpha(a) self.alpha = a end
function Frame:GetBackdrop() return self.backdrop end
function Frame:GetBackdropColor() return table.unpack(self.backdropColor or {1, 1, 1, 1}) end
function Frame:SetBackdropColor(...) self.backdropColor = {...} end
function Frame:SetBackdropBorderColor(...) self.backdropBorder = {...} end
function Frame:SetBackdrop(b) assert(not T.combat, 'SetBackdrop in combat'); self.backdrop = b end
function Frame:IsEnabled() return not self.disabled end
function Frame:Enable() self.disabled = false end
function Frame:Disable() self.disabled = true end
function Frame:GetChecked() return self.checked end
function Frame:SetChecked(v) self.checked = v end
function Frame:GetID() return self.id end
function Frame:EnableMouse(v) self.mouse = v end
function Frame:IsMouseEnabled() return self.mouse end
function Frame:SetMouseClickEnabled(v) self.clicks = v end

-- A frame: kind ("Frame", "Button", "EditBox", ...), optional parent and global name.
function T.Frame(kind, parent, name)
    local f = setmetatable({kind = kind or 'Frame', name = name, parent = parent, children = {}, regions = {},
        scripts = {}, registered = {}, shown = true, skin = {}}, Frame)
    if parent then parent.children[#parent.children + 1] = f end
    if name then _G[name] = f end
    return f
end
CreateFrame = function(kind, name, parent)
    local f = T.Frame(kind, parent, name)
    T.events[#T.events + 1] = f
    return f
end

-- Recording EUI facade: each primitive records itself on the frame it styled
-- (f.skin.Button = true, f.skin.Shell = options, ...), so specs assert what was styled.
T.accent = {0.05, 0.8, 0.6}
local S = {apiVersion = 3}
for _, name in ipairs({'Shell', 'Panel', 'Inset', 'Button', 'EditBox', 'Checkbox', 'Dropdown', 'ScrollBar', 'Tab',
    'CloseButton', 'PageButton', 'SquareIcon', 'SortHeaderBar', 'FadeRegions', 'FadeNineSlice', 'ApplyBarFill',
    'WhiteButtonLabel', 'StateButtonLabel', 'White'}) do
    S[name] = function(f, options)
        if type(f) == 'table' then f.skin = f.skin or {}; f.skin[name] = options == nil and true or options end
    end
end
function S.SetTabSelection(f, selected) f.selected = selected end
function S.Font(text, r, g, b) text:SetFont('eui', select(2, text:GetFont()), ''); if r then text:SetTextColor(r, g, b) end end
function S.GetFont() return 'eui', '' end
function S.GetAccentColor() return table.unpack(T.accent) end
function S.GetPanelColor() return 0.07, 0.07, 0.07, 0.97 end
function S.GetStyle() return 'eui' end
function S.IsEnabled() return true end
T.looks = {}
function S.OnLooksChanged(fn) T.looks[#T.looks + 1] = fn end
T.S = S

-- Load the TOC's shared files (everything outside Skins/), then the given skin files. Paths are
-- relative to the addon folder (T.DIR), as in the TOC.
function T.Load(...)
    local ns = {}
    local toc = assert(io.open(T.TOC)):read('*a')
    for line in toc:gmatch('[^\r\n]+') do
        local path = line:gsub('\\', '/')
        if not path:match('^#') and path:match('%S') and not path:match('^Skins/') then
            assert(loadfile(T.DIR .. path))(T.ADDON, ns)
        end
    end
    for _, path in ipairs({...}) do assert(loadfile(T.DIR .. path))(T.ADDON, ns) end
    T.ns = ns
    return ns
end

-- The skin's catalog entry; a spec's own test skin gets one, targeting a folder of its id.
function T.Entry(id)
    local ns = T.ns
    local entry = ns.skinCatalogByID[id]
    if not entry then
        local label = id
        for _, module in ipairs(ns.modules) do if module.id == id then label = module.label end end
        entry = {id = id, label = label, targets = {id}}
        ns.skinCatalog[#ns.skinCatalog + 1] = entry
        ns.skinCatalogByID[id] = entry
    end
    return entry
end
-- Load the skin's target addon and hand EUI's facade over, as EUI does at login: the skin's
-- factory runs and its module installs if available() is true. Returns the module.
function T.Install(id)
    local entry = T.Entry(id)
    for _, target in ipairs(entry.targets) do T.loaded[target] = true end
    T.Fire('ADDON_LOADED', entry.targets[1])
    local register = assert(T.registered[T.PREFIX .. entry.label], 'skin not registered: ' .. id)
    register(S)
    T.Flush()
    return T.Module(id)
end
function T.Module(id)
    for _, module in ipairs(T.ns.modules) do if module.id == id then return module end end
    error('no module ' .. id)
end
function T.Refresh(id) T.Module(id).refresh(); T.Flush() end

return T
