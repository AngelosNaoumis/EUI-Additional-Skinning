# BugSack

`Skins/BugSack.lua` · tests: `bugsack_spec`

## Scope

BugSack's window gets the shell (76px footer, no accent bar), square portrait, flat tabs along the bottom, and flat Previous/Next/Send/Wipe buttons with BugSack's own labels and click actions.

Not installed on Forever: mock-tested only.

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

Six hook sites. The `PanelTemplates_*` hooks are global but return at once for tabs that are not BugSack's.

## Fixes

None: verbatim.

## Known limits

- Runs on `Scoped.lua`/`Menus.lua` and the shared helpers.
- Mock specs check the behaviour listed in the spec header; the look itself needs an in-game check.

## History

- 2.0.0: added.
