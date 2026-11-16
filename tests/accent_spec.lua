-- Additional Skinning never adds a top accent texture or look-change callback; shells and all
-- other accent-coloured primitives remain available. The retained API entry point is idempotent.
local T = dofile('tests/support.lua')
local ns = T.Load()
local frame = T.Frame('Frame', nil, 'AccentRegressionWindow')
local regionCount, callbackCount = #frame.regions, #T.looks

ns.AttachAccent(T.S, frame)
ns.AttachAccent(T.S, frame)
assert(#frame.regions == regionCount, 'top accent texture was allocated')
assert(#T.looks == callbackCount, 'top accent registered a look-change callback')

local H = ns.CreateSkinHelper(T.S, {})
H.Shell(frame, function() end)
H.Shell(frame, function() end)
assert(frame.skin.Shell, 'removing the accent also removed the window shell')
assert(#frame.regions == regionCount, 'shell attached a top accent or duplicated a region')

print('PASS: shared shell adds no top accent texture/callback and remains idempotent')
