# Testing

Skins are tested without the game: each spec builds fake WoW frames, installs the skin, and
asserts what it styled. Everything runs in Lua 5.1 (WoW's Lua) through `lupa`.

## Running

```sh
pip install lupa                  # once
python tests/run.py               # everything: lint, Lua 5.1 compile, specs, tool tests
python tests/run.py --lua 5.4     # the same on Lua 5.4 (catches float/integer slips 5.1 lets through)
```

`tests/run.py` runs, in order:

1. **`scripts/lint.py`.** House rules: ASCII, tabs, trailing whitespace, globals missing on WoW
   Forever, `OnUpdate`/tickers, combat handling or `SetScript` in skins, a doc and a spec per
   skin, and `docs/API.md` up to date.
2. **Compile.** Every addon file, as Lua 5.1. This enforces 5.1 syntax (no `goto`, `//`,
   bitwise operators) and its 60-upvalue / 200-local limits.
3. **Specs.** Every `tests/*_spec.lua`, each in its own fresh Lua state.
4. **Tool tests.** Every `tests/test_*.py`: the Python scripts, and the docs' Lua examples.

**Reading the output:**

- **Pass:** each spec prints one `PASS: ...` line naming what it covers, and the run ends with
  `All N specs passed on Lua 5.1 (M addon files compiled)`.
- **Spec failure:** `FAIL <spec>: <file>:<line>: <message>`. The line is the failing `assert`;
  its message says what broke.
- **Compile failure:** `FAIL compile (Lua 5.1): ...`.
- **Lint problem:** `<file>:<line>: [<rule>] <message>`.

Run a single spec while working on it:

```sh
python -c "import lupa.lua51 as l; r = l.LuaRuntime(); r.execute(\"table.unpack = table.unpack or unpack; table.pack = table.pack or function(...) return {n = select('#', ...), ...} end\"); r.execute(open('tests/myaddon_spec.lua').read())"
```

## Test files

| File | Kind | Covers |
| --- | --- | --- |
| `tests/support.lua` | Shared fakes | WoW API, frames, the recording EUI facade, load/install helpers |
| `tests/<addon>_spec.lua` | Skin spec | One skin's behaviour on a mirror of the target's frames |
| `tests/skin_spec.lua` | Framework | `ns.Skin`: roots and modes, passes, combat, visibility, events, gates, `ace` |
| `tests/helpers_spec.lua` | Helpers | Every `Helpers.lua` building block |
| `tests/widgets_spec.lua` | Scanner | `H.Scan` scroll scoping, discovery, exclusions, fades |
| `tests/button_text_spec.lua` | Shared buttons | Single-line fitting, readable minimum, icons, dynamic labels and dimensions, intentional multiline labels and idempotence |
| `tests/core_spec.lua` | Core | TOC order, lazy activation, EUI toggles for enabled targets, GUID enable state, no old-addon guard or import, combat-end pass only after a deferral, `/eas` and `/easnf` only (no legacy commands, one handler each), Debug Mode help |
| `tests/loader_spec.lua` | Loader | Factories per enabled, loaded target; combat; EUI toggle; failure isolation |
| `tests/menus_spec.lua` | Menus | Bound popup and dropdown menus, no top accent allocation, restoration, combat |
| `tests/naowh_spec.lua` | Naowh Forever | Load order, factory wrapping, saved settings honoured, guard, both options pages, copy/manual border, EllesmereUI borders, `/easnf` (status, `edge 2`), bulk actions scoped to Naowh, player-only GCD event |
| `tests/options_spec.lua` | Options | The EUI plugin page: master, Debug Mode (off by default, no reload) and per-skin toggles, rows locked while their addon is off, reload prompt on every change, `/eas options` |
| `tests/dev_spec.lua` | Dev tools | Debug Mode gate (off: no work), `/eas dump`, `probe` (secret-safe) and `perf` |
| `tests/limits_spec.lua` | Headroom | Every skin handler at or under 50 upvalues |
| `tests/auctionator_*_spec.lua` | Skin specs | Auctionator; they keep their own fakes |
| `tests/<addon>_spec.lua` (Altoholic, Attune, BugSack, ForeverDungeonJournal, GearQuestForever, HuntersFieldGuide, WhatsTraining, OneForAll x2) | Skin specs | One per skin; OneForAll has two (source-shaped and Forever API) |
| `tests/test_*.py` | Tool tests | `read_dump.py` round trip; the docs' Lua examples; scripts compile and `new_skin.py` output passes the suite |

## `tests/support.lua`

Load it first. It installs the fake WoW API as globals and returns `T`:

| Call / field | What it does |
| --- | --- |
| `T.Load(...)` | Load the TOC's shared files (everything except `Skins/`), then the given skin files; returns `ns`. |
| `T.Install(id)` | Mark the skin's target loaded, fire its `ADDON_LOADED` and hand EUI's facade over as at login: the factory runs and the module installs if `available()` is true. Returns the module. A spec's own test skin (not in the catalog) gets an entry targeting a folder of its id. |
| `T.Entry(id)` | The skin's catalog entry (created for a test skin). |
| `T.Refresh(id)` | Queue a pass for that skin and run it. |
| `T.Flush()` | Run every queued pass (`C_Timer.After(0)` work); fails on a refresh loop. |
| `T.Fire(event, ...)` | Deliver an event to every frame registered for it (`ADDON_LOADED`, `PLAYER_REGEN_ENABLED`, ...). |
| `T.Frame(kind, parent, name)` | A frame: `"Frame"`, `"Button"`, `"EditBox"`, `"CheckButton"`, `"Slider"`, ... A name makes it a global. |
| `T.Texture(parent, layer, kind)` / `T.FontString(parent, text)` | Regions on a frame. |
| `T.S` | The recording facade (below). `T.accent` is the accent colour it returns. |
| `T.combat = true` | `InCombatLockdown()` returns true. |
| `T.loaded.Addon = true` | `C_AddOns.IsAddOnLoaded("Addon")` returns true (e.g. `T.loaded.OtherSkins = true`). `T.enabled.Addon = true`: enabled but not loaded. |
| `T.chat` | Chat lines the addon printed. `T.looks`: functions registered with `OnLooksChanged` (call them to simulate a theme change). |
| `T.Module(id)` / `T.ns` | The registered module; the loaded namespace. |

**Frames** are plain tables, so a spec sets their state as fields and builds them the way the
target does:

- **Keys:** `parent.Inset = T.Frame('Frame', parent)`.
- **State fields:** `shown`, `width`, `height`, `protected`, `forbidden`, `disabled`, `checked`, `id`.
- **Layout fields:** `left` / `right` / `top` / `bottom` (what `GetLeft()` and friends return;
  nil until set, like a frame that hasn't been laid out).
- **Labels and textures:** `label` (a button's text, as `GetFontString()`), `normal`
  (`GetNormalTexture()`).
- **Recorded by the frame:** `points` (written by `SetPoint`), `scripts` (hooked and set
  scripts; `f:Show()` / `f:Hide()` run `OnShow` / `OnHide`), `alpha`.
- **Methods to hook:** add them as fields; `H.Hook` wraps them like `hooksecurefunc`.

**Regions** record what the skin wrote on them:

- **Textures:** `alpha`, `color` (`SetColorTexture`), `vertex`, `atlas`, `path`, `crop`, `masks`,
  `layer`, `points`, `desaturated`.
- **FontStrings:** `text`, `font` (`'native'` until EUI's font is applied, then `'eui'`),
  `fontWrites`, `textColor`.

**The recording facade:** every EUI primitive records itself on the object it styled, as
`f.skin.<Name> = options` (or `true` when called without options). Examples:
`window.skin.Shell.noTopBar`, `button.skin.Button`, `input.skin.EditBox.padInput`,
`bar.skin.ScrollBar`, `icon.skin.SquareIcon == ownerFrame`. `S.SetTabSelection` sets
`f.selected`, and `S.Font` sets the font to `'eui'`.

## Writing a skin spec

`python scripts/new_skin.py <Addon>` creates a spec that already passes. Then grow it:

1. **Mirror the real frames.** With Debug Mode on, `/eas dump <Frame>` in game, `/reload`, then
   `python scripts/read_dump.py <Frame> --spec` prints a fixture that rebuilds the real tree. Paste
   it in, or keep only the parts the skin touches.
2. **Install, then assert one behaviour per line,** with a message naming it.
3. **Cover the standard behaviours** below.
4. **Break each feature once on purpose** (comment the line out) and check that its assert fails.
   Put it back.

```lua
-- Foo: main window shelled, buttons styled, list rows washed on refill, warm passes idempotent.
local T = dofile('tests/support.lua')
local ns = T.Load('Skins/Foo.lua')

Foo = {ToggleMain = function() end}
local window = T.Frame('Frame', nil, 'FooMainFrame')
local go = T.Frame('Button', window); go.label = T.FontString(go, 'Go')
local list = T.Frame('Frame', window)
local rows = {T.Frame('Button', list)}
list.ScrollBox = T.Frame('Frame', list)
list.ScrollBox.ForEachFrame = function(_, fn) for _, row in ipairs(rows) do fn(row) end end
list.ScrollBox.Update = function() end

T.Install('Foo')
assert(window.skin.Shell, 'main window not shelled')
assert(go.skin.Button, 'button not styled')

-- Pooled rows: a row added later is styled when the box refills.
rows[2] = T.Frame('Button', list)
list.ScrollBox:Update()
assert(rows[2].styled, 'refilled row not styled')

-- Warm passes create nothing and rewrite nothing.
local regions, writes = #window.regions, go.label.fontWrites
T.Refresh('Foo'); T.Refresh('Foo')
assert(#window.regions == regions and go.label.fontWrites == writes, 'warm pass not idempotent')
print('PASS: Foo window, buttons, pooled rows, warm passes')
```

## Behaviours every skin spec should cover

| Behaviour | How |
| --- | --- |
| Waits for its target | Install with the target global nil: `module.attempted` stays false; set it, `T.Fire('ADDON_LOADED')`, `T.Flush()`. |
| Styles what it should | Assert `f.skin.<Primitive>` and the region fields the skin writes (`alpha == 0`, `color`, `points`). |
| Leaves alone what it shouldn't | Protected frames, non-target buttons, values: assert the field is still nil or unchanged. |
| Late frames | Create after install, then fire the hook or `f:Show()`; assert styled. |
| Pooled rows/icons | Refill (call `Update`, `SetTexture`), assert restyled. |
| Hidden windows | `f.shown = false`: not walked again on a refresh; styled after `f:Show()`. |
| Combat | `T.combat = true` → refresh does nothing; `T.combat = false`, `T.Fire('PLAYER_REGEN_ENABLED')` → applied. |
| Measured layout | Set `left`/`right`/`top`/`bottom`, refresh, assert `points` or sizes; then refresh again and assert they didn't move twice. |
| Warm idempotence | Count regions, children, `fontWrites` before and after a few refreshes: equal. |
| Off / guarded | `EUIAdditionalSkinningDB.skins = {Foo = false}`; the master switch via `/eas off`. |

## Rules for test code

- Specs run on Lua 5.1 too: use `table.unpack`/`table.pack` (shimmed) and `io.open(...):read('*a')`;
  no `goto` or `//`.
- One fresh state per spec: no cleanup between specs is needed, and globals don't leak.
- Asserts carry a message saying what broke.
- Plain-text matches use `text:find(fragment, 1, true)`. Lua patterns treat `-`, `(`, `.` and `%`
  as special.
- First line: one comment naming every behaviour the spec covers (lint checks specs exist; this
  line is how a reader finds the right one).

## Other tests

- **Tool tests (`tests/test_*.py`):** a Python script that exits non-zero on failure. `run.py`
  picks it up.
- **Benchmarks:**
  - `benchmarks/<name>.lua` builds a synthetic workload and prints one `MEASURE` line.
  - `python scripts/benchmark.py <name> --before <older copy>` compares medians.
  - Use it for any change to per-pass code.
  - In game: Debug Mode on, then `/eas perf`.
- **CI:** `.github/workflows/checks.yml` runs the same `tests/run.py` on Lua 5.1 and 5.4, then
  packages.
