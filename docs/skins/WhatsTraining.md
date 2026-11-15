# What's Training?

`Skins/WhatsTraining.lua` · tests: `whatstraining_spec`

## Scope

What's Training?'s window gets the shell without a title strip; spell and UI icons are squared, its grouping popup a panel, its scroll bar EUI's.

Installed on Forever (11.4.7): check in game.

## Frame map

| Part | Frames and hooks |
| --- | --- |
| Window | `WhatsTrainingFrame` (root), `WhatsTrainingSkillsButton` (controls) |
| Redraw | `WhatsTrainingFrame:Refresh` post-hooked |

## Decisions

- Spell and city indicators keep their colours and artwork; only icons are cropped square.

## Performance

One hook site.

## Fixes

- **No window shell:** What's Training? always lives inside the Spellbook (on Forever,
  `WhatsTrainingFrame` sits in `WhatsTrainingOverlay` on `PlayerSpellsFrame` and paints its own
  page). Shelled as a window, it got a second, dark background and a second border
  over the page. It is now styled as controls only.

## Known limits

- Runs on `Scoped.lua`/`Menus.lua` and the shared helpers.
- Mock specs check the behaviour listed in the spec header; the look itself needs an in-game check.

## History

- 2.0.0: added.
