# EUI Additional Skinning

Skins some EllesmereUI functions and additionally skins the addons below.

## Supported addons

| Addon | What changes |
| --- | --- |
| [Auctionator](docs/skins/Auctionator.md) | Modern auction house: Auctionator's tabs join the native tab row; results tables, headers, rows, bag icons and the sell form match EUI's own auction house skin. Follows EUI's auction house window style (stock under the Blizzard or Classic look); the legacy `AuctionFrame` keeps a softer style. |
| [Naowh Forever](docs/skins/NaowhForever.md) | EllesmereUI's palette, accent and font; window shells; the border of your EllesmereUI main action bar on items, HUD elements, trackers, aura and GCD icons, the focus cast bar and the top bar; dark item plates. |
| EllesmereUI windows and bags | The same border on every window EllesmereUI skins (loot roll and loot won popups included), its Friends window and its bags. Works without Naowh Forever. |
| [Altoholic](docs/skins/Altoholic.md) | Shells, tabs, controls, grids, calendar and achievement rows, dropdown menus. |
| [Attune](docs/skins/Attune.md) | Windows, graph nodes, tree rows. |
| [BugSack](docs/skins/BugSack.md) | Window, tabs, buttons. |
| [GearQuest Forever](docs/skins/GearQuestForever.md) | Log window and simulate dialog: EllesmereUI shell, readable text, thin panel edges, menus and controls; hunt rows, tabs, icons and rarity colours kept. |
| [Hunter's Field Guide](docs/skins/HuntersFieldGuide.md) | Journal and export window: EllesmereUI shell, readable text, panels and controls; beast entries, tabs and icons kept. |
| [BattlegroundEnemiesFixed](docs/skins/BattlegroundEnemiesFixed.md) | Enemy unit-frame borders, Health/Power dividers, visible trinket/objective/respawn and CC/DR icon borders; target/focus recolour the existing outer border. Role, raid-target and castbar visuals remain native. |
| [Deadly Boss Mods](docs/skins/DeadlyBossMods.md) | Timer bars only: one configured border around each pooled bar and its visible icons, with optional matching dividers; warnings and DBM options are untouched. |
| [LagBuddy](docs/skins/LagBuddy.md) | Main analyzer with its Addons/Graphics views and the results dialog; panels, tabs, buttons and scroll controls without touching metric collection. |
| [Forever Dungeon Journal](docs/skins/ForeverDungeonJournal.md) | Journal, settings, loot filter and favourites windows. |
| [OneForAll](docs/skins/OneForAll.md) | Main frame, its sections and secondary windows, rarity borders. |
| [What's Training?](docs/skins/WhatsTraining.md) | Window, spell icons, scroll bar. |

A skin's code runs only when its addon is enabled and loaded; otherwise it costs nothing.

## Requirements

- World of Warcraft Forever (interface 16001).
- **EllesmereUI** (required). **EllesmereUI Blizzard Skins+** (`EllesmereUIBlizzardSkin`) for the
  window skins; without it only the Naowh Forever colours, fonts and borders apply.

## Installation

1. Download the repository (Code > Download ZIP) or a release ZIP.
2. Copy its `EUIAdditionalSkinning` folder into `Interface/AddOns`. That folder is the whole addon;
   everything else in the repository is for development.

### Optional: chat bubble style (`Tooltips.zip`)

`Tooltips.zip` holds three chat bubble styles. Pick the one you prefer:

| Folder in the zip | Style |
| --- | --- |
| `Tooltips-Gray+Dark - Recomended` | Gray border, dark background (recommended) |
| `Tooltips-Brown+Dark` | Brown border, dark background |
| `Tooltips-Brown` | Brown |

1. Extract `Tooltips.zip` and open the style folder you chose.
2. Copy the `Tooltips` folder inside it into `Interface` (next to `AddOns`, not inside it), so you
   end up with `Interface/Tooltips/ChatBubble.tga` and `Interface/Tooltips/ChatBubbleVertical.tga`.
3. Restart the game (a `/reload` does not pick up new texture files).

To switch styles, replace the `Interface/Tooltips` folder with another style's. To go back to the
default look, delete `Interface/Tooltips`.

## Configuration

EUI's options panel has an **Additional Skinning** section (`/eas options`):

- **Skins:** the master switch, **Enable Debug Mode** (off by default), **Default button style**,
  **Default Button Font Size** (8; range 4-32), **Disable Button Text Wrapping** (off by default),
  and one compact row per addon: its enable toggle and an EllesmereUI three-dot settings button.
  The three-dot button stays available when the skin or target addon is disabled, so preferences
  can be prepared before enabling it. Each skin also has its own toggle on EUI's Window Skins page
  (Third-Party Addons, "EUI Additional Skinning - ..."); a skin runs only when both are on.
- **Per-skin three-dot settings:** only applicable controls are shown. Eligible button skins expose
  **Button Style**, **Button Font Size** (**Default**, **Addon's Font Size**, or 4-32), **Auto Resize
  Button Text** (default Off), **Button Text Wrapping** (**Default**, **Enabled**, or **Disabled**),
  and **Minimum Auto Font Size** (default 8). BattlegroundEnemiesFixed and DBM component switches live
  here instead of expanding the main page. Every configurable popup has a confirmed
  **Reset to Defaults** action.
- **Naowh Forever:** its appearance, components, borders, manual border controls and bulk actions
  are consolidated into the Naowh three-dot popup; the old separate settings page was removed.
  Its button typography remains entirely native and it exposes no shared font controls.
  **Enable All** / **Disable All** keep the manual border, while **Reset to Defaults** clears it.
  The manual border style is still shared by Naowh and the EllesmereUI window/bag borders.
- **EllesmereUI:** the main page retains only the independent **Border EllesmereUI windows** and
  **Border EllesmereUI bags** switches.

**Button style** (takes effect at once): **EllesmereUI windows** (default) keeps the window skins'
dark grey button; **Game Menu** draws the buttons like EllesmereUI's Game Menu buttons, in your
EllesmereUI **Popup Menu** button colour and border settings. **Default button style** (under
General) sets it for every addon; each applicable skin's three-dot popup can choose **Default**,
**EllesmereUI windows** or **Game Menu**.

With automatic resizing off, **Default** inherits the global size, a number is a per-skin override,
and **Addon's Font Size** restores and then leaves native font sizing alone. Automatic resizing
ignores the fixed selection, starts at the original addon size, never enlarges it, and shrinks only
as needed toward the configured minimum. Changing automatic resizing is saved immediately but
requires confirmation before reloading; choosing **Later** leaves the current session's mode intact.
Its font-size dropdown is disabled while automatic mode is configured or still active pending a
reload. Only active automatic mode installs targeted text/dimension hooks; while it is off there are
no fit measurements, fit writes, or fit-state allocations. There is no polling. Fixed sizes, the
global default, wrapping and button styles apply live. Wrapping **Default** inherits the global
toggle, **Enabled** preserves the addon's captured layout, and **Disabled** keeps eligible
single-line labels from wrapping; intentional multiline controls remain unchanged.

## Commands

| Command | Does |
| --- | --- |
| `/eas` | Each integration's state |
| `/eas options` | Open the options section |
| `/eas on` / `off` | Master switch (reload for a clean result) |
| `/eas refresh` | Re-apply the active skins |
| `/eas euiwindows`, `/eas euibags` | Toggle the EllesmereUI window or bag borders (reload to apply) |
| `/easnf <command>` | Naowh Forever: `font`, `colors`, `shell`, `slots`, `borders`, `edge bars|<0-4>` (a number sets a solid manual border of that size), `border <0-100>`, `button <0-100>`, `reset`, `debug [all]` |
| `/eas dump <frame|mouse|clear>`, `/eas perf [off|reset]` | Debug Mode only. For writing skins: frame maps, in-game pass timings |
| `/eas probe <frame|mouse>` | Debug Mode only. Diagnostic: the textures drawn over a window (or under the cursor), top first, with strata, level, layer, alpha, colour and owner; saved for `read_dump.py "probe <frame>"` |

With Debug Mode off the developer commands only say how to turn it on, and `/eas` help leaves them
out.

## Compatibility

- Visual only: post-hooks and alpha fades; protected and forbidden frames are never touched; work
  is deferred through combat. No `OnUpdate` scripts or repeating timers.
- The Naowh Forever integration wraps Naowh Forever's shared drawing functions in place before its
  modules load (its folder name sorts before `NaowhForever`); Naowh's own files are never changed.
  Only Naowh's flat "Naowh" look is styled; its metal "Forever" look is left alone.
- Copying the Main Action Bar 1 border, and finding the windows and bags EllesmereUI skins, use
  EllesmereUI internals (guarded); if a future EllesmereUI changes them, the copied border falls back
  to a plain edge and the window borders stop, without errors.

## Development

| Path | What |
| --- | --- |
| `EUIAdditionalSkinning/` | The addon: exactly what WoW loads (`scripts/package.py` checks) |
| `docs/`, `*.md` | Documentation |
| `tests/`, `benchmarks/`, `scripts/` | Specs, benchmarks and tools (run from the repository root) |

[CLAUDE.md](CLAUDE.md) (start here), [ARCHITECTURE.md](ARCHITECTURE.md),
[SKIN-DEVELOPMENT.md](SKIN-DEVELOPMENT.md), [TESTING.md](TESTING.md), [docs/API.md](docs/API.md),
[CHANGELOG.md](CHANGELOG.md).

```sh
python tests/run.py           # lint, Lua 5.1 compile, specs, tool tests
python tests/run.py --lua 5.4 # the same checks under Lua 5.4
python scripts/benchmark.py button_text --before <older-addon-copy>
python scripts/package.py     # dist/EUIAdditionalSkinning-<version>.zip
```

## Credits and licence

MIT ([LICENSE](LICENSE)).

- **EllesmereUI** provides the look and the public skinning API; **Naowh Forever** is by Naowh.
