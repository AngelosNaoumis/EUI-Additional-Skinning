"""read_dump.py: a dump read from WTF saved variables round-trips through --spec back into the same dump."""
import re
import sys
import tempfile
from pathlib import Path

import lupa.lua51 as lupa

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'scripts'))
import read_dump  # noqa: E402

SHIMS = "table.unpack = table.unpack or unpack\ntable.pack = table.pack or function(...) return {n = select('#', ...), ...} end\n"
BUILD = '''
local T = dofile('tests/support.lua')
T.Load()
local w = T.Frame('Frame', nil, 'RoundTrip'); w.width, w.height = 320, 240
w.Refresh = function() end
w.Inset = T.Frame('Frame', w); w.Inset.shown = false
w.Icon = T.Texture(w, 'ARTWORK'); w.Icon:SetAtlas('ui-icon')
w.Title = T.FontString(w, 'Say "hi"')
w.Close = T.Frame('Button', w, 'RoundTripClose'); w.Close.label = T.FontString(w.Close, 'X')
local deep = T.Frame('Frame', w.Inset); deep.Spinner = T.Texture(deep, 'OVERLAY')
EUIAdditionalSkinningDB = EUIAdditionalSkinningDB or {}; EUIAdditionalSkinningDB.debug = true; SlashCmdList.EUIADDITIONALSKINNING('dump RoundTrip')
return T
'''


def state():
    lua = lupa.LuaRuntime()
    lua.execute(SHIMS)
    return lua


def dump_lines(lua):
    lines = lua.globals().EUIAdditionalSkinningDB['dumps']['RoundTrip']['lines']
    return [lines[i] for i in range(1, len(lines) + 1)]


def without_anchors(lines):
    return [re.sub(r' @\S+', '', line) for line in lines]


import os  # noqa: E402
os.chdir(root)
original = state()
original.execute(BUILD)
lines = dump_lines(original)

# Saved variables as WoW writes them, read back through the script.
with tempfile.TemporaryDirectory() as wtf:
    saved = Path(wtf) / 'Account' / 'TEST' / 'SavedVariables'
    saved.mkdir(parents=True)
    body = ',\n'.join('%s' % original.eval('function(s) return string.format("%q", s) end')(line) for line in lines)
    (saved / 'EUIAdditionalSkinning.lua').write_text(
        'EUIAdditionalSkinningDB = {["dumps"] = {["RoundTrip"] = {["time"] = 1, ["lines"] = {\n' + body + '\n}}}}\n')
    dumps = read_dump.load(wtf)
assert dumps['RoundTrip'][1] == lines, 'saved variables not read back verbatim'

# The fixture rebuilds a tree that dumps the same (anchors aside: fixtures don't set them).
fixture = read_dump.fixture('RoundTrip', lines)
rebuilt = state()
rebuilt.execute("local T = dofile('tests/support.lua'); T.Load()\n" + fixture +
                "\nEUIAdditionalSkinningDB = EUIAdditionalSkinningDB or {}; EUIAdditionalSkinningDB.debug = true; SlashCmdList.EUIADDITIONALSKINNING('dump RoundTrip')")
again = dump_lines(rebuilt)
assert without_anchors(again) == without_anchors(lines), '\n'.join(['round trip differs:'] + lines + ['---'] + again)
print('PASS: read_dump loads WTF saved variables and --spec fixtures round-trip to the same dump')
