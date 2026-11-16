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
| `GearQuestLogFrame` (log, settings, simulator, lookup pages) | EUI shell; portrait kept inside the top-left corner; panels a 1px grey edge; text readable |
| `GearQuestSimulateDialog` | EUI shell (its own backdrop removed each time it opens) |
| `GearQuestLanguageMenu` and the menus inside the window | Fill kept, 1px flat edge |
| Buttons, edit boxes, checkboxes, scroll bars, horizontal sliders | EUI controls; oversized text-button labels shrink conservatively without changing the control |
| Hunt rows (`GearQuestLogRow<n>`), list tabs (`gqFill`) | Unchanged |
| External page tabs (`frame.sideTabRail`) | Original icon/chrome/state art and native GearQuest layout; overlapping eight pixels render behind the main window |
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
| Portrait | `frame.PortraitContainer` (fallback: `gqPortraitHolder`); `GQ.PortraitGuide.hit` is its click/glow target |
| Animated buttons | `frame.playStyleBtn` and `frame.trackBtn`; their native `introWash` textures keep their existing animation |
| Right-side navigation | `frame.sideTabRail`; `tabLog`, `tabLookup`, `tabSimulator`, `tabSettings` are parented outside the window on `UIParent` |
| Redraws hooked | `GQ.Log`: `Init`, `Show`, `Toggle`, `Refresh`, `RefreshSettings`, `RefreshSimulator`, `RefreshLookup`, `ToggleSourceFilterMenu`, `ToggleSpecPicker`, `TogglePlayStylePanel`, `ShowWeaponMenu`, `ShowRangedMenu`; `GQ.Preview:EnsureDialog` |

## Decisions

- **No fills added.** Panels only lose the parchment and get a thin edge; the shell's dark fill
  shows through. A painted panel on a frame that sits over content was the Attune overlay bug.
- **Text:** GearQuest draws its detail and lore text black for the parchment. `H.Readable` lifts
  dark text (luminance under 0.3): near-grey to white, coloured to a light tint of its hue.
  Rarity, class and gold text is bright and never touched.
- **Rows and tabs** carry selection, quality and state in their own fills; the generic button
  style would box them and hide that, so the skin leaves them.
- **The X** is styled as a close button before the generic pass (the Altoholic lesson).
- **Portrait:** the 61px original container and separate guide hit/glow move from `(-6, 7)` to
  `(8, -8)`, entirely inside the shell. The guide bubble receives the same scaled offset when it
  opens and after the window is dragged, so the tail still points to the portrait. No artwork or
  scripts are replaced.
- **Intro animation:** the native Play style and Track `introWash` textures are expanded from their
  5px inset to the EUI button's 2px inner edge. Their existing animation, visibility and dismissal
  code is untouched; no animation or update handler is added.
- **Right-side buttons:** reusing Character Pane internals would couple this skin to protected
  Blizzard/EUI implementation details. Following the safe fallback, GearQuest's original buttons,
  icons, selected/hover art, tooltips, click scripts and layout stay unskinned. GearQuest reapplies
  their anchors, sizes, frame levels and selected-state chrome together on every page change. Its
  `DIALOG` rail and button levels originally put the overlap above the `DIALOG` level-100 window.
  The skin sets each actual tab to the lower `HIGH` strata once when it is discovered. GearQuest
  remains the sole geometry and state owner, while the window covers only the overlapping eight
  pixels and the exposed `UIParent`-parented portion remains clickable. The skin does not hook
  `SetPageTab`; if GearQuest genuinely replaces a tab, the next normal refresh treats that new
  object once.
- **Button labels:** the shared styled-button policy keeps the intended size when it fits and
  progressively shrinks oversized labels, including Play style, to a 9px minimum. It changes no
  button geometry, alignment, colour, outline, click script or intro animation.

## Performance

Passes are one-shot and coalesced from the hooked methods and the scan's show/click hooks: no
polling or recurring timer. Portrait and bubble anchors are compared before writing; each intro
wash is anchored once. The side-tab rail is outside the scanned window; only each tab object's
strata is written once, while GearQuest's repeated native layout passes remain untouched.
Per frame, the text check compares before writing; panels and menus are handled once
(`H.Once`).

## Known limits

- GearQuest's portrait stays original but is re-anchored inside the shell; its title remains native.
- The tracker, toasts, portrait guide and character-sheet popup are HUD or overlay pieces and keep
  GearQuest's look.
- Dropdowns built from `UIDropDownMenuTemplate` in the simulate dialog keep Blizzard's art.
- A label that still cannot fit at the readable 9px minimum is left at 9px and marked
  `euiasTextFitOverflow` for in-game diagnosis; it is not made smaller or given a wider button.

## History

- 2.2.0: added.
