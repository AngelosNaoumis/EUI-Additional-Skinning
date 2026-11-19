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
| `FieldGuideTargetPanel` | Dark EUI panel fill; native parchment/ornate edge suppressed; configured EUIAdditionalSkinning border |
| `FieldGuideToast` | Dark EUI panel fill; native parchment/ornate edge suppressed; configured EUIAdditionalSkinning border |
| `FieldGuideFilterMenu`, icon slots | Fill kept, 1px flat edge |
| Buttons, the search box, checkboxes, scroll bars | EUI controls |
| Beast entries, icon tabs, the portrait home button, page arrows, models, map pins | Unchanged |
| Minimap button, gamepad UI, its Blizzard settings panel | Unchanged |

## Frame map

| What | Where |
| --- | --- |
| Namespace | `_G.HuntersFieldGuide` (`PD`) |
| Main window | `FieldGuideFrame`, built once by `PD:CreateUI` (`SKINS.forever` uses `PortraitFrameTemplate`) |
| Header | `frame.header` (`spellbook-list-backplate`, `spellbook-divider`) |
| Entries | buttons with `backplate` (Forever) or `band` (classic) |
| Tabs | buttons with `frame`/`active`/`glow` art |
| Target panel | `FieldGuideTargetPanel`, built once by `PD:CreateTargetPanel` |
| Notification panel | `FieldGuideToast`, built once by `PD:CreateToast`; `PD:Toast`, `PD:ToastNotice` and the settings placement sample reuse it |
| Redraws hooked | `PD`: `CreateUI`, `ToggleUI`, `RefreshUI`, `OpenBeast`, `OpenAbility`, `OpenJournalSettings`, `ShowModel`, `CreateTargetPanel`, `ShowTargetPanel`, `CreateToast`, `ShowExport`, `UpdateFilterButton` |

## Decisions

- **Text:** the journal styles its text with spellbook ink (`SPELLBOOK_FONT_COLOR`, dark brown)
  and dark green/red for good and bad. `H.Readable` lifts it: near-grey ink to white, coloured
  lines to a light tint of their hue. Gold names and white text are left alone.
- **Entries and tabs** keep their spellbook art: elite, tamed, favourite and selected marks are
  drawn on it, and the generic icon squaring would break the masked icons.
- **The page art** is a region on the window, so the shell fades it like any window art.
- **Portrait:** only `PortraitContainer` is re-anchored to `(8, -8)` inside the Forever window.
  The masked portrait and the home button anchored to it keep their original art, click and tooltip.
- **Movable panels:** both fade BackdropTemplate's parchment `Center` and receive
  `S.Panel(..., {noBorder = true})` for the active dark EUI fill. Both alpha-lock the eight
  native edge textures. One shared configured border is attached directly to each panel, so it
  follows dragging, height changes, strata changes, alpha fading, showing and hiding without hooks
  on those frequent lifecycle operations. Frame Stack's generated `FieldGuideToast.<suffix>` child
  is that border renderer, not a second notification; it is claimed by `ns.OwnFrames` and never
  scanned as Hunter's Field Guide content.

## Performance

Passes run only from hooked methods and the scan's event-driven show/click hooks: no recurring timers or polling.
The portrait anchor is compared before writing. The text check also compares before writing;
backdrops and the header are handled once (`H.Once`). Configured-border ownership and native-edge
fades are idempotent.

## Known limits

- The classic look's already-contained portrait stays at its native position; the Forever
  `PortraitFrameTemplate` container receives the corrective anchor.
- The minimap button keeps the journal's look.

## History

- 2.2.0: added.
