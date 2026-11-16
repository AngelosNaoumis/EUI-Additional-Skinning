-- ns.Skin: target waiting, root modes and shells, auto-styled controls, pass order,
-- visible-only walking, combat deferral, gates, events, build merging, looks, fonts, no old-addon guard.
local T = dofile('tests/support.lua')
local ns = T.Load()
local calls, passes = {}, 0

FakeAddon = nil
local window = T.Frame('Frame', nil, 'FakeWindow')
local content, dialog, controls = T.Frame('Frame'), T.Frame('Frame'), T.Frame('Frame')
local button = T.Frame('Button', window); button.label = T.FontString(button, 'Go')
local input = T.Frame('EditBox', window)
local title = T.FontString(window, 'Title')
local hidden = T.Frame('Frame'); hidden.shown = false
local gated = false

ns.Skin('Fake', {
    label = 'Fake Addon',
    available = function() return FakeAddon ~= nil end,
    events = {'FAKE_EVENT'},
    event = function(_, event) calls[#calls + 1] = event end,
    setup = function(C)
        C.AddRoot(window, 'window'); C.AddRoot(content, 'content'); C.AddRoot(dialog, 'dialog')
        C.AddRoot(controls); C.AddRoot(hidden)
    end,
    active = function() return not gated end,
    build = function(C)
        -- Handlers returned here and fields on the spec combine.
        return {
            before = function() passes = passes + 1; calls[#calls + 1] = 'before' end,
            visit = function(_, f, kind)
                if f == window then calls[#calls + 1] = 'visit'; C.H.Font(title) end
            end,
        }
    end,
    after = function() calls[#calls + 1] = 'after' end,
})

-- Registered under the collection prefix; waits for its target addon.
local module = T.Install('Fake')
assert(module.label == 'Fake Addon' and not module.attempted, 'installed without its target')
FakeAddon = {}
T.Fire('ADDON_LOADED'); T.Flush()
assert(module.active and passes == 1, 'did not install once the target loaded')

-- Modes decide the shell; controls are styled by kind; passes run before, visit, after.
assert(window.skin.Shell and next(window.skin.Shell) == nil, 'window shell')
assert(content.skin.Shell.noTopBar and dialog.skin.Shell.bottomBar == 32, 'content/dialog shells')
assert(controls.skin.Shell == nil and hidden.skin.Shell == nil, 'controls roots must not be shelled')
assert(button.skin.Button and input.skin.EditBox.padInput, 'controls not auto-styled')
assert(calls[1] == 'before' and calls[2] == 'visit' and calls[#calls] == 'after', 'pass order')
assert(title.font == 'eui', 'visit font not applied')

-- Warm passes: fonts already in place are not rewritten.
local writes = title.fontWrites
T.Refresh('Fake'); T.Refresh('Fake')
assert(title.fontWrites == writes and passes == 3, 'warm pass rewrote a font')

-- Hidden roots are walked once, then only after they show.
local late = T.Frame('Button', hidden); late.label = T.FontString(late, 'Late')
T.Refresh('Fake'); assert(not late.skin.Button, 'hidden root walked again')
hidden:Show(); T.Flush(); assert(late.skin.Button, 'shown root not styled')

-- Combat defers the pass; leaving combat resumes it once.
T.combat = true
local before = passes
T.Refresh('Fake'); assert(passes == before, 'skinned in combat')
T.combat = false
T.Fire('PLAYER_REGEN_ENABLED'); T.Flush(); assert(passes == before + 1, 'deferred pass did not resume')
T.Fire('PLAYER_REGEN_ENABLED'); T.Flush(); assert(passes == before + 1, 'idle combat end refreshed')

-- Extra events reach the skin and refresh it; EUI look changes refresh it.
T.Fire('FAKE_EVENT'); T.Flush(); assert(calls[#calls] == 'after' and passes == before + 2)
local seen = false
for _, call in ipairs(calls) do if call == 'FAKE_EVENT' then seen = true end end
assert(seen, 'skin event handler not called')
-- Broad events can reject an unrelated occurrence without queuing a pass.
local filteredRuns = 0
ns.Skin('FilteredEvent', {available = function() return true end, events = {'FILTERED_EVENT'},
    event = function(_, _, value) return value == 'wanted' end,
    before = function() filteredRuns = filteredRuns + 1 end})
T.Install('FilteredEvent')
local filteredBaseline = filteredRuns
T.Fire('FILTERED_EVENT', 'unrelated'); T.Flush()
assert(filteredRuns == filteredBaseline, 'rejected event queued a pass')
T.Fire('FILTERED_EVENT', 'wanted'); T.Flush()
assert(filteredRuns == filteredBaseline + 1, 'accepted event did not queue a pass')
for _, fn in ipairs(T.looks) do fn() end
T.Flush(); assert(passes == before + 3, 'look change did not refresh')

-- active() false leaves the target alone for that pass.
gated = true; T.Refresh('Fake'); assert(passes == before + 3, 'gated pass ran')
gated = false

-- ace = true styles AceGUI widgets before the skin's own visit sees them.
local aceRoot = T.Frame('Frame')
local aceFrame = T.Frame('Frame', aceRoot); local aceDrop = T.Frame('Button', aceFrame)
aceFrame.obj = {type = 'Dropdown', frame = aceFrame, dropdown = aceDrop}
local visitedAce = false
ns.Skin('AceUser', {ace = true, available = function() return true end,
    setup = function(C) C.AddRoot(aceRoot) end,
    visit = function(_, f) if f == aceFrame then visitedAce = true end end})
T.Install('AceUser')
assert(aceDrop.skin.Dropdown and not visitedAce, 'ace widget not handled first')

-- Another skinning addon being loaded does not stop a skin (no old-addon guard).
ns.Skin('Unguarded', {available = function() return true end,
    before = function() calls[#calls + 1] = 'unguarded' end})
T.loaded.OtherSkins = true
local unguarded = T.Install('Unguarded')
assert(unguarded.attempted and ns.IsEnabled(unguarded), 'a skin stood down beside another skinning addon')
T.loaded.OtherSkins = nil
print('PASS: ns.Skin target waiting, root modes/shells, auto-styled controls, pass order, font skip, visible-only walks, combat deferral, events/looks, gates, ace flag, no old-addon guard')
