## What changes in game?

<!-- Which addon, which windows, what the player sees. -->

## How was it tested?

<!-- python tests/run.py output; in game: client, EUI styles tried, combat, /reload. -->

## Screenshots

<!-- Before and after for any visual change. Delete if not visual. -->

## Checklist

- [ ] `python tests/run.py` green (lint, Lua 5.1 compile, specs)
- [ ] Each new behaviour has a spec assert, and breaking it makes the spec fail
- [ ] `docs/skins/<Addon>.md` updated (frame map, decisions, limits); `docs/API.md` regenerated if helpers changed
- [ ] Zero cost while the target is absent or the skin is off; no per-pass allocations
- [ ] Visual only: hooks, no `SetScript` on others' frames, no protected frames, combat deferred
- [ ] Checked in game with both EUI window styles and the Classic look
