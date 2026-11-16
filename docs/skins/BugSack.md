# BugSack

`Skins/BugSack.lua` · tests: `bugsack_spec`

## Scope

BugSack's window gets the shell (76px footer, no accent bar), square portrait, flat tabs along the bottom, and flat Previous/Next/Send/Wipe buttons with BugSack's own labels and click actions.

Audited against the installed BugSack source; the final look still needs an in-game check.

## Frame map

| Part | Frames and hooks |
| --- | --- |
| Window | `BugSackFrame` (root) |
| Tabs | `BugSackTabAll`, `BugSackTabSession`, `BugSackTabLast`, `BugSackTabOptions`; selection followed through `PanelTemplates_SelectTab` / `DeselectTab` |
| Buttons | `BugSackPrevButton`, `BugSackNextButton`, `BugSackSendButton`, `BugSackWipeButton` |
| Opening | `BugSack.OpenSack`, `OpenConfig` repaint at once (`C.RefreshNow`); `CreateOptionsTab` queues |

## Decisions

- `immediateShow`: the sack repaints in the same frame it opens, so it never flashes unskinned.

## Performance

Six hook sites. The `PanelTemplates_*` hooks are global but return at once for tabs that are not BugSack's. Tab and footer-button geometry is applied once per control; selection refreshes update state without reanchoring or resizing.

## Fixes

- **Refresh layout:** scoped refreshes used to repeat unchanged `ClearAllPoints`, `SetPoint` and `SetSize` calls. Per-control one-time guards retain late-created controls while keeping navigation geometry stable.

## Known limits

- Runs on `Scoped.lua`/`Menus.lua` and the shared helpers.
- Mock specs check the behaviour listed in the spec header; the look itself needs an in-game check.

## History

- 2.0.0: added.
