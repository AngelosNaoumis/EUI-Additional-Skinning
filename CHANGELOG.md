# Changelog

## Unreleased

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
