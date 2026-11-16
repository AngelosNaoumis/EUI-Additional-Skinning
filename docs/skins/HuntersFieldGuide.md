# Hunter's Field Guide

`Skins/HuntersFieldGuide.lua` · tests: `huntersfieldguide_spec`

The Field Guide's spellbook-style journal in EllesmereUI's look, the way EllesmereUI treats the
Forever spellbook: the shell replaces the page art, the spellbook "ink" text becomes light (its
hue kept for coloured lines), and the controls are EllesmereUI's. Beast entries, icon tabs, the
portrait and the model views keep the journal's own art, which carries its marks.

Built from Hunter's Field Guide 0.8.7's source (installed copy). **Not yet checked in game.**

## Scope

| Window | Look |
| --- | --- |
| `FieldGuideFrame` (both the "Forever spellbook" and "classic" looks) | EUI shell; portrait kept inside the top-left corner; header backplate faded; text readable |
| `FieldGuideExport` | EUI shell |
| `FieldGuideTargetPanel`, `FieldGuideFilterMenu`, icon slots | Fill kept, 1px flat edge |
| Buttons, the search box, checkboxes, scroll bars | EUI controls |
| Beast entries, icon tabs, the portrait home button, page arrows, models, map pins | Unchanged |
| Toast, minimap button, gamepad UI, its Blizzard settings panel | Unchanged |

## Frame map

| What | Where |
| --- | --- |
| Namespace | `_G.HuntersFieldGuide` (`PD`) |
| Main window | `FieldGuideFrame`, built once by `PD:CreateUI` (`SKINS.forever` uses `PortraitFrameTemplate`) |
| Header | `frame.header` (`spellbook-list-backplate`, `spellbook-divider`) |
| Entries | buttons with `backplate` (Forever) or `band` (classic) |
| Tabs | buttons with `frame`/`active`/`glow` art |
| Redraws hooked | `PD`: `CreateUI`, `ToggleUI`, `RefreshUI`, `OpenBeast`, `OpenAbility`, `OpenJournalSettings`, `ShowModel`, `ShowTargetPanel`, `ShowExport`, `UpdateFilterButton` |

## Decisions

- **Text:** the journal styles its text with spellbook ink (`SPELLBOOK_FONT_COLOR`, dark brown)
  and dark green/red for good and bad. `H.Readable` lifts it: near-grey ink to white, coloured
  lines to a light tint of their hue. Gold names and white text are left alone.
- **Entries and tabs** keep their spellbook art: elite, tamed, favourite and selected marks are
  drawn on it, and the generic icon squaring would break the masked icons.
- **The page art** is a region on the window, so the shell fades it like any window art.
- **Portrait:** only `PortraitContainer` is re-anchored to `(8, -8)` inside the Forever window.
  The masked portrait and the home button anchored to it keep their original art, click and tooltip.

## Performance

Passes run only from hooked methods and the scan's event-driven show/click hooks: no recurring timers or polling.
The portrait anchor is compared before writing. The text check also compares before writing;
backdrops and the header are handled once (`H.Once`).

## Known limits

- The classic look's already-contained portrait stays at its native position; the Forever
  `PortraitFrameTemplate` container receives the corrective anchor.
- The toast and the minimap button keep the journal's look.

## History

- 2.2.0: added.
