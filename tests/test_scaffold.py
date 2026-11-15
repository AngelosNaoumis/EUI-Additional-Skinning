"""Every Python script compiles, and scripts/new_skin.py produces a skin, spec, doc and TOC entries
that pass the whole suite in a fresh copy of the addon."""
import os
import py_compile
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
for script in sorted([*(root / 'scripts').glob('*.py'), *(root / 'tests').glob('*.py')]):
    py_compile.compile(str(script), doraise=True)

# The copy runs the whole suite again; this test must not recurse into itself there.
if os.environ.get('EUI_SCAFFOLD_TEST'):
    print('PASS: scripts compile (scaffold run skipped inside the scaffold copy)')
    sys.exit(0)

with tempfile.TemporaryDirectory() as temp:
    copy = Path(temp) / 'EUI-Additional-Skinning'
    shutil.copytree(root, copy, ignore=shutil.ignore_patterns('.git', 'dist', '__pycache__'))
    env = dict(os.environ, EUI_SCAFFOLD_TEST='1')
    result = subprocess.run([sys.executable, 'scripts/new_skin.py', 'ZzScaffoldProbe', '--label', 'Scaffold Probe'],
                            cwd=copy, env=env, capture_output=True, text=True)
    for path in ['EUIAdditionalSkinning/Skins/ZzScaffoldProbe.lua', 'tests/zzscaffoldprobe_spec.lua', 'docs/skins/ZzScaffoldProbe.md']:
        assert (copy / path).is_file(), f'new_skin.py did not create {path}\n{result.stdout}{result.stderr}'
    toc = (copy / 'EUIAdditionalSkinning' / 'EUIAdditionalSkinning.toc').read_text()
    assert 'Skins\\ZzScaffoldProbe.lua' in toc, 'TOC entry'
    assert 'id = "ZzScaffoldProbe"' in (copy / 'EUIAdditionalSkinning' / 'Catalog.lua').read_text(), 'catalog entry'
    assert result.returncode == 0 and 'All ' in result.stdout, f'suite failed after scaffolding\n{result.stdout}{result.stderr}'
print('PASS: scripts compile; new_skin.py scaffolds a skin, spec, doc, catalog and TOC entries that pass the suite')
