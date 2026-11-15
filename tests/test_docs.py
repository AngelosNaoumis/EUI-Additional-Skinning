"""Every ```lua block in the docs compiles as Lua 5.1, so copied examples work. Spec-field
snippets (`setup = function ... end,`) are compiled inside a table constructor."""
import re
import sys
from pathlib import Path

import lupa.lua51 as lupa

root = Path(__file__).resolve().parents[1]
DOCS = ['SKIN-DEVELOPMENT.md', 'TESTING.md', 'CLAUDE.md', 'README.md', 'ARCHITECTURE.md', *sorted(p.relative_to(root).as_posix() for p in (root / 'docs').rglob('*.md'))]
BLOCK = re.compile(r'```lua\n(.*?)```', re.S)
compile_lua = lupa.LuaRuntime().eval('function(s) local f, e = loadstring(s); return e end')

failures, count = [], 0
for doc in DOCS:
    path = root / doc
    if not path.is_file():
        continue
    text = path.read_text()
    for m in BLOCK.finditer(text):
        code = m.group(1)
        line = text[:m.start()].count('\n') + 2
        fragment = re.match(r'\s*[A-Za-z_]\w*\s*=\s*function', code) is not None
        error = compile_lua('local _ = {\n' + code + '\n}' if fragment else code)
        count += 1
        if error:
            failures.append(f'{doc}:{line}: {error}')
for failure in failures:
    print(f'FAIL {failure}')
if failures:
    sys.exit(1)
print(f'PASS: {count} Lua examples in the docs compile on Lua 5.1')
