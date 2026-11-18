# Deadly Boss Mods

## Scope

Only timer bars from `DBM-StatusBarTimers` are changed. DBM configuration, warnings, alerts and
other modules are intentionally untouched.

The installed DBM 12.1.23 source was inspected. Timer objects are created or taken from DBM's own
pool by `DBT:CreateBar`; their named status bar and two optional icons remain attached to that
pooled object while `barPrototype:ApplyStyle` changes size and layout. The skin post-hooks the
creation method and the shared `ApplyStyle` lifecycle once. It does not hook timer-progress updates,
add `OnUpdate`, poll, or continuously scan active bars.

Each pooled timer gets one cached hull using Additional Skinning's configured border style. The
hull spans the status bar and whichever left/right icons are currently visible. One matching
vertical divider is cached for each icon side. Hidden icons hide their divider; left-only,
right-only, both-icon and no-icon layouts update only when `ApplyStyle` changes the participating
objects. DBM's own anchors make the hull follow ordinary width animation without repeated skin
geometry writes.

No independent border is applied to the status bar or either icon. DBM's optional built-in
four-edge bar border is alpha-faded to prevent duplicate thickness. Pool reuse retains the same
hull, border and divider textures. Secret encounter-timeline bars and protected or forbidden
frames are skipped.

## Settings

- `Deadly Boss Mods`: master integration toggle, on by default.
- `Unified timer border`: one outer border around the complete visible timer layout, on by default.
- `Icon/bar dividers`: matching divider at each visible icon/bar boundary, on by default.

The two component settings retain the existing `bars` and `icons` SavedVariable keys for backward
compatibility. Changes request a reload, like the other skin toggles.

## History

- 2.3.0: added timer-bar hulls and optional icon/bar dividers.
