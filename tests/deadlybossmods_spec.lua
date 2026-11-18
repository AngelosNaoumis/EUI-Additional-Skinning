-- DBM timers: one cached hull around bar plus visible icons, matching cached dividers, no update hook.
local T = dofile('tests/support.lua')
local ns = T.Load('Skins/DeadlyBossMods.lua')

UIParent = T.Frame('Frame', nil, 'UIParent')
local borderCalls = setmetatable({}, {__mode = 'k'})
local dividerCalls = setmetatable({}, {__mode = 'k'})
ns.ApplyConfiguredBorder = function(frame)
    borderCalls[frame] = (borderCalls[frame] or 0) + 1
    return true
end
ns.ApplyConfiguredDividerV = function(frame, right)
    dividerCalls[frame] = {calls = (dividerCalls[frame] and dividerCalls[frame].calls or 0) + 1, right = right}
    return true
end

local DBT = {bars = {}, byID = {}, nativeBorders = true}
_G.DBT = DBT
local barPrototype = {}
local barMeta = {__index = barPrototype}
function DBT:GetBar(id) return self.byID[id] end
function DBT:GetBarIterator() return pairs(self.bars) end
function DBT:CreateBar(_, id, _, _, _, _, _, _, _, _, _, _, _, _, _, secret)
    local object = self.byID[id]
    if not object then
        local name = 'DBT_Bar_' .. tostring(id)
        local frame = T.Frame('Frame', UIParent, name)
        object = setmetatable({frame = frame, isSecret = secret and true or false,
            nativeBorders = self.nativeBorders}, barMeta)
        self.byID[id] = object
        self.bars[object] = true
        local bar = T.Frame('StatusBar', frame, name .. 'Bar')
        bar:SetSize(195, 20)
        for _, suffix in ipairs({'Icon1', 'Icon2'}) do
            local icon = T.Texture(frame, 'ARTWORK')
            icon.shown = true
            icon:SetSize(20, 20)
            function icon:IsShown() return self.shown end
            _G[name .. 'Bar' .. suffix] = icon
        end
    end
    object:ApplyStyle()
    return object
end
function barPrototype:ApplyStyle()
    local name = self.frame:GetName()
    if self.nativeBorders then
        for _, side in ipairs({'Top', 'Bottom', 'Left', 'Right'}) do
            local key = name .. 'BarBorder' .. side
            _G[key] = _G[key] or T.Texture(_G[name .. 'Bar'], 'ARTWORK')
            _G[key]:SetAlpha(1)
        end
    end
end
function DBT:ApplyStyle() for object in pairs(self.bars) do object:ApplyStyle() end end
function DBT:UpdateBars() end

local function Layout(object)
    local name = object.frame:GetName()
    local bar = _G[name .. 'Bar']
    local icon1 = _G[name .. 'BarIcon1']
    local icon2 = _G[name .. 'BarIcon2']
    local hull
    for _, child in ipairs(object.frame.children) do
        if child ~= bar and child.mouse == false then hull = child end
    end
    assert(hull, 'DBM composite hull missing')
    return hull, bar, icon1, icon2, hull.children[1], hull.children[2]
end

-- An already-active bar is discovered through DBT's set-key iterator.
DBT:CreateBar(12, 0, 123)
T.Install('DeadlyBossMods')
local activeHull = Layout(DBT:GetBar(0))
assert(borderCalls[activeHull] == 1, 'active DBM set key did not receive one composite border')

DBT:CreateBar(10, 1, 123)
local object = DBT:GetBar(1)
local name = object.frame:GetName()
local hull, bar, leftIcon, rightIcon, leftDivider, rightDivider = Layout(object)
assert(borderCalls[hull] == 1, 'timer layout did not receive exactly one configured outer border')
assert(borderCalls[bar] == nil and borderCalls[leftIcon] == nil and borderCalls[rightIcon] == nil,
    'bar or icon received an independent border')
assert(#hull.points == 4 and hull.points[1][2] == leftIcon and hull.points[2][2] == rightIcon,
    'both-icon hull does not span the complete visible timer')
assert(dividerCalls[leftDivider].right == false and dividerCalls[rightDivider].right == true,
    'left/right divider sides do not match the castbar layout')

