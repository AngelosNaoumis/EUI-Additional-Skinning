# EUI Additional Skinning

Skins some some EllesmereUI function and additionally skins some skins below.

## Supported addons

| Addon | What changes |
| --- | --- |
| [Auctionator](docs/skins/Auctionator.md) | Modern auction house: Auctionator's tabs join the native tab row; results tables, headers, rows, bag icons and the sell form match EUI's own auction house skin. Follows EUI's auction house window style (stock under the Blizzard or Classic look); the legacy `AuctionFrame` keeps a softer style. |
| [Naowh Forever](docs/skins/NaowhForever.md) | EllesmereUI's palette, accent and font; window shells; the border of your EllesmereUI main action bar on items, HUD elements, trackers, aura and GCD icons, the focus cast bar and the top bar; dark item plates. |
| EllesmereUI windows and bags | The same border on every window EllesmereUI skins (loot roll and loot won popups included), its Friends window and its bags. Works without Naowh Forever. |
| [Altoholic](docs/skins/Altoholic.md) | Shells, tabs, controls, grids, calendar and achievement rows, dropdown menus. |
| [Attune](docs/skins/Attune.md) | Windows, graph nodes, tree rows. |
| [BugSack](docs/skins/BugSack.md) | Window, tabs, buttons. |
| [Forever Dungeon Journal](docs/skins/ForeverDungeonJournal.md) | Journal, settings, loot filter and favourites windows. |
| [OneForAll](docs/skins/OneForAll.md) | Main frame, its sections and secondary windows, rarity borders. |
| [What's Training?](docs/skins/WhatsTraining.md) | Window, spell icons, scroll bar. |

A skin's code runs only when its addon is enabled and loaded; otherwise it costs nothing.

## Requirements

- World of Warcraft Forever (interface 16001; the TOC also lists the 12.x interfaces).
- **EllesmereUI** (required). **EllesmereUI Blizzard Skins+** (`EllesmereUIBlizzardSkin`) for the
  window skins; without it only the Naowh Forever colours, fonts and borders apply.

## Installation

1. Download the repository (Code > Download ZIP) or a release ZIP.
2. Copy its `EUIAdditionalSkinning` folder into `Interface/AddOns`. That folder is the whole addon;
   everything else in the repository is for development.

## Configuration

EUI's options panel has an **Additional Skinning** section (`/eas options`):

- **Skins:** the master switch, **Enable Debug Mode** (off by default; turns on the developer
  commands below, takes effect at once) and one toggle per addon. A row is locked while its addon isn't
  enabled. Each skin also has its own toggle on EUI's Window Skins page (Third-Party Addons,
  "EUI Additional Skinning - ..."); a skin runs only when both are on. The **EllesmereUI** section
  holds **Border EllesmereUI windows** and **Border EllesmereUI bags**. Then the border settings:
  **Borders** (Naowh Forever's custom borders on/off, **Copy Main Action Bar 1 border**, Naowh's
  divider and button-border strength) and **Manual Border**, used while copying is off: Border
  Style, Border Size (step or exact pixels), Border Width/Height Offset and Shift X/Y (textured
  styles), Border Color with opacity, Class Color, Show Behind. While copying is on the manual
  controls are locked and say why; their values are kept either way. The style applies to Naowh
  Forever and the EllesmereUI window and bag borders.
- **Naowh Forever Additional Settings:** Naowh Forever's appearance (font, colours, window shells,
  item plates), which of its elements get borders, and three buttons that touch Naowh's settings
  only: **Enable All** / **Disable All** switch every Naowh feature on or off (the manual border is
  kept); **Reset to Defaults** resets every Naowh setting, the border style and manual border
  included. None of them changes the EllesmereUI border toggles, Debug Mode or the skin switches.

Changes are saved at once; a reload is offered, and switching off needs it.

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
python scripts/package.py     # dist/EUIAdditionalSkinning-<version>.zip
```

## Credits and licence

MIT ([LICENSE](LICENSE)).

- **EllesmereUI** provides the look and the public skinning API; **Naowh Forever** is by Naowh.
