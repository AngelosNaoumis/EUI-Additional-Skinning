-- Lua 5.1 headroom: every skin handler stays at or under 50 upvalues (the hard limit is 60, and one
-- overflow stops the whole file from loading in game), so a growing skin is split in time.
local T = dofile('tests/support.lua')
local ns = T.Load()
local CEILING = 50
local specs = {}
local Skin = ns.Skin
ns.Skin = function(id, spec) specs[id] = spec; return Skin(id, spec) end
local toc = assert(io.open(T.TOC)):read('*a')
for line in toc:gmatch('[^\r\n]+') do
    local path = line:gsub('\\', '/')
    if path:match('^Skins/') then assert(loadfile(T.DIR .. path))('EUIAdditionalSkinning', ns) end
end
-- Skins load lazily: run each factory so the ns.Skin specs register.
for _, entry in ipairs(ns.skinCatalog) do if entry.factory then entry.factory() end end

local checked, report = 0, {}
for id, spec in pairs(specs) do
    local S = spec.style and spec.style(T.S, {skin = T.S}) or T.S
    local C = {S = S, H = ns.CreateSkinHelper(S, {skin = T.S}), module = {}, refresh = function() end, AddRoot = function() end}
    local handlers = spec.build and spec.build(C) or {}
    for key, value in pairs(spec) do if handlers[key] == nil then handlers[key] = value end end
    for key, fn in pairs(handlers) do
        if type(fn) == 'function' then
            local ups = debug.getinfo(fn).nups
            checked = checked + 1
            report[#report + 1] = string.format('%s.%s=%d', id, key, ups)
            assert(ups <= CEILING, string.format('%s.%s captures %d upvalues (limit 60): move a group of its helpers '
                .. 'into a table or a separate local function before it stops the file loading', id, key, ups))
        end
    end
end
assert(checked > 0, 'no skin handlers checked')
table.sort(report)
print('PASS: Lua 5.1 upvalue headroom (<= ' .. CEILING .. '): ' .. table.concat(report, ' '))
