"""Print frame maps saved in game with /eas dump <Frame | mouse>.

WoW writes saved variables on /reload or logout. This reads EUIAdditionalSkinning.lua from every
account under the client's WTF folder (or --wtf), newest first.

    python scripts/read_dump.py                          # list saved dumps
    python scripts/read_dump.py AuctionatorShoppingFrame # print one
    python scripts/read_dump.py AuctionatorShoppingFrame --spec   # Lua fixture for tests/support.lua
    python scripts/read_dump.py AuctionatorShoppingFrame --out some/file.txt
"""
import argparse
import datetime
import re
import sys
from pathlib import Path

import lupa.lua51 as lupa

root = Path(__file__).resolve().parents[1]
REGIONS = {'Texture', 'FontString', 'MaskTexture', 'Line'}
LAYERS = {'BACKGROUND', 'BORDER', 'ARTWORK', 'OVERLAY', 'HIGHLIGHT'}
TOKEN = re.compile(r'"(?:[^"\\]|\\.)*"|\S+')
IDENT = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')


def load(wtf):
    files = sorted(Path(wtf).glob('Account/*/SavedVariables/EUIAdditionalSkinning.lua'),
                   key=lambda p: p.stat().st_mtime, reverse=True)
    if not files:
        sys.exit(f'No EUIAdditionalSkinning saved variables under {wtf}. Dump in game, then /reload.')
    dumps = {}
    for path in files:
        lua = lupa.LuaRuntime()
        lua.execute(path.read_text(encoding='utf-8', errors='replace'))
        db = lua.globals().EUIAdditionalSkinningDB
        saved = db and db['dumps']
        for name, dump in (saved.items() if saved else []):
            if name not in dumps:
                lines = [dump['lines'][i] for i in range(1, len(dump['lines']) + 1)]
                dumps[name] = (dump['time'] or 0, lines, path)
    return dumps


def fixture(name, lines):
    """Lua rebuilding the dumped tree with tests/support.lua: one F[n] per object, attached to its
    parent under its key, with global names, sizes, hidden/protected state, atlas, text and
    no-op stubs for the frame's own methods, so a spec mirrors the real layout."""
    out = [f'-- Fixture from /eas dump {name} (python scripts/read_dump.py {name} --spec).',
           'local F, NOOP = {}, function() end']
    parents = []
    for index, line in enumerate(lines, 1):
        if line.startswith('...'):
            out.append(f'-- {line}')
            continue
        depth = (len(line) - len(line.lstrip(' '))) // 2
        tokens = TOKEN.findall(line.strip())
        label, kind, rest = tokens[0], tokens[1], tokens[2:]
        del parents[depth:]
        parent = parents[-1] if parents else None
        owner = f'F[{parent}]' if parent else 'nil'
        ref = f'F[{index}]'
        text = next((t for t in rest if t.startswith('"')), None)
        if kind in REGIONS:
            if kind == 'FontString':
                out.append(f'{ref} = T.FontString({owner}, {text or "nil"})')
            else:
                layer = next((t for t in rest if t in LAYERS), None)
                out.append(f"{ref} = T.Texture({owner}, {repr(layer) if layer else 'nil'}, {kind!r})")
                atlas = next((t[6:] for t in rest if t.startswith('atlas=')), None)
                if atlas:
                    out.append(f'{ref}:SetAtlas({atlas!r})')
        else:
            global_name = next((t[5:] for t in rest if t.startswith('name=')), None)
            if parent is None and not label.startswith('#'):
                global_name = label
            named = f', {global_name!r}' if global_name else ''
            out.append(f'{ref} = T.Frame({kind!r}, {owner}{named})')
            size = next((t for t in rest if re.fullmatch(r'\d+x\d+', t)), None)
            if size:
                width, height = size.split('x')
                out.append(f'{ref}.width, {ref}.height = {width}, {height}')
            if 'hidden' in rest:
                out.append(f'{ref}.shown = false')
            if 'protected' in rest:
                out.append(f'{ref}.protected = true')
            if text and kind == 'Button':
                out.append(f'{ref}.label = T.FontString({ref}, {text})')
            methods = next((t[3:] for t in rest if t.startswith('fn=')), '')
            for method in methods.split(','):
                if IDENT.fullmatch(method):
                    out.append(f'{ref}.{method} = NOOP')
            parents.append(index)
        if parent and IDENT.fullmatch(label):
            out.append(f'F[{parent}].{label} = {ref}')
    return '\n'.join(out) + '\n'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('name', nargs='?')
    parser.add_argument('--wtf', default=str(root.parents[2] / 'WTF'), help='the client WTF folder')
    parser.add_argument('--spec', action='store_true', help='print a tests/support.lua fixture that rebuilds the tree')
    parser.add_argument('--out', help='also write the output to this file')
    args = parser.parse_args()
    dumps = load(args.wtf)
    if not args.name:
        for name, (stamp, lines, path) in sorted(dumps.items()):
            when = datetime.datetime.fromtimestamp(stamp).strftime('%Y-%m-%d %H:%M') if stamp else '?'
            print(f'{name:40} {len(lines):4} lines  {when}  ({path.parts[-3]})')
        sys.exit(0 if dumps else 'No dumps saved yet: /eas dump <Frame>, then /reload.')
    if args.name not in dumps:
        sys.exit(f'No dump named {args.name}; saved: {", ".join(sorted(dumps)) or "none"}')
    lines = dumps[args.name][1]
    text = fixture(args.name, lines) if args.spec else '\n'.join(lines) + '\n'
    print(text, end='')
    if args.out:
        Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        Path(args.out).write_text(text)


if __name__ == '__main__':
    main()
