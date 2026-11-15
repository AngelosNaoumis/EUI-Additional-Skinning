# EUI Additional Skinning: project guide

EllesmereUI skins for Altoholic, Attune, Auctionator, BugSack, Forever Dungeon Journal, OneForAll,
What's Training? and Naowh Forever, in one addon (WoW Forever, interface 16001). Cosmetic only, so
**runtime cost is the first priority**.

**Layout:** the repository's `EUIAdditionalSkinning/` folder is the addon, exactly what WoW loads
(the TOC, its Lua files and `LICENSE`, a copy of the root one; `scripts/package.py` refuses anything
else). Lua paths in the docs (`Core.lua`, `Skins/<Addon>.lua`) are relative to it. Docs, `tests/`,
`benchmarks/` and `scripts/` stay outside it; run every command from the repository root. Locally,
`Interface/AddOns/EUIAdditionalSkinning` is a junction to that folder.

## Read this, not that

| Task | Read | Skip |
| --- | --- | --- |
| How it fits together | `ARCHITECTURE.md` | Every Lua file |
| Write a new skin | `SKIN-DEVELOPMENT.md`, `docs/API.md`, a frame dump | Other skins' Lua, `Widgets.lua` internals |
| Change an existing skin | `docs/skins/<Addon>.md`, then the section of `Skins/<Addon>.lua` it names | The rest |
| Naowh Forever styling | `ARCHITECTURE.md` "Naowh Forever", then `Integrations/NaowhForever/Runtime.lua` by section | Frame-skin docs |
| Look up a helper | `docs/API.md` (signature, purpose, file:line) | Whole files |
| Write or fix a test | `TESTING.md` | Other specs' fakes |
| A target's frames and hooks | Debug Mode on (Skins page), `/eas dump <Frame>`, `/reload`, `python scripts/read_dump.py <Frame>` | Guessing keys, the target's source |
| What draws over a window | Debug Mode on, `/eas probe <Frame|mouse>` | Inferring from screenshots |
| Real cost in game | Debug Mode on, `/eas perf` | Mock timings alone |

## Commands

```sh
python tests/run.py                                    # lint, Lua 5.1 compile, specs, tool tests: after every change
python tests/run.py --lua 5.4                          # same on 5.4
python scripts/new_skin.py <AddonFolder> --label "X"   # skin + spec + doc + catalog + TOC
python scripts/api_index.py                            # after changing any ns.* / H.* function or its comment
python scripts/benchmark.py <auctionator|menus|scan> --before <copy>   # after per-pass or hook changes
python scripts/package.py                              # before a release
```

Tests need `lupa` (`pip install lupa`; on a Python without wheels: `LUPA_NO_LUAJIT=true`).

## Rules and what enforces them

| Rule | Enforced by |
| --- | --- |
| Lua 5.1 only: no `goto`, `//`, bitwise operators; at most 60 upvalues per function, 200 locals in scope. | `tests/run.py` compiles every file with 5.1 |
| Each `ns.Skin` handler captures at most 50 upvalues. | `tests/limits_spec.lua` |
| ASCII, 4-space indent, no tabs or trailing whitespace, final newline. | `lint.py` [format] |
| No globals WoW Forever lacks (`GetItemInfo`, ...): use the `C_` form. | `lint.py` [forever-global] |
| No `OnUpdate` scripts or repeating timers in skins; hooks and events only. | `lint.py` [polling] |
| Skins don't handle combat themselves (`ns.Skin`/`Scoped` defer passes). | `lint.py` [combat] |
| Visual only: post-hooks (`H.Hook`, `H.Script`), never `SetScript` on a target's frames, never replace a target's callbacks, fade art with alpha. **One documented exception:** the Naowh integration wraps Naowh Forever's shared factories because they must return values (ARCHITECTURE.md). | `lint.py` [setscript]; review |
| Never touch protected or forbidden frames (`H.Allowed` first). | `H.Scan` skips them; review |
| Every skin is a catalog entry plus `ns.RegisterSkinDefinition`; never add option rows by hand. | `tests/options_spec.lua` |
| Every skin has `docs/skins/<Addon>.md` and a spec that loads it; `docs/API.md` matches the code. | `lint.py` [docs] |
| Every behaviour has a spec assert, and breaking it once on purpose makes one fail. | Review |
| No secret-value comparisons or arithmetic (12.x combat data). | Judgment |
| Auctionator's repository asks AI tools not to use it as a reference: work from its frames. | Judgment |

