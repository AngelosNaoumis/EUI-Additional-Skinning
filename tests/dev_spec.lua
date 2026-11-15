-- Dev tools, only in Debug Mode (off: no work): probe (textures over a window, draw order, owner; secret values reported unknown, never tested), dump (secret-safe; keys, names, types, sizes, state, anchors, own methods, art, text, truncation, usage) and perf.
local T = dofile('tests/support.lua')
local ns = T.Load()

-- Debug Mode off (the default): the commands answer with a hint and do no work: no dump saved,
-- no frame enumerated, no pass timing.
local enumerated = 0
EnumerateFrames = function() enumerated = enumerated + 1 end
T.Frame('Frame', nil, 'GateWindow').rect = {0, 0, 100, 100}
for _, command in ipairs({'dump GateWindow', 'probe GateWindow', 'probe mouse', 'perf'}) do
    T.chat = {}; SlashCmdList.EUIADDITIONALSKINNING(command)
    assert(T.chat[1] and T.chat[1]:find('Debug Mode is off', 1, true), command .. ' ran with Debug Mode off')
end
assert(enumerated == 0 and not ns.profiling and not (EUIAdditionalSkinningDB and EUIAdditionalSkinningDB.dumps),
    'a dev command worked with Debug Mode off')
EnumerateFrames = nil
ns.DB().debug = true

local window = T.Frame('Frame', nil, 'DumpWindow')
window.width, window.height = 300, 200
window.Refresh = function() end; window.SetView = function() end
window.Inset = T.Frame('Frame', window)
window.Inset.shown = false
window.Icon = T.Texture(window, 'ARTWORK'); window.Icon:SetAtlas('ui-icon')
local label = T.FontString(window, 'Hello'); window.Title = label
local named = T.Frame('Button', window, 'DumpNamedButton'); window.Close = named
named.protected = true
named:SetPoint('TOPRIGHT', window, 'TOPRIGHT', -4.4, -3.6)

SlashCmdList.EUIADDITIONALSKINNING('dump DumpWindow')
local lines = EUIAdditionalSkinningDB.dumps.DumpWindow.lines
local text = table.concat(lines, '\n')
local function has(fragment, message) assert(text:find(fragment, 1, true), message .. '\n' .. text) end
assert(lines[1] == 'DumpWindow Frame 300x200 fn=Refresh,SetView', 'root line: ' .. lines[1])
has('\n  Icon Texture 16x16 ARTWORK atlas=ui-icon', 'texture with key and atlas')
has('\n  Title FontString 16x16 OVERLAY "Hello"', 'font string with text')
has('\n  Inset Frame 100x24 hidden', 'hidden child by key')
has('\n  Close Button 100x24 protected name=DumpNamedButton @TOPRIGHT>parent.TOPRIGHT(-4,-4)',
    'named, keyed, protected, anchored child')
