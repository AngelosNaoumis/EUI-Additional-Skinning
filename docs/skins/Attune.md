# Attune

`Skins/Attune.lua` · tests: `attune_spec`

## Scope

Attune's main, raid, survey, sync, quest-reward and quest-detail windows get the shell (no footer band); graph nodes a 1px backdrop; the tree a flat selection fill and +/- glyphs. The graph canvas and its lines are never painted.

Installed on Forever (16001-41): check in game.

## Frame map

| Part | Frames and hooks |
| --- | --- |
| Windows | `Attune_MainFrame`, `AttuneBronzeChrome`, `Attune_MainRaidFrame`, `Attune_SurveyMenuFrame`, `Attune_SyncProgress_Frame`, `AttuneQuestRewardFrame`, `AttuneQuestDetail` |
| Redraws | 13 global `Attune_*` functions post-hooked (`Attune_Frame`, `Attune_UpdateTreeGroup`, ...) |
| Graph | `frame.map` and everything under `Attune_GraphRoot` excluded from the walk |

## Decisions

- The bronze chrome keeps its title's drag handlers.
- Nodes keep their own colours; only the edge becomes 1px.

## Performance

Two hook sites plus the 13 global redraw hooks; every refresh is the coalesced scoped pass.

## Fixes

- **Bronze chrome** (`AttuneBronzeChrome`): Attune lays this see-through `PortraitFrameTemplate`
  one level above its AceGUI window (`Attune_MainFrame`) for the title, portrait, close button and
  border. Shelling both laid the chrome's background, which covered the window's own level-100
  content (the Survey view read as dimmed) and the window got two borders. The chrome is now
  styled as controls only (art faded, title, close button and portrait kept); the window's shell
  is the one background.
- **Dark overlay (root cause, `/eas probe mouse`: `painted=Attune backdrop`, 1217x737, level
  517):** our own **Border EllesmereUI windows** host on the shelled window sits above the
  window's content, and a textured border style draws on a backdrop frame inside it. The scoped
  shape's backdrop-panel rule painted that frame with an inset `WSkin.Panel`, darkening every
  HIGH-strata Attune frame; only the DIALOG-strata Survey and guild buttons stayed bright.
  `H.Allowed` now refuses this addon's own border frames (`ns.OwnFrames`), so no skin walks into
  them. (The chrome's `NineSlice` is also never painted as a panel: border art.)
- **Portrait:** 16px, anchored 12px left of Attune's list/grid view toggle (`widget.attuneViewToggle`,
  the gap Attune leaves for its portrait under the title strip); in the title strip it hung below
  it or looked cramped.
- **Footer band:** none (`bottomBar` drew a dark strip along the bottom).
- **Status line:** the AceGUI status box's backdrop is faded to transparent; it was painted as a
  dark inset panel along the bottom.
- **Zoom slider:** the shared `H.LegacySlider` keeps a compact 8x14 handle on horizontal sliders
  (it turned the native 32x32 thumb into a solid block over the value labels).

## Known limits

- Runs on `Scoped.lua`/`Menus.lua` and the shared helpers.
- Mock specs check the behaviour listed in the spec header; the look itself needs an in-game check.

## History

- 2.0.0: added.
