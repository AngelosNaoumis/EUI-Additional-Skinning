# GearQuest Forever

`Skins/GearQuestForever.lua` · tests: `gearquestforever_spec`

GearQuest's quest-log-style window in EllesmereUI's look, the way EllesmereUI treats Blizzard's
quest log: the shell replaces the window art, the parchment goes and the dark "ink" text becomes
light, gold metal edges become thin grey lines, and the controls are EllesmereUI's. Item icons,
rarity colours, comparison numbers and GearQuest's own rows and tabs are left as drawn.

Built from GearQuest Forever 1.2.0's source (installed copy). **Not yet checked in game.**

## Scope

| Window | Look |
| --- | --- |
| `GearQuestLogFrame` (log, settings, simulator, lookup pages) | EUI shell; panels a 1px grey edge; text readable |
| `GearQuestSimulateDialog` | EUI shell (its own backdrop removed each time it opens) |
| `GearQuestLanguageMenu` and the menus inside the window | Fill kept, 1px flat edge |
| Buttons, edit boxes, checkboxes, scroll bars, horizontal sliders | EUI controls |
| Hunt rows (`GearQuestLogRow<n>`), page tabs (`gqFill`) | Unchanged |
| Tracker, toasts, portrait guide, minimap button, slot popup on the character sheet, gamepad UI | Unchanged (HUD and overlays) |

## Frame map

| What | Where |
| --- | --- |
| Namespace | `_G.GearQuest` (`GQ`); the window on `GQ.Log` |
| Main window | `GearQuestLogFrame` (`PortraitFrameTemplate`), built once by `GQ.Log:Init` |
| Panels | `frame.listInset`, `frame.detailBg` (`gqParchment`), settings list/detail, simulator insets: `ApplyMetalEdge` (tooltip border), `ApplyParchmentBackground` |
| Window fallback border | `frame.gqOuterBorder` (only without Blizzard's portrait-frame art) |
| Menus | `GearQuestSourceFilterMenu` and its branches, `GearQuestSpecPicker`, `GearQuestWeaponMenu`, `GearQuestCustomSpecMenu`, `GearQuestLanguageMenu` |
| Dialog | `GearQuestSimulateDialog`, built and re-chromed by `GQ.Preview:EnsureDialog` |
| Redraws hooked | `GQ.Log`: `Init`, `Show`, `Toggle`, `Refresh`, `SetPageTab`, `RefreshSettings`, `RefreshSimulator`, `RefreshLookup`, `ToggleSourceFilterMenu`, `ToggleSpecPicker`, `TogglePlayStylePanel`, `ShowWeaponMenu`, `ShowRangedMenu`; `GQ.Preview:EnsureDialog` |

## Decisions

- **No fills added.** Panels only lose the parchment and get a thin edge; the shell's dark fill
  shows through. A painted panel on a frame that sits over content was the Attune overlay bug.
- **Text:** GearQuest draws its detail and lore text black for the parchment. `H.Readable` lifts
  dark text (luminance under 0.3): near-grey to white, coloured to a light tint of its hue.
  Rarity, class and gold text is bright and never touched.
- **Rows and tabs** carry selection, quality and state in their own fills; the generic button
  style would box them and hide that, so the skin leaves them.
- **The X** is styled as a close button before the generic pass (the Altoholic lesson).

## Performance

Passes run only from the hooked methods and the scan's show/click hooks: no timers, no polling.
Per frame: the text check compares before writing; panels and menus are handled once (`H.Once`).

## Known limits

- GearQuest's own portrait and window title stay as GearQuest places them.
- The tracker, toasts, portrait guide and character-sheet popup are HUD or overlay pieces and keep
  GearQuest's look.
- Dropdowns built from `UIDropDownMenuTemplate` in the simulate dialog keep Blizzard's art.

## History

- 2.1.0+: added (unreleased).
