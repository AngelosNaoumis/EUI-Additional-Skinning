# Naowh Forever

`Integrations/NaowhForever/` · tests: `naowh_spec`

## Scope

Naowh Forever's flat "Naowh" look in EllesmereUI's palette, accent and font; EllesmereUI window
shells on Naowh windows; the border of the user's EllesmereUI Main Action Bar 1 (or the manual border)
on item buttons, HUD elements, trackers, PvP and raid aura icons, GCD icons, the focus cast bar
(one hull with a divider) and the top bar's groups; dark item plates. The EllesmereUI window and bag
borders live in the same file and use this popup's border style, but are switched on the Skins page
and work without Naowh Forever (ARCHITECTURE.md). Naowh's metal "Forever" look is left
alone (a chat line says so). No border on on-screen alerts or the minimap layer readout.

Installed on Forever (Naowh Forever 1.2.32): check in game.

## Frame map

| Part | How it is reached |
| --- | --- |
| Palette | `ns.THEME` tables repainted in place after `ns.ApplyThemeColors` (post-hook); accent changes via `EllesmereUI.RegAccent` |
| Font | `ns.UIFontPath` wrapped: EllesmereUI's font path |
| Buttons | `ns.Button` wrapped: brighter resting edge |
| Text colours | `ns.Color` wrapped: string tokens resolve to the live theme table |
| Outlines, windows | `ns.Border` wrapped: remembers outlines, watches top-level windows |
| Window backdrops | the shared backdrop class's `Paint`, post-hooked |
| Item buttons | `Shared.ItemBar.NewButton` wrapped: plate and border |
| HUD elements | `Shared.Parts.HudBackdrop` wrapped: border in every background mode |
| Aura icons | `PvP.Icon.New`, `RaidDebuffs.Icon.New` post-hooked after `NaowhForever_Combat` loads (`Auras.lua`) |
| Focus cast bar, top bar, GCD tracker | `NaowhForeverFocusCastBar`, `NaowhForeverTopBar`, `NaowhForeverGcdTracker` |
| EllesmereUI windows | the window engine's `WSkin.Shell` post-hooked; `FriendsFrame`; `EUI_MainBagFrame`, `EUI_ReagentBagFrame`, `EUI_BankFrame` |

## Decisions

- **Wrapping, not post-hooking,** for the factories that return a frame or value: the one
  exception to the addon's post-hook rule. Naowh's modules read these from the namespace at call
  time, so wrapping them before the modules load reaches every frame without touching Naowh's files.
- **Load order:** wrapped at NaowhForever's `ADDON_LOADED` (this folder sorts before it and depends
  on nothing that depends on it). If Naowh loaded first the integration still activates.
- **Restricted aura buttons** get one non-interactive child overlay during Blizzard's allowed
  `initializeFrame` phase; never a script, never a branch on their secret `IsShown()`.
- **Hidden frames stay hidden:** applying a border never shows a frame Naowh built hidden.
- Settings apply after `/reload`: the styling state is fixed for the session.
- **One settings popup:** appearance, component switches, copied/manual borders
  and bulk actions are registered through `A.RegisterSkinSettings` and rendered by the Naowh row's
  three-dot control. The old standalone page and expanded border sections were removed. Settings
  remain editable while Naowh is absent or switched off. Shared button typography is deliberately
  excluded: Naowh's button factory and later native font updates retain their own sizes.
- **Border modes:** "Copy Main Action Bar 1 border" (`edgeMode = "actionbars"`) reads that bar's
  border once after login. Off (`"solid"`), the manual border (`naowh.manual`) is drawn: the
  action bar page's option set, edited with EllesmereUI's own controls (`GetBorderTextureDropdown`,
  `BorderPxSliderCfg`, `BorderOffsetRowCfgs`, offsets in its `actionbars` registry) and drawn by
  `ApplyBorderStyle` with the same arguments the action bars pass. A style pick resets offsets,
  shifts and exact size and takes the style's default size, colour and Show Behind, as the action
  bar page does. Manual values survive switching modes; Reset to Defaults clears them. The first
  manual border is seeded from the old plain edge (`edgeSize`, `edgeR/G/B`); no other migration.
- **Show Behind** leaves the border at its element's level (under child content) instead of
  raising it one level above.

## Performance

| Work | When |
| --- | --- |
| Factory wrappers | Only when Naowh builds an element; idempotent per frame (weak-key caches) |
| Show/hide/size hooks | Only on frames whose visibility or geometry really changes |
| `UNIT_SPELLCAST_SUCCEEDED` | Registered for the player only; one child-count compare, a scan only when the GCD pool grew |
| `C_Timer.After(0)` | One-shot, deduplicated deferrals while a factory finishes |
| Border style | Resolved once after login and cached |

No `OnUpdate`, no repeating timer, no periodic or `UIParent` scan. Disabled features install
nothing: there is no GCD ticker or extras poll.

## Integration wiring

Namespace wiring, the `NS.Live()` gate,
the facade through the catalog, the player-only GCD event, and the declarative three-dot settings.

## Known limits

- Reads EllesmereUI internals for the action-bar border and the window engine; guarded, falls
  back to a plain edge.
- **Border Above Effects** (an action bar option) is not offered: it lifts a bar's border above
  the button's cooldown swipe and proc glow. Naowh's borders sit on frames without those effect
  layers and are already drawn above the element's content (Show Behind is the opposite choice).
- The manual Border Size, offset and style controls are EllesmereUI's; if its options are not
  loaded when the page is built, only Style, Shift, Color, Class Color and Show Behind show.
- Frames Naowh built before the integration activated (Naowh loaded first) keep their look until
  a reload.

## History

- 2.0.0: added; settings in `EUIAdditionalSkinningDB.naowh` and EUI's options; GCD event filtered
  to the player.
