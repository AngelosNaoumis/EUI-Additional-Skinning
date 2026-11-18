# BattlegroundEnemiesFixed

`Skins/BattlegroundEnemiesFixed.lua` · tests: `battlegroundenemiesfixed_spec`

The local BattlegroundEnemiesFixed 12.1.5.8 repository was used read-only. Its bundled license is
GPL-2.0; no source was copied into this project. The repository's requested adjacent WoW UI source
library was not present locally, so the integration points below were verified against the actual
checked-out BGE implementation and this project's frame/API tests.

The skin uses BGE's enemy-frame lifecycle. Existing buttons come from `BGEEnemies.PlayerList`;
new and recycled buttons are handled by one post-hook on `SetupButtonForNewPlayer`. No global frame
scan or frame-creation hook is used.

## Supported surfaces

- one configured EUI outer border on each secure enemy unit button;
- a horizontal Health/Power divider attached to the `Power` module;
- the shared `SpecClassPriority` class/spec and crowd-control debuff surface;
- DR and combat status surfaces;
- trinket and objective/respawn borders anchored to their actual `Icon` texture.

Role icons, raid-target markers, and every castbar surface remain entirely native. The skin does not
border, resize, reposition, recolour, retexture, or hook BGE castbars.

The source version does not expose general buff/debuff rows. Its live crowd-control debuff shares
`SpecClassPriority` with the class/spec icon, so **Buff/debuff borders** controls that surface.

## Visibility and highlights

Trinket and objective/respawn containers stay allocated while their icon is hidden, alpha-zero, or
has no texture. One cached non-interactive border host is anchored to the icon region and mirrors
container visibility, icon visibility, effective alpha, and texture availability through narrow
Show/Hide/SetShown/SetAlpha/SetTexture hooks. Empty or recycled slots therefore leave no floating
border. Replacing a pooled icon retires its old host before anchoring one host to the replacement.
Cooldown overlays, timer text, tooltips, and the containing frame remain untouched.

BGE's `MyTarget` and `MyFocus` frames still provide the source lifecycle and retain their native
shown state, but their extra square is made transparent once during setup. Show/Hide requests recolour the already-created EUI outer
border using BGE's configured `MyTarget_Color` or `MyFocus_Color`. Target wins over focus; clearing
both restores the configured normal border colour. `SetupButtonForNewPlayer` hides both source
indicators, so recycled rows cannot retain stale colour.

## Configuration and performance

The master switch and these components are on by default:

- **Unit-frame borders**
- **Health/Power dividers**
- **Buff/debuff borders**
- **Additional icon borders**

Every border, divider, host, and lifecycle hook is cached. DR allocation is observed only through
`NewInput` and coalesced to one next-frame creation check. Target/focus work occurs only when BGE
changes those indicators. There is no `OnUpdate`, polling, recurring timer, aura-update hook, or
global enumeration. Existing border visibility and highlight colour update immediately in combat.
New unprotected icon, DR, aura/status, and divider decoration is also created immediately. Only
creation or attachment involving an actually protected frame is recorded in weak per-operation
queues; Core's existing `PLAYER_REGEN_ENABLED` path flushes those exact targets once without a full
row scan. It does not install another event frame or timer.
Configured borders and colour overrides are owned by shared `Borders.lua`, so BGE does not depend on
Naowh Forever being installed, enabled, or initialized.

In-game validation should cover 2v2/3v3 and a large battleground: roster recycling, hidden/shown
power bars, trinket cooldown transitions, objective/respawn changes, CC/DR, simultaneous target and
focus, BGE spacing changes, cast start/stop remaining native, test mode, `/reload`, and combat.

## History

- 2.3.0: added with operation-level combat deferral and immediate combat-safe visual updates.
