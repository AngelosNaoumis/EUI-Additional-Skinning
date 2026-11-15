"""House rules that tests can't see. Run by tests/run.py; one line per problem, non-zero exit.

Rules (keys in brackets; CLAUDE.md lists them with what each prevents):
- [format] ASCII in code, no tabs in Lua, no trailing whitespace, newline at end of file.
- [forever-global] No globals that WoW Forever lacks; use the C_ form named in the message.
- [polling] No OnUpdate scripts or repeating timers in addon code (hooks and events only).
- [combat] Skins never handle PLAYER_REGEN_*: ns.Skin defers passes through combat.
- [setscript] Skins never SetScript; post-hook with H.Script / H.Hook.
- [docs] Every Skins/<Addon>.lua has docs/skins/<Addon>.md and a spec that loads it.

Exception, on the offending line or the line above, with an approver and a reason:
    -- lint-allow: polling by Angelos: one-shot worker that removes itself
    -- lint-allow: forever-global until 2026-12-31 by Angelos: retail-only path
An exception past its date fails everywhere until it is removed or renewed.
"""
import datetime
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
addon = root / 'EUIAdditionalSkinning'
SKIP = {'.git', 'dist'}
KEYS = {'format', 'forever-global', 'polling', 'combat', 'setscript', 'docs'}
CODE_DIRS_SKIP = {'tests', 'benchmarks', 'scripts'}

# Globals WoW Forever never defines (retail keeps them only as deprecation fallbacks); each maps
# to what to call instead. List from EllesmereUI's guardrails.
MOVED = {
    'C_SpecializationInfo': 'GetSpecialization GetSpecializationInfo GetNumSpecializationsForClassID GetActiveSpecGroup',
    'C_Item': 'ActionBindsItem BindEnchant ConfirmBindOnUse ConfirmNoRefundOnUse ConfirmOnUse DoesItemContainSpec '
              'DropItemOnUnit EndBoundTradeable EndRefund EquipItemByName GetDetailedItemLevelInfo GetItemChildInfo '
              'GetItemClassInfo GetItemCooldown GetItemCount GetItemCreationContext GetItemFamily GetItemGem '
              'GetItemInfo GetItemInfoInstant GetItemInventorySlotInfo GetItemQualityColor GetItemSetInfo '
              'GetItemSpecInfo GetItemSpell GetItemSubClassInfo GetItemUniqueness IsArtifactPowerItem '
              'IsConsumableItem IsCorruptedItem IsCosmeticItem IsCurrentItem IsDressableItem IsEquippableItem '
              'IsEquippedItem IsEquippedItemType IsHarmfulItem IsHelpfulItem IsItemInRange IsUsableItem ItemHasRange '
              'PickupItem ReplaceEnchant ReplaceTradeEnchant ReplaceTradeskillEnchant UseItemByName',
    'C_ItemSocketInfo': 'AcceptSockets ClickSocketButton CloseSocketInfo GetExistingSocketInfo GetExistingSocketLink '
                        'GetNewSocketInfo GetNewSocketLink GetNumSockets GetSocketItemBoundTradeable GetSocketItemInfo '
                        'GetSocketItemRefundable GetSocketTypes HasBoundGemProposed',
    'C_CurrencyInfo': 'GetCoinIcon GetCoinText GetCoinTextureString',
    'C_PvP': 'GetZonePVPInfo IsSubZonePVPPOI SetPVP TogglePVP',
    'C_PetInfo': 'GetPetTalentTree PetAssistMode',
    'C_TradeInfo': 'PickupTradeMoney',
}
FOREVER = {name: f'{ns}.{name}' for ns, names in MOVED.items() for name in names.split()}
FOREVER.update({
    'GetSpecializationMasterySpells': 'C_SpecializationInfo.GetSpecializationMasterySpells (returns a table)',
    'GetTalentInfo': 'C_SpecializationInfo.GetTalentInfo (takes a query table)',
    'GetItemIcon': 'C_Item.GetItemIconByID',
    'PlayVocalErrorSoundID': 'C_Sound.PlayVocalErrorSound',
    'GetSpecializationInfoByID': 'nothing on Forever: nil-guard it and fall through to no spec',
})
FOREVER_RE = re.compile(r'(?<![.:\w])(' + '|'.join(sorted(FOREVER, key=len, reverse=True)) + r')\b')
ALLOW_RE = re.compile(r'lint-allow:\s*([\w-]+)(?:\s+until\s+(\S+))?(?:\s+by\s+([^:]*?))?\s*(?::\s*(.*))?$')
today = datetime.date.today()
problems = []