for _, side in ipairs({'Top', 'Bottom', 'Left', 'Right'}) do
    assert(_G[name .. 'BarBorder' .. side].alpha == 0, 'DBM native edge left under the unified border')
end

-- Applying the same style or changing bar width does not rewrite anchors; DBM's own anchors make
-- the hull follow the animation. Visibility transitions write geometry once per actual layout.
local clears, clear = 0, hull.ClearAllPoints
hull.ClearAllPoints = function(self) clears = clears + 1; clear(self) end
object:ApplyStyle()
bar:SetWidth(240)
object:ApplyStyle()
assert(clears == 0, 'unchanged DBM style or width repeated composite geometry writes')

-- Standard/huge transitions choose the tallest visible piece without changing DBM dimensions.
bar:SetHeight(30)
object:ApplyStyle()
assert(clears == 0 and hull.points[3][2] == bar, 'huge bar did not remain the vertical hull source')
leftIcon:SetHeight(36)
object:ApplyStyle()
assert(clears == 1 and hull.points[3][2] == leftIcon, 'tall visible icon did not expand the unified hull')
leftIcon:SetHeight(20)
bar:SetHeight(20)
object:ApplyStyle()
assert(clears == 2 and hull.points[3][2] == bar, 'standard layout did not restore the bar height')

rightIcon.shown = false
object:ApplyStyle()
assert(clears == 3 and hull.points[1][2] == leftIcon and hull.points[2][2] == bar,
    'left-only layout did not span icon through bar')
assert(leftDivider.shown and rightDivider.shown == false, 'left-only layout kept the wrong divider visible')

leftIcon.shown, rightIcon.shown = false, true
object:ApplyStyle()
assert(clears == 4 and hull.points[1][2] == bar and hull.points[2][2] == rightIcon,
    'right-only layout did not span bar through icon')
assert(leftDivider.shown == false and rightDivider.shown, 'right-only layout kept the wrong divider visible')

rightIcon.shown = false
object:ApplyStyle()
assert(clears == 5 and hull.points[1][2] == bar and hull.points[2][2] == bar,
    'no-icon layout did not reduce the hull to the timer bar')
assert(leftDivider.shown == false and rightDivider.shown == false, 'no-icon layout left a divider visible')

-- Pool reuse retains the same hull, outer border and divider textures.
leftIcon.shown, rightIcon.shown = true, true
DBT:CreateBar(8, 1, 456)
local reusedHull, _, _, _, reusedLeft, reusedRight = Layout(object)
assert(reusedHull == hull and reusedLeft == leftDivider and reusedRight == rightDivider,
    'pooled DBM timer recreated its composite pieces')
assert(borderCalls[hull] == 1 and dividerCalls[leftDivider].calls == 1 and dividerCalls[rightDivider].calls == 1,
    'pooled DBM timer reapplied a border or divider')

-- A normal/huge transition may lazily create DBM's native edge; the shared ApplyStyle hook must
-- suppress it immediately without a scan or timer-update hook.
DBT.nativeBorders = false
DBT:CreateBar(10, 3, 123)
local transition = DBT:GetBar(3)
transition.nativeBorders = true
transition:ApplyStyle()
for _, side in ipairs({'Top', 'Bottom', 'Left', 'Right'}) do
    assert(_G[transition.frame:GetName() .. 'BarBorder' .. side].alpha == 0,
        'style transition restored a duplicate native edge')
end

DBT:CreateBar(10, 2, 123, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, true)
local protected = T.Frame('Frame', UIParent, 'DBT_Bar_protected'); protected.protected = true
DBT.bars[setmetatable({frame = protected}, barMeta)] = true
DBT:ApplyStyle()
for _ = 1, 1000 do DBT:UpdateBars() end
assert(#T.timers == 0, 'DBM skin left polling or queued timer work')

EUIAdditionalSkinningDB.skins = {DeadlyBossMods = false}
DBT.nativeBorders = false
DBT:CreateBar(10, 4, 123)
local disabled = DBT:GetBar(4)
assert(#disabled.frame.children == 1, 'disabled DBM skin created a composite frame')
print('PASS: DBM uses one cached composite border for both/left/right/no-icon layouts; dividers and pooled reuse are stable; update, disabled, secret and protected paths are inert')
