# {{LABEL}}

`Skins/{{ADDON}}.lua` · tests: `{{SPEC}}`

TODO: one paragraph on what this skin covers and the look it aims for.

## Scope

| Window | Look |
| --- | --- |
| TODO main window | TODO |

## Frame map

From `/fstack` in game: globals, keys of special parts, and what creates or redraws them.

| What | Where |
| --- | --- |
| Main window | `{{ADDON}}Frame` |
| Created later | TODO: mixins / `Show...` / pools hooked in `setup` |

## Decisions

TODO: anything the code does that isn't obvious from reading it, and why: the target's quirk, the
host window it must match, what was tried and looked wrong.

## Performance

TODO: per-pass work and how it is kept cheap (pooled rows, measured-once layout, caches).

## Known limits

TODO

## History

TODO: first version, notable changes.
