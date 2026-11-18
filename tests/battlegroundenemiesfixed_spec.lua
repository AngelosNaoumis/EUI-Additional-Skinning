-- BGE: native role/raid/castbars, visibility-aware icons, one recoloured outer border and recycling.
local T = dofile('tests/support.lua')
local ns = T.Load('Skins/BattlegroundEnemiesFixed.lua')
UIParent = T.Frame('Frame', nil, 'UIParent')

local borderCalls = setmetatable({}, {__mode = 'k'})
local horizontalCalls = setmetatable({}, {__mode = 'k'})
local colours = setmetatable({}, {__mode = 'k'})
ns.ApplyConfiguredBorder = function(frame)
    borderCalls[frame] = (borderCalls[frame] or 0) + 1
    return true
end
ns.ApplyConfiguredDividerH = function(frame, top)
    horizontalCalls[frame] = {calls = (horizontalCalls[frame] and horizontalCalls[frame].calls or 0) + 1, top = top}
    return true
end
ns.SetConfiguredBorderColor = function(frame, ...)
    colours[frame] = select('#', ...) > 0 and {...} or false
    return true
end

BattleGroundEnemies = T.Frame('Frame', UIParent, 'BattleGroundEnemies')
BattleGroundEnemies.db = {profile = {
    MyTarget_Color = {1, 0.2, 0.1, 1},
    MyFocus_Color = {0.1, 0.8, 0.6, 1},
}}
BGEEnemies = T.Frame('Button', UIParent, 'BGEEnemies')
BGEEnemies.PlayerList = {}
BattleGroundEnemies.Enemies = BGEEnemies

local function IconModule(parent, shown, texture, alpha)
    local frame = T.Frame('Frame', parent)
    frame.Icon = T.Texture(frame, 'ARTWORK')
    frame.Icon:SetTexture(texture)
    frame.Icon:SetAlpha(alpha == nil and 1 or alpha)
    if shown then frame:Show() else frame:Hide() end
    return frame
end

local function CastDisplay(parent)
    local bar = T.Frame('StatusBar', parent)
    bar:SetSize(150, 10)
    bar.Icon = T.Texture(bar, 'ARTWORK')
    bar.Icon:SetTexture('cast-icon')
    bar.Icon:SetSize(10, 10)
    return bar
end

