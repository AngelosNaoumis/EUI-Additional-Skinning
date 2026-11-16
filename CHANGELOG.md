# Changelog

## Unreleased

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
