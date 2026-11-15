-- What's Training?: embedded in the Spellbook, so no window shell (no second background or border), controls styled, spell icons squared, its Refresh post-hooked, warm passes create nothing, nothing when its EUI toggle is off.
local T = dofile('tests/support.lua')
local ns = T.Load('Skins/WhatsTraining.lua')

local overlay = T.Frame('Frame', nil, 'WhatsTrainingOverlay') -- parented to the Spellbook in game
local window = T.Frame('Frame', overlay, 'WhatsTrainingFrame')
local filter = T.Frame('Button', window); filter.label = T.FontString(filter, 'All')
local refreshed = 0
function window:Refresh() refreshed = refreshed + 1 end
local row = T.Frame('Button', window)
row.spell = {icon = T.Texture(row)}

T.Install('WhatsTraining')
assert(not window.skin.Shell and not overlay.skin.Shell, 'a window shell covers the Spellbook page')
assert(filter.skin.Button, 'controls inside the page not styled')
assert(row.spell.icon.skin and row.spell.icon.skin.SquareIcon, 'spell icon not squared')
window:Refresh()
assert(refreshed == 1 and #T.timers > 0, 'Refresh hook missing or replaced the original')
T.Flush()
local regions = #window.regions
T.Refresh('WhatsTraining'); T.Refresh('WhatsTraining')
assert(#window.regions == regions, 'warm pass created regions')

-- A second load with its EUI toggle off installs nothing.
local T2 = dofile('tests/support.lua')
T2.S.IsEnabled = function() return false end
T2.Load('Skins/WhatsTraining.lua')
local other = T2.Frame('Frame', nil, 'WhatsTrainingFrame')
T2.loaded.WhatsTraining = true
T2.Fire('ADDON_LOADED', 'WhatsTraining')
T2.registered[T2.PREFIX .. "What's Training?"](T2.S); T2.Flush()
assert(not other.skin.Shell and #T2.ns.modules == 0, 'installed with its EUI toggle off')
print("PASS: What's Training? no shell inside the Spellbook, controls styled, squared spell icons, post-hooked Refresh, warm passes, EUI toggle off")
