# Altoholic

`Skins/Altoholic.lua` · tests: `altoholic_spec`

## Scope

Altoholic's main window and message box get EUI's window shell (no title strip, no accent bar), with flat tabs, buttons, checkboxes, steppers, dropdowns, grids, the calendar and achievement rows.

Installed on Forever (1.60.005): check in game.

## Frame map

| Part | Frames and hooks |
| --- | --- |
| Main window | `AltoholicFrame` (root); `SwitchToTab`, `SetTabs`, `ToggleUI`, `SetPortraitToUnit` hooked |
| Message box | `AltoMessageBox` (root) |
| Pooled rows | grid, achievement and calendar rows restyle from their own `Update` hooks (`C.RefreshControlsNow` on the row only) |
| Dropdowns | Altoholic's `LibUIDropDownMenu` lists bound through `ns.BindPopupList` (Menus.lua) |

## Decisions

- Pooled rows repaint only their own subtree from their `Update` hook, not a full pass.
- Labels keep Altoholic's class and rarity colours (`SetTextColor` is followed, not overwritten).

## Performance

28 hook sites, all post-hooks on Altoholic's own methods. No timers or polling.

## Fixes

- **Expand/collapse button** (`AltoholicFrame.TabSummary.ToggleView`, AddonFactory's
  `ToggleButtonTemplate`, 16x16): its plus/minus art sits on a NormalTexture keyed `Icon`, so the
  icon-button branch kept it as a cropped red icon inside a button box. The toggle is now matched
  first (`C.ToggleState`: AddonFactory's `isCollapsed`, else the art) and drawn as a flat button
  with a `+`/`-` glyph that follows `SetNormalTexture`; its click and tooltip are untouched.
- **Close button** (`AltoholicFrameCloseButton`, 28x28): its `RedButton-Exit` atlas reads back
  as a file ID, so it matched the toolbar-icon branch and got EllesmereUI's button fill, hover,
  border and an icon border (found with `/eas dump` and `/eas probe mouse`). A parent's
  `CloseButton` is now styled by `S.CloseButton` only: the X and its hover, pushed and disabled
  states stay EllesmereUI's.

## Known limits

- Runs on `Scoped.lua`/`Menus.lua` and the shared helpers.
- Mock specs check the behaviour listed in the spec header; the look itself needs an in-game check.

## History

- 2.0.0: added.
