-- Existing BGE combat update hot path: colour/visibility changes and row recycling must allocate no
-- new decoration or queue work. This is a mock-host measurement, not WoW CPU/FPS profiling.
local T = dofile('tests/support.lua')
hooksecurefunc = function(object, key, callback)
    local original = object[key]
    object[key] = function(...)
        local a, b, c, d, e = original(...)
        callback(...)
        return a, b, c, d, e
    end
end
local ns = T.Load('Skins/BattlegroundEnemiesFixed.lua')
UIParent = T.Frame('Frame', nil, 'UIParent')

local counts = {borders = 0, dividers = 0, colours = 0, shown = 0}
ns.ApplyConfiguredBorder = function() counts.borders = counts.borders + 1; return true end
ns.ApplyConfiguredDividerH = function() counts.dividers = counts.dividers + 1; return true end
ns.SetConfiguredBorderColor = function() counts.colours = counts.colours + 1; return true end

BattleGroundEnemies = T.Frame('Frame', UIParent, 'BattleGroundEnemies')
BattleGroundEnemies.db = {profile = {
    MyTarget_Color = {1, 0.2, 0.1, 1}, MyFocus_Color = {0.1, 0.8, 0.6, 1},
}}
BGEEnemies = T.Frame('Button', UIParent, 'BGEEnemies')
BGEEnemies.PlayerList = {}
BattleGroundEnemies.Enemies = BGEEnemies

local function Icon(parent, shown, texture, alpha)
    local frame = T.Frame('Frame', parent)
    frame.Icon = T.Texture(frame)
    frame.Icon:SetTexture(texture)
    frame.Icon:SetAlpha(alpha or 1)
    if shown then frame:Show() else frame:Hide() end
    return frame
end

local function Player()
    local button = T.Frame('Button', BGEEnemies)
    button.protected, button.PlayerIsEnemy = true, true
    button.Power = T.Frame('StatusBar', button)
    button.SpecClassPriority = T.Frame('Frame', button)
    button.Trinket = Icon(button, true, 'trinket', 1)
    button.ObjectiveAndRespawn = Icon(button, false, nil, 1)
    button.Role = Icon(button, true, 'role', 1)
    button.RaidTargetIcon = Icon(button, true, 'raid', 1)
    button.CombatIndicator = T.Frame('Frame', button)
    button.CombatIndicator.Combat = T.Frame('Frame', button.CombatIndicator)
    button.CombatIndicator.OutOfCombat = T.Frame('Frame', button.CombatIndicator)
    button.MyTarget = T.Frame('Frame', button); button.MyTarget:Hide()
    button.MyFocus = T.Frame('Frame', button); button.MyFocus:Hide()
    button.DRTracking = T.Frame('Frame', button)
    button.DRTracking.childFrames = {T.Frame('Frame', button.DRTracking)}
    function button.DRTracking:NewInput() end
    button.CastBar = T.Frame('Frame', button)
    return button
end

function BGEEnemies:SetupButtonForNewPlayer(button)
    button.MyTarget:Hide()
    button.MyFocus:Hide()
    self.PlayerList[1] = button
    button:Show()
end

local player = Player()
BGEEnemies.PlayerList[1] = player
T.Install('BattlegroundEnemiesFixed')
local trinketHost
for _, child in ipairs(player.Trinket.children) do
    if child.all == player.Trinket.Icon then trinketHost = child end
end
assert(trinketHost, 'trinket host missing')
local setShown = trinketHost.SetShown
function trinketHost:SetShown(value)
    counts.shown = counts.shown + 1
    return setShown(self, value)
end

counts.borders, counts.dividers, counts.colours, counts.shown = 0, 0, 0, 0
T.combat = true
collectgarbage('collect'); collectgarbage('stop')
local heap, started = collectgarbage('count'), os.clock()
for index = 1, 10000 do
    player.MyFocus:Show()
    player.MyTarget:Show()
    player.MyTarget:Hide()
    player.MyFocus:Hide()
    player.Trinket.Icon:SetTexture(index % 2 == 0 and 'trinket' or nil)
    BGEEnemies:SetupButtonForNewPlayer(player)
end
local elapsed, allocated = os.clock() - started, collectgarbage('count') - heap
collectgarbage('restart')
assert(counts.borders == 0 and counts.dividers == 0 and #T.timers == 0,
    'warm combat updates created decoration or queued work')
print(string.format('MEASURE %.6f %.3f %d %d %d %d %d', elapsed, allocated, counts.borders,
    counts.dividers, counts.colours, counts.shown, #T.timers))
