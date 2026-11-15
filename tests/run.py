"""Lint, compile every addon file, then run each tests/*_spec.lua in its own Lua state.

Lua 5.1 by default, the version WoW runs: the compile step also enforces 5.1's syntax and its
limits of 60 upvalues per function and 200 locals in scope (an overflow stops a whole file from
loading in game). Specs get table.pack/table.unpack shims; the addon code gets nothing extra.

    pip install lupa
    python tests/run.py              # Lua 5.1, as in game
    python tests/run.py --lua 5.4    # the same specs on a newer Lua
"""
import argparse
import importlib
import os
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--lua', default='5.1', choices=['5.1', '5.4'])
args = parser.parse_args()
lupa = importlib.import_module('lupa.lua51' if args.lua == '5.1' else 'lupa.lua54')

# Addon code only: tests, benchmarks, scripts and templates are not loaded by WoW.
sources = sorted(p for p in root.rglob('*.lua')
                 if not {'tests', 'benchmarks', 'scripts', 'dist', '.git'} & set(p.relative_to(root).parts))
specs = sorted((root / 'tests').glob('*_spec.lua'))
SHIMS = '''
table.unpack = table.unpack or unpack
table.pack = table.pack or function(...) return {n = select('#', ...), ...} end
'''


def state():
    lua = lupa.LuaRuntime()
    lua.execute(SHIMS)
    return lua.eval('function(path, compileOnly) local f, e = loadfile(path); if not f then error(e, 0) end;'
                    ' if not compileOnly then f() end end')


os.chdir(root)
lint = subprocess.run([sys.executable, 'scripts/lint.py'])
failed = False
compile_file = state()
for path in sources:
    try:
        compile_file(path.relative_to(root).as_posix(), True)
    except lupa.LuaError as error:
        print(f'FAIL compile (Lua {args.lua}): {error}')
        failed = True
for spec in specs:
    try:
        state()(spec.relative_to(root).as_posix())
    except lupa.LuaError as error:
        print(f'FAIL {spec.name}: {error}')
        failed = True
# Python tool tests (scripts/): each tests/test_*.py exits non-zero on failure.
for test in sorted((root / 'tests').glob('test_*.py')):
    if subprocess.run([sys.executable, str(test)]).returncode:
        print(f'FAIL {test.name}')
        failed = True
if failed or lint.returncode:
    sys.exit(1)
print(f'All {len(specs)} specs passed on Lua {args.lua} ({len(sources)} addon files compiled)')