local function Player(protected)
    local button = T.Frame('Button', BGEEnemies)
    button.protected = protected and true or false
    button.PlayerIsEnemy = true
    button:SetSize(220, 28)
    button.healthBar = T.Frame('StatusBar', button)
    button.Power = T.Frame('StatusBar', button)
    button.Power:SetSize(220, 4)
    button.SpecClassPriority = T.Frame('Frame', button)
    button.Trinket = IconModule(button, true, nil, 0)
    button.ObjectiveAndRespawn = IconModule(button, false, nil, 1)
    button.Role = IconModule(button, true, 'role', 1)
    button.RaidTargetIcon = IconModule(button, true, 'raid-target', 1)
    button.CombatIndicator = T.Frame('Frame', button)
    button.CombatIndicator.Combat = T.Frame('Frame', button.CombatIndicator)
    button.CombatIndicator.OutOfCombat = T.Frame('Frame', button.CombatIndicator)
    button.MyTarget = T.Frame('Frame', button); button.MyTarget:Hide()
    button.MyFocus = T.Frame('Frame', button); button.MyFocus:Hide()

    local dr = T.Frame('Frame', button)
    dr.childFrames = {T.Frame('Frame', dr)}
    dr.inputs = {}
    function dr:NewInput(input)
        self.inputs[#self.inputs + 1] = input
        if not self.childFrames[2] then self.childFrames[2] = T.Frame('Frame', self) end
        return input
    end
    button.DRTracking = dr

    local cast = T.Frame('Frame', button)
    cast.CastBar = CastDisplay(cast)
    function cast:ApplyAllSettings()
        if self.nextBar then self.CastBar, self.nextBar = self.nextBar, nil end
    end
    button.CastBar = cast
    return button
end

function BGEEnemies:SetupButtonForNewPlayer(button)
    button.MyTarget:Hide()
    button.MyFocus:Hide()
    self.PlayerList[#self.PlayerList + 1] = button
    button:Show()
    return button
end

local function BorderedChild(frame)
    for _, child in ipairs(frame.children) do if borderCalls[child] then return child end end
end

local first = Player(true)
BGEEnemies.PlayerList[1] = first
local originalPoints, originalWidth, originalHeight = #(first.points or {}), first:GetSize()
T.Install('BattlegroundEnemiesFixed')

-- The secure unit button gets one separate child host; no geometry write lands on it.
assert(borderCalls[first] == nil, 'secure enemy button was modified directly')
local outer
for _, child in ipairs(first.children) do
    if borderCalls[child] and child.all == first then outer = child end
end
assert(outer and outer.all == first and borderCalls[outer] == 1, 'enemy frame has no cached outer-border host')
local width, height = first:GetSize()
assert(#(first.points or {}) == originalPoints and width == originalWidth and height == originalHeight,
    'enemy button geometry changed while adding its border')

local powerDivider
for _, child in ipairs(first.Power.children) do if horizontalCalls[child] then powerDivider = child end end
assert(powerDivider and horizontalCalls[powerDivider].top and horizontalCalls[powerDivider].calls == 1,
    'health/power divider is missing or on the wrong edge')

-- Native role and raid marker surfaces receive no border or geometry changes. Castbars and their
-- icons are equally untouched; the only static icon borders are supported aura/combat/DR surfaces.
assert(not borderCalls[first.Role] and not BorderedChild(first.Role), 'role icon was bordered')
assert(not borderCalls[first.RaidTargetIcon] and not BorderedChild(first.RaidTargetIcon), 'raid target icon was bordered')
assert(not borderCalls[first.CastBar] and not borderCalls[first.CastBar.CastBar]
    and not BorderedChild(first.CastBar) and not BorderedChild(first.CastBar.CastBar), 'castbar was skinned')
for _, frame in ipairs({first.SpecClassPriority, first.CombatIndicator.Combat,
        first.CombatIndicator.OutOfCombat, first.DRTracking.childFrames[1]}) do
    assert(borderCalls[frame] == 1, 'supported BGE surface did not receive exactly one border')
end

-- Objective/respawn and trinket borders are anchored to the actual Icon texture and stay hidden
-- until the container, texture and alpha all make that icon effectively visible.
local trinketHost = BorderedChild(first.Trinket)
local objectiveHost = BorderedChild(first.ObjectiveAndRespawn)
assert(trinketHost and trinketHost.all == first.Trinket.Icon and not trinketHost:IsShown(),
    'empty trinket slot has a visible or incorrectly anchored border')
assert(objectiveHost and objectiveHost.all == first.ObjectiveAndRespawn.Icon and not objectiveHost:IsShown(),
    'empty objective slot has a visible or incorrectly anchored border')
first.Trinket.Icon:SetTexture('trinket')
assert(not trinketHost:IsShown(), 'alpha-hidden trinket showed its border')
first.Trinket.Icon:SetAlpha(1)
assert(trinketHost:IsShown(), 'visible trinket did not show its border')
first.Trinket.Icon:SetTexture(nil)
assert(not trinketHost:IsShown(), 'cleared trinket left a floating border')
first.ObjectiveAndRespawn.Icon:SetTexture('objective')
first.ObjectiveAndRespawn:Show()
assert(objectiveHost:IsShown(), 'visible objective did not show its border')
first.ObjectiveAndRespawn:SetAlpha(0)
assert(not objectiveHost:IsShown(), 'alpha-hidden objective left a visible border')
first.ObjectiveAndRespawn:SetAlpha(1)
assert(objectiveHost:IsShown(), 'objective border did not return with container alpha')
first.ObjectiveAndRespawn:Hide()
assert(not objectiveHost:IsShown(), 'hidden objective left a visible border')
first.ObjectiveAndRespawn:Show()
first.ObjectiveAndRespawn.Icon:SetTexture(nil)
assert(not objectiveHost:IsShown(), 'recycled objective slot retained its border')
local oldTrinketHost = trinketHost
first.Trinket.Icon:SetTexture('old-trinket')
local replacement = T.Texture(first.Trinket)
replacement:SetTexture('new-trinket')
first.Trinket.Icon = replacement
T.Refresh('BattlegroundEnemiesFixed')
for _, child in ipairs(first.Trinket.children) do
    if borderCalls[child] and child.all == replacement then trinketHost = child end
end
assert(trinketHost ~= oldTrinketHost and not oldTrinketHost:IsShown()
    and trinketHost.all == replacement and trinketHost:IsShown(),
    'replaced trinket icon retained a stale border host')

-- Native target/focus squares are suppressed. Their state recolours the one outer border with
-- target > focus > normal precedence, then recycling clears stale state.
T.combat = true
first.MyFocus:Show()
assert(first.MyFocus:IsShown() and first.MyFocus:GetAlpha() == 0
    and colours[outer][1] == 0.1 and colours[outer][2] == 0.8,
    'focus did not recolour the existing border or native square remained opaque')
first.MyTarget:Show()
assert(first.MyTarget:IsShown() and first.MyTarget:GetAlpha() == 0
    and colours[outer][1] == 1 and colours[outer][2] == 0.2,
    'target did not take precedence or native square remained opaque')
first.MyTarget:Hide()
assert(colours[outer][1] == 0.1 and colours[outer][2] == 0.8, 'focus was not restored after target cleared')
first.MyFocus:Hide()
assert(colours[outer] == false, 'normal configured border colour was not restored')
first.Trinket.Icon:SetTexture('combat-trinket')
assert(trinketHost:IsShown(), 'existing trinket border did not update immediately in combat')
first.Trinket.Icon:SetTexture(nil)
assert(not trinketHost:IsShown(), 'existing trinket border stayed visible after a combat-time clear')
first.ObjectiveAndRespawn.Icon:SetTexture('combat-objective')
first.ObjectiveAndRespawn:Show()
assert(objectiveHost:IsShown(), 'existing objective border did not update immediately in combat')
first.ObjectiveAndRespawn:Hide()
assert(not objectiveHost:IsShown(), 'existing objective border did not hide immediately in combat')
T.combat = false

first.DRTracking:NewInput({dr = 'stun'})
T.Flush()
local secondDR = first.DRTracking.childFrames[2]
assert(borderCalls[secondDR] == 1, 'dynamically allocated DR icon was not skinned')
first.DRTracking:NewInput({dr = 'fear'})
T.Flush()
assert(borderCalls[secondDR] == 1, 'recycled DR icon received a duplicate border')

local outerChildren = #first.children
first.MyTarget:Show()
BGEEnemies.PlayerList = {}
BGEEnemies:SetupButtonForNewPlayer(first)
assert(colours[outer] == false, 'recycled frame retained a target/focus border colour')
assert(borderCalls[outer] == 1 and horizontalCalls[powerDivider].calls == 1 and #first.children == outerChildren,
    'button recycling recreated or reapplied decorations')
for _ = 1, 1000 do
    BGEEnemies.PlayerList = {}
    BGEEnemies:SetupButtonForNewPlayer(first)
end
assert(borderCalls[outer] == 1 and horizontalCalls[powerDivider].calls == 1 and #first.children == outerChildren
    and #T.timers == 0, '1000 warm button reuses allocated decoration or queued work')

-- A row first encountered during combat receives every safe decoration immediately. Only the
-- protected outer host, protected divider/icon and protected DR surface wait for combat end.
local second = Player(true)
second.Power.protected = true
second.ObjectiveAndRespawn.protected = true
second.Trinket.Icon:SetTexture('combat-created-trinket')
second.Trinket.Icon:SetAlpha(1)
second.ObjectiveAndRespawn.Icon:SetTexture('combat-created-objective')
second.ObjectiveAndRespawn:Show()
local protectedDR = second.DRTracking.childFrames[1]
protectedDR.protected = true
T.combat = true
BGEEnemies:SetupButtonForNewPlayer(second)
assert(borderCalls[second.SpecClassPriority] == 1
    and borderCalls[second.CombatIndicator.Combat] == 1
    and borderCalls[second.CombatIndicator.OutOfCombat] == 1,
    'combat-safe BGE surfaces waited for combat end')
local combatTrinketHost = BorderedChild(second.Trinket)
assert(combatTrinketHost and combatTrinketHost:IsShown(),
    'combat-safe trinket border was not created and shown immediately')
local combatOuter
for _, child in ipairs(second.children) do
    if borderCalls[child] and child.all == second then combatOuter = child end
end
assert(not combatOuter and #second.Power.children == 0
    and not BorderedChild(second.ObjectiveAndRespawn) and not borderCalls[protectedDR],
    'protected BGE decoration was modified during combat')

local liveDR = T.Frame('Frame', second.DRTracking)
second.DRTracking.childFrames[#second.DRTracking.childFrames + 1] = liveDR
second.DRTracking:NewInput({dr = 'combat-safe'})
T.Flush()
assert(borderCalls[liveDR] == 1 and borderCalls[protectedDR] == nil,
    'DR styling did not separate combat-safe and protected surfaces')
second.MyFocus:Show()
second.MyTarget:Show()
second.ObjectiveAndRespawn.Icon:SetTexture(nil)
second.ObjectiveAndRespawn:Hide()

T.combat = false
T.Fire('PLAYER_REGEN_ENABLED')
T.Flush()
local secondOuter
for _, child in ipairs(second.children) do
    if borderCalls[child] and child.all == second then secondOuter = child end
end
local secondObjective = BorderedChild(second.ObjectiveAndRespawn)
local secondDivider
for _, child in ipairs(second.Power.children) do
    if horizontalCalls[child] then secondDivider = child end
end
local protectedDRHost = BorderedChild(protectedDR)
assert(secondOuter and secondDivider and protectedDRHost and borderCalls[protectedDRHost] == 1,
    'genuinely protected BGE decoration was not applied once after combat')
assert(secondObjective and not secondObjective:IsShown(),
    'deferred objective border overwrote the newer hidden/empty state')
assert(colours[secondOuter] and colours[secondOuter][1] == 1 and colours[secondOuter][2] == 0.2,
    'deferred outer border did not adopt the latest target/focus state')
local secondChildren, objectiveChildren = #second.children, #second.ObjectiveAndRespawn.children
T.Fire('PLAYER_REGEN_ENABLED')
T.Flush()
assert(borderCalls[secondOuter] == 1 and horizontalCalls[secondDivider].calls == 1
    and borderCalls[protectedDRHost] == 1 and #second.children == secondChildren
    and #second.ObjectiveAndRespawn.children == objectiveChildren,
    'idle combat end duplicated or reapplied deferred BGE decoration')

EUIAdditionalSkinningDB.skinFeatures = {BattlegroundEnemiesFixed = {
    frames = false, dividers = false, auras = false, icons = false,
}}
local disabled = Player(true)
BGEEnemies:SetupButtonForNewPlayer(disabled)
for _, child in ipairs(disabled.children) do
    assert(borderCalls[child] == nil and horizontalCalls[child] == nil,
        'disabled BattlegroundEnemiesFixed component created decoration work')
end
assert(#T.timers == 0, 'BattlegroundEnemiesFixed skin left recurring or queued work')
print('PASS: BGE native role/raid/castbars, visible icons, recoloured outer highlight and stable recycling')
