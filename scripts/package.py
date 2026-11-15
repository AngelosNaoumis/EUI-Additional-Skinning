"""Validate the TOC and versions, run the tests, then build and verify dist/EUIAdditionalSkinning-<version>.zip:
the EUIAdditionalSkinning folder, which holds exactly what WoW loads (TOC, its files, the licence).

Run from anywhere: python scripts/package.py [--out DIR]
"""
import argparse
import os
import re
import subprocess
import sys
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

NAME = 'EUIAdditionalSkinning'
root = Path(__file__).resolve().parents[1]
addon = root / NAME
parser = argparse.ArgumentParser()
parser.add_argument('--out', default=str(root / 'dist'), help='where to write the zip')
args = parser.parse_args()
toc = (addon / f'{NAME}.toc').read_text()
version = re.search(r'^## Version: (\S+)$', toc, re.M).group(1)
assert f'ns.VERSION = "{version}"' in (addon / 'Core.lua').read_text(), 'TOC and Core versions differ'
assert f'## {version} ' in (root / 'CHANGELOG.md').read_text(), f'CHANGELOG.md has no {version} entry'
loaded = [line.strip().replace('\\', '/') for line in toc.splitlines() if line.strip() and not line.startswith('#')]
for path in loaded:
    assert (addon / path).is_file(), f'Missing TOC file: {path}'
skins = {p.relative_to(addon).as_posix() for p in (addon / 'Skins').glob('*.lua')}
assert skins == {p for p in loaded if p.startswith('Skins/')}, 'Every skin file must be listed in the TOC'
subprocess.run([sys.executable, 'tests/run.py'], cwd=root, check=True)

# The player payload: the TOC, the files it loads, and the licence.
files = [f'{NAME}.toc', *loaded, 'LICENSE']
assert (addon / 'LICENSE').read_bytes() == (root / 'LICENSE').read_bytes(), 'EUIAdditionalSkinning/LICENSE differs from LICENSE'
present = {p.relative_to(addon).as_posix() for p in addon.rglob('*') if p.is_file()}
assert present == set(files), f'The addon folder must hold only what WoW loads; extra: {sorted(present - set(files))}'
dist = Path(args.out)
dist.mkdir(parents=True, exist_ok=True)
archive = dist / f'{NAME}-{version}.zip'
partial = archive.with_suffix('.zip.partial')
with ZipFile(partial, 'w', compression=ZIP_DEFLATED) as z:
    for path in files:
        z.write(addon / path, f'{NAME}/{path}')
with ZipFile(partial) as z:
    assert z.testzip() is None, 'Corrupt ZIP'
    assert sorted(z.namelist()) == sorted(f'{NAME}/{p}' for p in files)
    for path in files:
        assert z.read(f'{NAME}/{path}') == (addon / path).read_bytes(), path
try:
    os.replace(partial, archive)
except PermissionError:
    sys.exit(f'{archive} is open in another program (a zip preview or Explorer); close it and run again. '
             f'The verified build is at {partial}.')
print(f'Verified {archive}: {len(files)} files')
