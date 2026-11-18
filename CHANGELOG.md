# Changelog

## 2.3.0 - 2026-11-18

- Replaced expanded per-skin controls with one enable toggle and EllesmereUI's native three-dot
  settings popup per catalog entry. Popups are generated from a shared declarative registry and
  remain configurable while their skin or target addon is disabled.
- Added global **Default Button Font Size** (8) with per-skin **Default**, **Addon's Font Size**, and
  explicit 4-32 choices. Optional automatic resizing is reload-gated, disables the fixed selector,
  and never enlarges beyond the addon's original size. Naowh Forever retains native typography.
- Consolidated every Naowh Forever appearance, component, border, manual-border and bulk setting
  into its three-dot popup and removed the duplicate standalone settings page. Existing
  `naowh`, `buttonStyles` and `skinFeatures` SavedVariables remain compatible.
- Added event-driven skins for DBM timers and LagBuddy's analyzer/settings/results windows. Each
  has an independent master toggle; DBM's unified timer
  border and icon/bar dividers can also be switched independently.
- Reused the configured Additional Skinning border engine for one cached DBM layout hull around
  the bar and all visible icons, with castbar-style dividers, native-edge suppression,
  secret/protected-frame guards, and no timer-update hooks.
- Added lifecycle and reuse regressions plus source-specific documentation. No polling, recurring
  timer, global frame-creation hook, metric-update hook, or interaction-time tree scan was introduced.
- Fixed DBM normal/huge style transitions so a native border created lazily by the pooled bar is
  suppressed immediately through the shared bar-style lifecycle, without rescanning active timers.
- Repeated assignments of unchanged styled-button text now reuse the cached fit result instead of
  measuring the label again.
- Corrected the source-verified BattlegroundEnemiesFixed integration: role, raid-target and castbar
  visuals stay native; trinket/objective/respawn borders follow actual icon visibility; target and
  focus recolour the existing outer border with target precedence. No polling or protected-frame
  geometry writes were added.
- Moved standalone configured-border ownership and recolouring into shared infrastructure, removing
  BGE's runtime dependency on Naowh Forever state and avoiding Naowh SavedVariables when it is absent.
- Made Auto Resize OFF bypass the fitting engine completely: fixed/native modes install no resize
  hooks, allocate no fit state, and perform zero automatic measurements or automatic font writes.
  Added regressions for dynamic text, dimensions, visibility, reapplication and the disabled hot path.
- Applied BGE's existing and unprotected visual updates immediately in combat. Only decoration that
  must attach to an actually protected frame is queued by operation for the existing combat-end
  event; no full BGE refresh is deferred. Stale pooled trinket/objective hosts are still retired.
- Removed the temporary allocation from every BGE icon-visibility update and added an offline combat
  benchmark covering 10,000 target/focus, trinket, and recycled-row update cycles.

## 2.2.0 - 2026-11-16

- Reduced idle and warm-path skinning overhead: button label fitting now allocates nothing material
  when reapplied and releases dead controls on Lua 5.1, closed custom popup pools no longer rescan
  unrelated menus, and Auctionator ignores unrelated addon-load events.
- Added performance regressions for all three paths and offline benchmarks for warm button label
  fitting and closed popup pools; no polling or recurring timer was added.
- Fixed GearQuest Forever's right-side page tabs so their eight-pixel overlap renders behind the
  main window while the exposed original buttons, states, tooltips and click handlers remain intact;
  navigation no longer causes any skin-owned positioning or repeated layering writes.
- Added scoped automatic label fitting for buttons styled by supported integrations: labels keep
  their intended font size when possible, shrink only as needed to a readable 9px minimum, and
  respond to real text, size and font changes without polling or changing button geometry.
- Completed a repository-wide skin consistency and lifecycle audit: popup menus no longer allocate
  the retired coloured top stripe, BugSack navigation refreshes no longer rewrite unchanged control
  geometry, and readable-text conversion now rejects unsafe colour channels before arithmetic.
- Added regressions for accent-free legacy and modern menus, one-time BugSack navigation layout and
  secret-safe readable text; corrected integration lifecycle and supported-skin documentation.
- Removed Additional Skinning's class/accent-coloured 2px top line from every managed window while
  retaining accent colours on text, selections and functional indicators.
- Fixed Hunter's Field Guide and GearQuest Forever portraits so their original art and hit targets
  sit fully inside the top-left corner.
- Fixed GearQuest's Play style and Track intro washes to cover the full EUI button interior, and
  kept its four original right-side page buttons stable across page navigation by leaving their
  combined layout and selected-state lifecycle under GearQuest's ownership.
- **New skins:** GearQuest Forever (log window, simulate dialog, menus, controls) and Hunter's Field
  Guide (journal, export window, panels, controls), each with its own toggle on the Skins page.
- **Button style per addon:** each addon's row on the Skins page has its own button style (Default,
  EllesmereUI windows or Game Menu) beside its toggle; **Default button style** (General) sets the
  rest. Switches at once.
- The default button style is now **EllesmereUI windows**; Game Menu is opt-in (as the default or
  per addon).
- Fixed: opening the Trade window raised an error (the EllesmereUI window border read a frame the
  game forbids reading).

## 2.1.0 - 2026-11-16

- **Button style** (Skins page): buttons in every skinned addon follow EllesmereUI's Game Menu
  buttons (your Popup Menu button colour and border) by default, or the window skins' dark grey
  button. Switches at once, no reload.
- In the Game Menu style the hover highlight stays inside the button's border, as on the Game
  Menu.

## 2.0.0 - 2026-11-15

- Initial release.
