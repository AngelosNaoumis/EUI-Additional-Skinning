-- LagBuddy: comprehensive scoped styling, lazy dialogs, cached passes and no metric hooks.
local T = dofile('tests/support.lua')
local ns = T.Load('Skins/LagBuddy.lua')
UIParent = T.Frame('Frame', nil, 'UIParent')
local METAL = 'Interface\\Tooltips\\UI-Tooltip-Border'
T.enabled.LagBuddy = true
T.Fire('ADDON_LOADED', T.ADDON)

local function Popup(name)
    local frame = T.Frame('Frame', UIParent, name)
    frame.backdrop = {bgFile = 'Interface/DialogFrame/UI-DialogBox-Background', edgeFile = METAL, edgeSize = 24}
    local scroll = T.Frame('ScrollFrame', frame)
    scroll.ScrollBar = T.Frame('Slider', scroll)
    return frame
end

SlashCmdList.LAGBUDDY = function(msg)
    if msg == 'settings' then _G.LagBuddyGameSettingsFrame = _G.LagBuddyGameSettingsFrame or Popup('LagBuddyGameSettingsFrame')
    elseif msg == 'results' then _G.LagBuddyCaptureResultsFrame = _G.LagBuddyCaptureResultsFrame or Popup('LagBuddyCaptureResultsFrame') end
end

T.Install('LagBuddy')
local main = T.Frame('Frame', UIParent, 'LagBuddyMainFrame')
main.backdrop = {bgFile = 'Interface/DialogFrame/UI-DialogBox-Background', edgeFile = METAL, edgeSize = 24}
local action = T.Frame('Button', main); action.label = T.FontString(action, 'Run Deep Analysis')
local actionClicks = 0; action:SetScript('OnClick', function() actionClicks = actionClicks + 1 end)
local results = T.Frame('Button', main); results.label = T.FontString(results, 'Analysis Results')
results:SetScript('OnClick', function()
    _G.LagBuddyCaptureResultsFrame = _G.LagBuddyCaptureResultsFrame or Popup('LagBuddyCaptureResultsFrame')
end)
local panel = T.Frame('Frame', main); panel.backdrop = {bgFile = 'dark', edgeFile = METAL, edgeSize = 12}
local toggle = T.Frame('Button', main); toggle.backdrop = {bgFile = 'state', edgeFile = METAL, edgeSize = 12}
toggle.label = T.FontString(toggle, 'MONITORING')
local metricUpdates = 0
function main:RefreshMetrics() metricUpdates = metricUpdates + 1 end
local treeReads, getNumChildren = 0, main.GetNumChildren
function main:GetNumChildren() treeReads = treeReads + 1; return getNumChildren(self) end

T.combat = true
T.Fire('PLAYER_LOGIN')
T.Flush()
assert(not main.skin.Shell, 'LagBuddy main window was modified during combat')
T.combat = false
T.Fire('PLAYER_REGEN_ENABLED')
T.Flush()
assert(main.skin.Shell, 'LagBuddy main window not shelled after login construction')
assert(action.skin.Button, 'LagBuddy action button not styled')
assert(panel.backdrop.edgeSize == 1, 'LagBuddy monitor panel did not receive a thin edge')
assert(toggle.backdrop.edgeSize == 1 and not toggle.skin.Button, 'semantic monitoring toggle colors were not preserved')
action:GetScript('OnClick')(action); T.Flush()
assert(actionClicks == 1, 'LagBuddy action changed')
local initialReads = treeReads
action:GetScript('OnClick')(action)
assert(#T.timers == 0 and treeReads == initialReads, 'ordinary LagBuddy click queued a structural tree scan')
for _ = 1, 10 do main:Hide(); main:Show(); T.Flush() end
assert(treeReads == initialReads, 'reopening LagBuddy repeated its structural tree walk')

SlashCmdList.LAGBUDDY('settings'); T.Flush()
results:GetScript('OnClick')(results); T.Flush()
assert(_G.LagBuddyGameSettingsFrame.skin.Shell and _G.LagBuddyCaptureResultsFrame.skin.Shell,
    'LagBuddy lazy settings/results dialog not shelled')
_G.LagBuddyCaptureResultsFrame = Popup('LagBuddyCaptureResultsFrame')
results:GetScript('OnEnable')(results); T.Flush()
assert(_G.LagBuddyCaptureResultsFrame.skin.Shell, 'automatic analysis-results enable signal did not skin its new dialog')
for _ = 1, 20 do main:RefreshMetrics() end
assert(metricUpdates == 20 and #T.timers == 0, 'skin hooked metric refreshes or left recurring work')

EUIAdditionalSkinningDB.skins = {LagBuddy = false}
_G.LagBuddyCaptureResultsFrame = Popup('LagBuddyCaptureResultsFrame')
results:GetScript('OnEnable')(results)
T.Flush()
assert(not _G.LagBuddyCaptureResultsFrame.skin.Shell, 'disabled LagBuddy skin styled a new results frame')
print('PASS: LagBuddy comprehensive styling covers main/lazy dialogs once, preserves stateful controls and stays inert across reopen, metric and disabled paths')
