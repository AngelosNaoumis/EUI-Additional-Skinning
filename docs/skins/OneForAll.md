# OneForAll

`Skins/OneForAll.lua` · tests: `oneforall_spec`, `oneforall_forever_spec`

## Scope

OneForAll's main frame and its eight lazy sections, profile/confirm/bug-report/discord/craft-list/quest-chain/weight-editor/trainer/talent-code/welcome/what's-new/preview/quest-share windows: shells, rarity borders, flat controls, pooled rows.

Not installed on Forever: mock-tested only (source-shaped specs, Retail and Forever API shapes).

## Frame map

| Part | Frames and hooks |
| --- | --- |
| Namespace | `OneForAll.UI` (its widget constructors are post-hooked) |
| Windows | `OneForAllFrame` and the `OneForAll*` secondary windows, inspected once on construction |

## Decisions

- Constructors are observed once; pooled widgets repaint through their own setters, so warm reopen/selection cycles create nothing and read no hierarchy (mock benchmark in `oneforall_spec`: 0 new objects, 0 discovery reads over 1000 cycles).

## Performance

16 hook sites; work deferred in combat is replayed once after it.

## Fixes

- **Combat-retry frame:** lint exceptions tagged on its own event frame (not a target frame). Code otherwise verbatim.

## Known limits

- Runs on `Scoped.lua`/`Menus.lua` and the shared helpers.
- Mock specs check the behaviour listed in the spec header; the look itself needs an in-game check.

## History

- 2.0.0: added.