Exceptions: a tag on the line or the line above, naming who and why; an optional date expires it.
Keys: `format`, `forever-global`, `polling`, `combat`, `setscript`, `docs`.

```lua
local t = C_Timer.NewTicker(1, Poll) -- lint-allow: polling until 2026-12-31 by Angelos: Foo has no event for this yet
```

## Initialization rules (easy to break)

- `Catalog.lua` loads first; a skin's code runs only from its factory, never at file load.
- The folder name must sort before `NaowhForever`, and the TOC must never list `NaowhForever`, a
  Naowh module or any addon that depends on them in `Dependencies` or `OptionalDeps`: the Naowh
  factories are wrapped at NaowhForever's `ADDON_LOADED`, before its modules build frames.
- `EllesmereUI` is the only hard dependency. Don't add target addons to `OptionalDeps`.
- Keep every new entry point behind `ns.IsEnabled` (Naowh: `NS.Live()`). The replaced addons
  are not detected; they must be disabled.
- Settings live in `EUIAdditionalSkinningDB` and apply after `/reload`; options pages say so.

## Common pitfalls

- `x and false or nil` is always `nil` in Lua: write the `if`.
- Enable state is cached per character for the session (it can't change without a reload).
- `GetLeft()` and friends are nil until layout: measure in `after`, mark done only then.
- A global hook (`UIDropDownMenu_AddButton`, `PanelTemplates_*`) runs for the whole UI: return at
  once unless the frame is yours.
- Fake frames in `tests/support.lua` only have the methods listed there: add one when a spec needs it.
- `GetAddOnInfo` knows an installed addon before it loads; mocks must too (`T.enabled`), or the
  per-session enable-state cache records "not enabled".
- A frame that clips its children cuts off a border drawn on its own children: border it from
  beside (Naowh `ClipHost`).
- Size is not a window test for HUD elements; EllesmereUI's window engine key is a better one.
- A frame this addon creates inside a target's window (a border host, hull, backdrop) must go in
  `ns.OwnFrames` (Naowh `ours`): otherwise the window's skin walks into it and styles it (Attune
  painted our border's backdrop frame as a panel over the whole window).
- Code that inspects arbitrary frames (dev tools, `EnumerateFrames`) meets restricted frames whose
  getters return secret values: even `if f:IsVisible()` is an error that taints. Read them only
  through `Dev.lua`'s `Read`/`Value` (pcall plus `issecretvalue` on every result) and treat a
  secret as unknown.

## Compatibility risks (all guarded; check after an EllesmereUI or Naowh Forever update)

- EllesmereUI internals: `_ModuleNS` and the action-bar profile (copied border), `PP.GetBorders`
  and `_bdBorderData` (border frames), the window engine's `WSkin.Shell` and frame data (window
  borders), `BorderPxSliderCfg`/`BorderOffsetRowCfgs` (manual border controls, options addon).
- Naowh Forever internals: the factories `Runtime.lua` wraps (ARCHITECTURE.md "Naowh Forever").
- Attune's bronze chrome (`AttuneBronzeChrome`, `widget.attuneViewToggle`) and Altoholic's
  AddonFactory templates are matched by key; a target update that renames them falls back to the
  generic styling.
- `Dev.lua` (`/eas dump`, `probe`, `perf`) ships in the package; the commands work only with Debug
  Mode on (`ns.DebugMode()`, Skins page) and do no work otherwise.
- Commands: `/eas` and `/easnf` (Naowh Forever) only; one handler each (`core_spec` checks).

## Acceptance for a skin

Zero cost while its addon is absent or it is switched off; hooks and events only, no per-pass
allocations, values compared before writing; no taint; follows EUI's style for a Blizzard host
window; switchable from its options row (reload offered); doc and spec complete; checked in game.

## Keeping docs current

Update the skin's doc with the code, `docs/API.md` with `api_index.py`, and `CHANGELOG.md` per
release. When a mistake is
corrected in review, add the rule here, and a lint check if it can be enforced.
