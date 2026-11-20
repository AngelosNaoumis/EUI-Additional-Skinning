# Angler's Field Guide

`Skins/AnglersFieldGuide.lua` · tests: `anglersfieldguide_spec`

Angler's Field Guide's fishing journal in EllesmereUI's look. Its classic and Forever spellbook
pages become an EUI shell, dark spellbook ink becomes readable, and ordinary controls use EUI's
styles. Catch entries, icon tabs, maps, fishing markers and state-bearing icon art remain native.

Built from Angler's Field Guide 0.2.3's installed source. **Not yet checked in game.**

## Scope

| Window | Look |
| --- | --- |
| `AnglerGuideFrame` (classic and Forever looks) | EUI shell; Forever portrait kept inside the top-left corner; header backplate faded; text readable |
| `AnglerGuideExport` | EUI shell and controls; movement and copy behavior preserved |
| `AnglerGuideToast` | Dark EUI panel fill; native inset parchment/ornate edge suppressed; one configured EUIAdditionalSkinning border |
| `AnglerGuideFilterMenu`, icon slots | Fill kept, 1px flat edge |
| Text buttons, search box, checkboxes and scroll bars | EUI controls |
| Catch entries, icon tabs, portrait home button, favourites, gear/page/map arrows, maps and pins | Unchanged |
| Minimap button, gamepad UI and Blizzard settings panel | Unchanged |

Angler's Field Guide has no Hunter-style target panel; no frame name is invented for one.

## Frame map

| What | Where |
| --- | --- |
| Namespace | `_G.AnglersFieldGuide` (`AG`) |
| Main window | `AnglerGuideFrame`, built once by `AG:CreateUI`; the Forever look uses `PortraitFrameTemplate` |
| Header | `frame.header` with `spellbook-list-backplate` and `spellbook-divider` |
| Entries | buttons with `backplate` (Forever) or `band` (classic) |
| Tabs | Forever buttons with `frame`/`active`/`glow`; classic direct-child check buttons |
| Filter | `AnglerGuideFilterMenu`, built by `AG:CreateFilter` during `CreateUI` |
| Notification | `AnglerGuideToast`, built once by `AG:CreateToast`; every `AG:Toast` call reuses it |
| Export | `AnglerGuideExport`, created lazily by `AG:ShowExport` |
| Redraws hooked | `AG`: `CreateUI`, `ToggleUI`, `RefreshUI`, `OpenCatch`, `OpenZone`, `OpenJournalSettings`, `CreateToast`, `ShowExport`, `UpdateFilterButton` |

## Decisions

- **Text:** `H.Readable` lifts dark ink to white and lightens coloured fishing states while
  preserving their hue. Gold and already-light text remain unchanged.
- **Entries and navigation art:** catch entries, tabs, favourites, the home target, icon choices,
  gear and spellbook arrows keep native state art instead of receiving a competing button box or
  square-icon crop.
- **Page art:** the journal's parchment is a window region and is replaced by the EUI shell.
- **Portrait:** only the Forever `PortraitContainer` moves to `(8, -8)`. Its custom masked fishing
  icon and the home hit target remain attached, preserving clicks and tooltips.
- **Toast:** `S.Panel(..., {noBorder = true})` fills the complete owner, eliminating the native
  backdrop inset. The native `Center` and eight edges are alpha-locked. The configured border is
  owned by the toast, so its native five-second fade, hover pause, click-to-open behavior, strata,
  visibility and reuse need no extra hooks. Its generated border child is claimed by `ns.OwnFrames`.

## Performance

Work runs from source-verified method hooks and the framework's event-driven control hooks. There
is no polling, recurring timer or global frame scan. Portrait placement compares before writing;
backdrops and the header use `H.Once`; the border and native-region suppression are idempotent.

## Known limits

- The classic look's portrait is already contained and therefore remains at its native position.
- Map art, world-map pins, the minimap button and gamepad overlay retain Angler's own styling.

## History

- Unreleased: initial skin.