assert(T.chat[#T.chat]:find('Dumped DumpWindow %(5 lines%)'), 'chat confirmation')

-- Long method lists are capped with a count of the rest.
local busy = T.Frame('Frame', nil, 'DumpBusy')
for i = 1, 12 do busy['M' .. string.format('%02d', i)] = function() end end
SlashCmdList.EUIADDITIONALSKINNING('dump DumpBusy')
assert(EUIAdditionalSkinningDB.dumps.DumpBusy.lines[1]:find('fn=M01,M02,M03,M04,M05,M06,M07,M08,M09,M10,+2', 1, true), 'method cap')

-- Large trees are cut off with a note; unknown targets print usage.
local big = T.Frame('Frame', nil, 'DumpBig')
for _ = 1, 700 do T.Frame('Frame', big) end
SlashCmdList.EUIADDITIONALSKINNING('dump DumpBig')
local bigLines = EUIAdditionalSkinningDB.dumps.DumpBig.lines
local function ClearCheck() SlashCmdList.EUIADDITIONALSKINNING('dump clear'); assert(EUIAdditionalSkinningDB.dumps == nil, 'dump clear keeps saved dumps') end
assert(#bigLines == 601 and bigLines[601]:find('truncated'), 'not truncated')
SlashCmdList.EUIADDITIONALSKINNING('dump NoSuchFrame')
assert(T.chat[#T.chat]:find('Usage'), 'usage for an unknown frame')
-- perf: passes are timed only while on; the readout lists each skin and WoW's addon CPU metric.
ns.Skin('Timed', {available = function() return true end, before = function() end})
T.Install('Timed')
T.Refresh('Timed'); assert(not ns.profiling, 'timing on by default')
SlashCmdList.EUIADDITIONALSKINNING('perf'); assert(ns.profiling and T.chat[#T.chat]:find('Pass timing on'))
T.Refresh('Timed'); T.Refresh('Timed')
Enum = {AddOnProfilerMetric = {RecentAverageTime = 1, PeakTime = 2}}
C_AddOnProfiler = {GetAddOnMetric = function(addon, metric) assert(addon == 'EUIAdditionalSkinning'); return metric == 1 and 0.012 or 0.5 end}
local before = #T.chat
SlashCmdList.EUIADDITIONALSKINNING('perf')
local readout = table.concat(T.chat, '\n', before + 1)
assert(readout:find('Timed: 2 passes, [%d.]+ ms average, [%d.]+ ms worst'), readout)
assert(readout:find('Addon CPU %(WoW profiler%): 0.012 ms recent average, 0.50 ms peak'), readout)
SlashCmdList.EUIADDITIONALSKINNING('perf reset'); SlashCmdList.EUIADDITIONALSKINNING('perf'); assert(T.chat[#T.chat - 1]:find('No skin passes'))
SlashCmdList.EUIADDITIONALSKINNING('perf off'); assert(not ns.profiling)
ClearCheck()
print('PASS: dump clear, dump keys/names/types/sizes, hidden/protected, anchors, own methods and cap, atlas and text, truncation, usage; perf timing, readout, profiler metric, reset, off')

-- /eas probe: the textures drawn over a window, top first by strata, level and layer, with owner;
-- small or faint ones are left out; mouse mode keeps only those under the cursor.
local host = T.Frame('Frame', nil, 'ProbeWindow'); host.rect = {100, 100, 400, 300}; host.strata = 'HIGH'; host.level = 100
local bg = T.Texture(host, 'BACKGROUND'); bg.rect = {100, 100, 400, 300}; bg:SetColorTexture(0, 0, 0, 1)
local chrome = T.Frame('Frame', host, 'ProbeChrome'); chrome.strata = 'HIGH'; chrome.level = 101
local veil = T.Texture(chrome, 'OVERLAY'); veil.rect = {90, 90, 420, 320}; veil:SetVertexColor(0, 0, 0, 0.6)
local icon = T.Texture(chrome, 'ARTWORK'); icon.rect = {110, 110, 20, 20}
local faint = T.Texture(chrome, 'ARTWORK'); faint.rect = {100, 100, 400, 300}; faint.alpha = 0
local button = T.Frame('Button', host, 'ProbeButton'); button.strata = 'DIALOG'; button.level = 5
local face = T.Texture(button, 'ARTWORK'); face.rect = {100, 100, 400, 300}
local function Probe(arg)
    T.chat = {}; SlashCmdList.EUIADDITIONALSKINNING('probe ' .. arg)
    local saved = EUIAdditionalSkinningDB.dumps['probe ' .. arg].lines
    local listed = {}
    for i = 2, #saved do listed[i - 1] = saved[i] end
    return listed, saved[1]
end
local probed, note = Probe('ProbeWindow')
assert(#probed == 3, 'probe kept small or faint textures:\n' .. table.concat(probed, '\n'))
assert(probed[1]:find('^1%. DIALOG 5 ARTWORK') and probed[2]:find('^2%. HIGH 101 OVERLAY%+0 alpha=1.00 rgba=0.00,0.00,0.00,0.60 color')
    and probed[3]:find('^3%. HIGH 100 BACKGROUND'), 'probe order or fields:\n' .. table.concat(probed, '\n'))
assert(not probed[2]:find('?', 1, true), 'a readable texture reported as unknown: ' .. probed[2])
assert(probed[2]:find('ProbeChrome.Texture', 1, true), 'owner missing: ' .. probed[2])
assert(probed[2]:find('| frame=ProbeChrome Frame 100x24$'), 'owner frame not described: ' .. probed[2])
assert(note == 'skipped: 0 restricted frames, 0 textures without readable geometry, 0 unreadable frames', 'skip note: ' .. note)
assert(T.chat[1]:find('Probe ProbeWindow: 3 textures, top first') and #T.chat == 4, 'probe chat lines')
-- An unnamed owner is named by its parent keys; a panel one of our skins painted says which rule.
local holder = T.Frame('Frame', host); host.Holder = holder; holder.strata = 'HIGH'; holder.level = 120
holder.backdrop = {bgFile = 'Interface/ChatFrame/ChatFrameBackground'}; ns.PanelSources[holder] = 'Attune backdrop'
local fill = T.Texture(holder, 'BACKGROUND'); fill.rect = {100, 100, 400, 300}
probed = Probe('ProbeWindow')
assert(probed[2]:find('| frame=ProbeWindow.Holder Frame 100x24 bgFile=Interface/ChatFrame/ChatFrameBackground painted=Attune backdrop', 1, true),
    'painted owner not reported:\n' .. table.concat(probed, '\n'))
holder.shown = false
GetMouseFoci = function() return {button} end
GetCursorPosition = function() return 115, 115 end
local under = Probe('mouse')
assert(#under == 4 and under[3]:find('HIGH 101 ARTWORK'), 'mouse probe: textures under the cursor\n' .. table.concat(under, '\n'))

-- Secret values (12.x restricted frames): any test, comparison, arithmetic, concatenation or
-- formatting of one is an error in game. The stand-in raises on every operation Lua lets a
-- table trap; boolean tests can't be trapped, so those cases are checked by their "?" markers.
local SECRET_MT = {}
for _, event in ipairs({'__eq', '__lt', '__le', '__add', '__sub', '__mul', '__div', '__unm', '__concat', '__len',
    '__index', '__newindex', '__call', '__tostring'}) do
    SECRET_MT[event] = function() error('attempt to use a secret value') end
end
local function Secret() return setmetatable({}, SECRET_MT) end
issecretvalue = function(v) return type(v) == 'table' and getmetatable(v) == SECRET_MT end
local function Returns(...) local values = {...}; return function() return table.unpack(values) end end
-- Frame filtering: an unreadable forbidden state skips the frame (counted), its textures unread.
local restricted = T.Frame('Frame', host); restricted.IsForbidden = Returns(Secret())
local hidden = T.Texture(restricted, 'OVERLAY'); hidden.rect = {100, 100, 400, 300}
-- Visibility: a secret IsVisible keeps the frame's textures, marked vis=?.
local secretShown = T.Frame('Frame', host); secretShown.strata = 'HIGH'; secretShown.level = 102
secretShown.IsVisible = Returns(Secret())
local dim = T.Texture(secretShown, 'OVERLAY'); dim.rect = {100, 100, 400, 300}
-- Sorting: a secret strata and frame level leave the texture unordered (order=?, after the ordered ones).
local unordered = T.Frame('Frame', host); unordered.GetFrameStrata = Returns(Secret()); unordered.GetFrameLevel = Returns(Secret())
local loose = T.Texture(unordered, 'OVERLAY'); loose.rect = {100, 100, 400, 300}
-- Texture enumeration and report: secret layer, alpha, colour and atlas each print as unknown.
local opaque = T.Texture(chrome, 'OVERLAY'); opaque.rect = {100, 100, 400, 300}
opaque.GetDrawLayer = Returns(Secret(), Secret()); opaque.GetAlpha = Returns(Secret())
opaque.GetVertexColor = Returns(Secret(), Secret(), Secret(), Secret()); opaque.GetAtlas = Returns(Secret())
opaque.GetTexture = Returns(Secret()); opaque.GetDebugName = Returns(Secret())
-- Geometry: a secret rectangle can't be placed (counted); a secret scale falls back to 1.
local nowhere = T.Texture(chrome, 'OVERLAY'); nowhere.GetRect = Returns(Secret(), 0, 10, 10)
chrome.GetEffectiveScale = Returns(Secret())
-- A frame that raises on any access is contained at its first read (counted restricted), the rest still listed.
local broken = setmetatable({}, {__index = function() error('broken frame') end})
host.children[#host.children + 1] = broken
GetMouseFoci = nil
probed, note = Probe('ProbeWindow')
local text = table.concat(probed, '\n')
assert(note == 'skipped: 2 restricted frames, 1 textures without readable geometry, 0 unreadable frames', 'secret skip note: ' .. note)
assert(not text:find('OVERLAY', 1, true) or #probed == 6, 'secret probe count:\n' .. text)
assert(probed[1]:find('^1%. DIALOG') and probed[2]:find('^2%. HIGH 102 OVERLAY%+0 .* vis=%?'),
    'secret visibility not kept and marked:\n' .. text)
assert(probed[3]:find('^3%. HIGH 101 OVERLAY') and probed[4]:find('^4%. HIGH 100'), 'ordered textures out of order:\n' .. text)
local unknown = {probed[5], probed[6]}
table.sort(unknown)
local joined = table.concat(unknown, '\n')
assert(joined:find('? ? OVERLAY+0 alpha=1.00 rgba=1.00,1.00,1.00,1.00 color order=?', 1, true),
    'secret strata and level not reported unknown:\n' .. text)
assert(joined:find('HIGH 101 ?? alpha=? rgba=? color order=? ProbeChrome.Texture', 1, true),
    'secret layer, alpha, colour, art or owner not reported unknown:\n' .. text)
-- Mouse mode: a secret parent stops the climb at the focus; a secret cursor ends with a message.
GetMouseFoci = function() return {dim} end
dim.GetParent = Returns(Secret())
dim.GetRect = Returns(100, 100, 300, 200)
GetCursorPosition = Returns(Secret(), Secret())
T.chat = {}; SlashCmdList.EUIADDITIONALSKINNING('probe mouse')
assert(T.chat[#T.chat]:find('cursor position unavailable', 1, true), 'secret cursor: ' .. tostring(T.chat[#T.chat]))
-- /eas dump reads through the same guard: secret name, size and shown state, no error.
local secretDump = T.Frame('Frame', nil, 'DumpSecret')
secretDump.GetWidth = Returns(Secret()); secretDump.IsShown = Returns(Secret()); secretDump.GetName = Returns(Secret())
secretDump.GetNumPoints = Returns(Secret())
SlashCmdList.EUIADDITIONALSKINNING('dump DumpSecret')
local dumped = EUIAdditionalSkinningDB.dumps.DumpSecret.lines[1]
assert(dumped:find('^#1 Frame shown=%? fn='), 'secret dump line: ' .. dumped)
issecretvalue = nil
