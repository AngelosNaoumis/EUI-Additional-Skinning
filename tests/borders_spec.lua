-- Shared configured borders remain independent from the Naowh Forever target addon and its toggle.
local T = dofile('tests/support.lua')
local applied, colours = {}, {}
EllesmereUI.ApplyBorderStyle = function(frame, ...)
    applied[frame] = (applied[frame] or 0) + 1
    frame.configuredStyle = {...}
    EllesmereUI._bdBorderData = EllesmereUI._bdBorderData or setmetatable({}, {__mode = 'k'})
    EllesmereUI._bdBorderData[frame] = EllesmereUI._bdBorderData[frame] or T.Frame('Frame', frame)
end
EllesmereUI.SetBorderStyleColor = function(frame, ...)
    colours[frame] = {...}
end

EUIAdditionalSkinningDB = {skins = {NaowhForever = false}}
local ns = T.Load()
local style = {size = 1, texture = 'solid', r = 0, g = 0, b = 0, a = 1}
ns.SetConfiguredBorderStyleProvider(function() return style end)
assert(not T.loaded.NaowhForever and not ns.IsSwitchedOn('NaowhForever'),
    'test precondition did not represent absent/disabled Naowh Forever')

local first, second = T.Frame('Frame'), T.Frame('Frame')
assert(ns.ApplyConfiguredBorder(first) and ns.ApplyConfiguredBorder(second),
    'shared borders depended on the Naowh Forever target being installed or enabled')
assert(EUIAdditionalSkinningDB.naowh == nil,
    'standalone shared borders created Naowh Forever SavedVariables')
assert(applied[first] == 1 and applied[second] == 1, 'shared border was not created once per owner')
assert(ns.OwnFrames[EllesmereUI._bdBorderData[first]],
    'the textured border child was exposed to the generic skin walker')
assert(ns.ApplyConfiguredBorder(first) and applied[first] == 1, 'shared border lifecycle was not idempotent')

local borderChild = EllesmereUI._bdBorderData[first]
style.size, style.texture, style.a = 3, 'changed-border', 0.6
assert(ns.ApplyConfiguredBorder(first) and applied[first] == 2
    and EllesmereUI._bdBorderData[first] == borderChild,
    'a configured style change did not update the existing border in place')
assert(ns.ApplyConfiguredBorder(first) and applied[first] == 2,
    'an unchanged configured style rebuilt the border')

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
