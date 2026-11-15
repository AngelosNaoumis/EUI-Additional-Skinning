-- Forever Dungeon Journal: waits for its namespace, installs once, post-hooks its exports (originals still run), the legacy quest worker repaints on hide instead of every frame, and no worker hook when the renderers are exported.
local T = dofile('tests/support.lua')
local ns = T.Load('Skins/ForeverDungeonJournal.lua')

-- The namespace is not there yet: the skin waits.
local entry = ns.skinCatalogByID.ForeverDungeonJournal
T.loaded.ForeverDungeonJournal = true
T.Fire('ADDON_LOADED', 'ForeverDungeonJournal')
T.registered[T.PREFIX .. entry.label](T.S); T.Flush()
assert(#ns.modules == 1 and not ns.modules[1].attempted, 'installed before its namespace existed')

-- An older journal: no exported quest renderers, a one-shot worker frame instead.
local toggles = 0
local worker = T.Frame('Frame')
ForeverDungeonJournal_NS = {ToggleJournal = function() toggles = toggles + 1 end, questRefreshWorker = worker}
T.Fire('ADDON_LOADED', 'ForeverDungeonJournal'); T.Flush()
local module = T.Module('ForeverDungeonJournal')
assert(module.active, 'did not install once its namespace existed')
assert(worker.scripts.OnHide and not worker.scripts.OnUpdate, 'worker must repaint on hide, never per frame')
ForeverDungeonJournal_NS.ToggleJournal()
assert(toggles == 1 and #T.timers > 0, 'ToggleJournal hook missing or replaced the original')
T.Flush()
worker:Hide()
assert(#T.timers > 0, 'worker hide queued no refresh'); T.Flush()

-- A current journal exports its renderers: no worker hook at all.
local T2 = dofile('tests/support.lua')
local ns2 = T2.Load('Skins/ForeverDungeonJournal.lua')
local worker2 = T2.Frame('Frame')
ForeverDungeonJournal_NS = {ToggleJournal = function() end, questRefreshWorker = worker2,
    RefreshQuestList = function() end, RefreshQuestDetail = function() end}
T2.Install('ForeverDungeonJournal')
assert(T2.Module('ForeverDungeonJournal').active and not worker2.scripts.OnHide and not worker2.scripts.OnUpdate,
    'worker hooked although the renderers are exported')
print('PASS: Forever Dungeon Journal namespace wait, single install, post-hooked exports, worker repaint on hide only for legacy journals')