def code_only(text):
    """The Lua source with comments and string contents blanked, line structure kept."""
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if text.startswith('--', i):
            m = re.match(r'--\[(=*)\[', text[i:])
            end = text.find(']' + m.group(1) + ']', i) + len(m.group(1)) + 2 if m else text.find('\n', i)
            end = n if end < (2 if m else 0) or end == -1 else end
            out.append(re.sub(r'[^\n]', ' ', text[i:end])); i = end
        elif c in '"\'':
            j = i + 1
            while j < n and text[j] != c and text[j] != '\n':
                j += 2 if text[j] == '\\' else 1
            out.append(c + ' ' * (min(j, n) - i - 1) + (c if j < n else '')); i = j + 1
        elif text.startswith('[[', i) or re.match(r'\[=+\[', text[i:]):
            eq = re.match(r'\[(=*)\[', text[i:]).group(1)
            end = text.find(']' + eq + ']', i)
            end = n if end == -1 else end + len(eq) + 2
            out.append(re.sub(r'[^\n]', ' ', text[i:end])); i = end
        else:
            out.append(c); i += 1
    return ''.join(out)


def allowed(lines, number, key, rel):
    """True when the line or the line above carries a valid, unexpired lint-allow for key."""
    for index in (number - 1, number - 2):
        if 0 <= index < len(lines):
            m = ALLOW_RE.search(lines[index])
            if m and m.group(1) == key:
                return True
    return False


def report(rel, number, key, message, lines):
    if not allowed(lines, number, key, rel):
        problems.append(f'{rel}:{number}: [{key}] {message}')


def files(*patterns):
    for pattern in patterns:
        for path in root.rglob(pattern):
            if not SKIP & set(path.relative_to(root).parts):
                yield path


# Exception tags must be well formed and current, wherever they are.
for path in files('*.lua'):
    rel = path.relative_to(root).as_posix()
    for number, line in enumerate(path.read_text(errors='replace').splitlines(), 1):
        if 'lint-allow:' not in line or 'ALLOW_RE' in line:
            continue
        m = ALLOW_RE.search(line)
        if not m or m.group(1) not in KEYS:
            problems.append(f'{rel}:{number}: lint-allow needs a known key: {", ".join(sorted(KEYS))}')
        elif not (m.group(3) and m.group(3).strip() and m.group(4) and m.group(4).strip()):
            problems.append(f'{rel}:{number}: lint-allow needs "by <who>: <why>"')
        elif m.group(2):
            try:
                if datetime.date.fromisoformat(m.group(2)) < today:
                    problems.append(f'{rel}:{number}: lint-allow for {m.group(1)} expired on {m.group(2)}')
            except ValueError:
                problems.append(f'{rel}:{number}: lint-allow date must be YYYY-MM-DD')

for path in files('*.lua', '*.toc', '*.py', '*.md'):
    rel = path.relative_to(root).as_posix()
    data = path.read_bytes()
    text = data.decode('utf-8', errors='replace')
    lines = text.splitlines()
    if path.suffix in ('.lua', '.toc', '.py') and any(b > 127 for b in data):
        problems.append(f'{rel}: [format] non-ASCII character')
    if path.suffix == '.lua' and '\t' in text:
        problems.append(f'{rel}: [format] tab character (indent with 4 spaces)')
    for number, line in enumerate(lines, 1):
        if line != line.rstrip():
            problems.append(f'{rel}:{number}: [format] trailing whitespace')
    if data and not data.endswith(b'\n'):
        problems.append(f'{rel}: [format] no newline at end of file')
    if path.suffix != '.lua' or CODE_DIRS_SKIP & set(path.relative_to(root).parts):
        continue
    skin = rel.startswith('EUIAdditionalSkinning/Skins/')
    for number, line in enumerate(code_only(text).splitlines(), 1):
        for m in FOREVER_RE.finditer(line):
            report(rel, number, 'forever-global', f'{m.group(1)} is missing on WoW Forever; use {FOREVER[m.group(1)]}', lines)
        if re.search(r'["\']OnUpdate|NewTicker\s*\(', lines[number - 1]) and not lines[number - 1].lstrip().startswith('--'):
            report(rel, number, 'polling', 'OnUpdate or a repeating timer; hook or listen to an event instead', lines)
        if skin and 'PLAYER_REGEN_' in lines[number - 1] and not lines[number - 1].lstrip().startswith('--'):
            report(rel, number, 'combat', 'ns.Skin already defers passes through combat; call C.refresh()', lines)
        if skin and re.search(r':SetScript\s*\(', line):
            report(rel, number, 'setscript', 'SetScript on a target frame; use H.Script or H.Hook', lines)

specs = {p: p.read_text() for p in (root / 'tests').glob('*_spec.lua')}
for skin in sorted((addon / 'Skins').glob('*.lua')):
    name = skin.stem
    if not (root / 'docs' / 'skins' / f'{name}.md').is_file():
        problems.append(f'Skins/{skin.name}: [docs] missing docs/skins/{name}.md')
    if not any(f'Skins/{name}.lua' in text for text in specs.values()):
        problems.append(f'Skins/{skin.name}: [docs] no spec loads it')

# [docs] The generated API reference must match the code.
import subprocess  # noqa: E402
api = subprocess.run([sys.executable, str(root / 'scripts' / 'api_index.py'), '--check'], capture_output=True, text=True)
if api.returncode:
    problems.append('docs/API.md: [docs] out of date: run python scripts/api_index.py')

for problem in problems:
    print(problem)
if problems:
    sys.exit(f'lint: {len(problems)} problem(s)')
print('lint: clean')
