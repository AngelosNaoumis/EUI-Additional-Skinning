-- Shared configured borders remain independent from the Naowh Forever target addon and its toggle.
local T = dofile('tests/support.lua')
local applied, colours = {}, {}
EllesmereUI.ApplyBorderStyle = function(frame, ...)
    applied[frame] = (applied[frame] or 0) + 1
    frame.configuredStyle = {...}
end
EllesmereUI.SetBorderStyleColor = function(frame, ...)
    colours[frame] = {...}
end

EUIAdditionalSkinningDB = {skins = {NaowhForever = false}}
local ns = T.Load()
assert(not T.loaded.NaowhForever and not ns.IsSwitchedOn('NaowhForever'),
    'test precondition did not represent absent/disabled Naowh Forever')

local first, second = T.Frame('Frame'), T.Frame('Frame')
assert(ns.ApplyConfiguredBorder(first) and ns.ApplyConfiguredBorder(second),
    'shared borders depended on the Naowh Forever target being installed or enabled')
assert(EUIAdditionalSkinningDB.naowh == nil,
    'standalone shared borders created Naowh Forever SavedVariables')
assert(applied[first] == 1 and applied[second] == 1, 'shared border was not created once per owner')
assert(ns.ApplyConfiguredBorder(first) and applied[first] == 1, 'shared border lifecycle was not idempotent')

assert(ns.SetConfiguredBorderColor(first, 1, 0.2, 0.1, 1)
    and colours[first][1] == 1 and colours[first][2] == 0.2,
    'independent highlight colour was not applied')
assert(not colours[second], 'one border tint leaked into another border owner')
assert(ns.SetConfiguredBorderColor(first) and colours[first][1] == 0 and colours[first][2] == 0,
    'configured normal border colour was not restored')

ns.Naowh = nil
local third = T.Frame('Frame')
assert(ns.ApplyConfiguredBorder(third) and applied[third] == 1,
    'shared border lifecycle required the public Naowh integration namespace')
print('PASS: configured border ownership, colour and lifecycle are independent from Naowh Forever')
