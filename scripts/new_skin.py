"""Scaffold a new skin: EUIAdditionalSkinning/Skins/<Addon>.lua, tests/<addon>_spec.lua, docs/skins/<Addon>.md and the TOC entries.

    python scripts/new_skin.py Bagnon
    python scripts/new_skin.py ElvUI_OptionsUI --label "ElvUI Options" --global ElvUI

<Addon> is the target's folder name (used for the module id, the catalog target and the
example frame name); --global is the global that exists once it has loaded (defaults
to <Addon>). Then follow SKIN-DEVELOPMENT.md and run python tests/run.py.
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
addon_dir = root / 'EUIAdditionalSkinning'
parser = argparse.ArgumentParser()
parser.add_argument('addon')
parser.add_argument('--label')
parser.add_argument('--global', dest='global_name')
args = parser.parse_args()
addon = args.addon
if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', addon):
    sys.exit('Addon name must be a valid Lua identifier (letters, digits, underscores).')
values = {'{{ADDON}}': addon, '{{LABEL}}': args.label or addon, '{{GLOBAL}}': args.global_name or addon,
          '{{SPEC}}': f'{addon.lower()}_spec'}

skin = addon_dir / 'Skins' / f'{addon}.lua'
spec = root / 'tests' / f'{addon.lower()}_spec.lua'
doc = root / 'docs' / 'skins' / f'{addon}.md'
for path in (skin, spec, doc):
    if path.exists():
        sys.exit(f'{path.relative_to(root)} already exists.')


def render(template):
    text = (root / 'scripts' / 'templates' / template).read_text()
    for key, value in values.items():
        text = text.replace(key, value)
    return text


skin.write_text(render('skin.lua'))
spec.write_text(render('spec.lua'))
doc.parent.mkdir(parents=True, exist_ok=True)
doc.write_text(render('doc.md'))

# Catalog: the skin's options row and EUI toggle; its factory runs once the target is loaded.
catalog_path = addon_dir / 'Catalog.lua'
catalog = catalog_path.read_text()
line = f'    {{id = "{addon}", label = "{values["{{LABEL}}"]}", targets = {{"{addon}"}}}},\n'
marker = '}\nns.skinCatalogByID = {}'
assert marker in catalog, 'Catalog.lua layout changed'
catalog_path.write_text(catalog.replace(marker, line + marker, 1), newline='\n')

# TOC: load the skin after the existing ones.
toc_path = addon_dir / 'EUIAdditionalSkinning.toc'
toc = toc_path.read_text()
newline = '\r\n' if '\r\n' in toc else '\n'
lines = toc.splitlines()
last_skin = max(i for i, line in enumerate(lines) if line.startswith('Skins\\'))
lines.insert(last_skin + 1, f'Skins\\{addon}.lua')
toc_path.write_text(newline.join(lines) + newline)

print(f'Created {skin.relative_to(root)}, {spec.relative_to(root)} and {doc.relative_to(root)}; added the catalog and TOC entries.')
print('Next: SKIN-DEVELOPMENT.md (the recipe) and TESTING.md (growing the spec).')
print("Its on/off row on EUI's Additional Skinning options page is automatic; check it in game (SKIN-DEVELOPMENT.md step 7).")
subprocess.run([sys.executable, 'tests/run.py'], cwd=root, check=False)
