# Architecture

One addon folder, the repository's `EUIAdditionalSkinning/` (Lua paths below are relative to it), one private namespace (`local ADDON, ns = ...` in every
file). Globals: `EUIAdditionalSkinningDB`, the slash-command tables (`/eas`, `/easnf`) and the
FontObjects `Menus.lua` creates on first use. Nothing else.

## Layers

| Layer | Files | Owns |
| --- | --- | --- |
| Registry | `Catalog.lua`, `Core.lua` | The integration list; lazy activation; EUI toggles; switches; `/eas` |
| Shared helpers | `Accent.lua`, `Widgets.lua`, `Helpers.lua` | `H` (scan, hooks, fades, fonts, shells, building blocks), soft-skin proxy, accent bar |
| Skin shapes | `Skin.lua`, `Scoped.lua` | `ns.Skin` (house shape), `ns.RegisterScopedSkin` (the scoped shape) |
| Menus | `Menus.lua` | Dropdown and popup menus bound by a skin |
| Skins | `Skins/*.lua` | One target addon each |
| Naowh Forever | `Integrations/NaowhForever/*.lua` | Naowh Forever's theme, fonts, borders; EllesmereUI window and bag borders |
| Options and tools | `Options.lua`, `Dev.lua` | The EUI options section; `/eas dump`, `/eas probe`, `/eas perf` (only in Debug Mode, `db.debug`) |

Load order is the TOC's: catalog, core, helpers, shapes, menus, dev tools, the Naowh
integration, options, then the skins. A skin file only *defines* its factory.

## Lifecycle of a skin

```text
Skins/Foo.lua loads   -> ns.RegisterSkinDefinition("Foo", factory)          (nothing else runs)
ADDON_LOADED / login  -> Register(): target enabled for this character?     -> EUI toggle "EUI Additional Skinning - Foo"
EUI hands S over      -> entry.skin = S -> ns.LoadSkin(entry)
LoadSkin              -> skinning on, row on, EUI toggle on, target enabled and loaded, not in combat
                      -> factory() -> ns.Skin / RegisterScopedSkin / RegisterModule -> module
TryModules            -> module.available() true -> install(S, module), once
install               -> hooks + events; every later change arrives through them as coalesced passes
```

- **Target state** (`Core.lua`): `ns.TargetEnabled` asks `C_AddOns.GetAddOnEnableState` with the
  player's GUID (a name can read as enabled for an addon disabled on this character) and caches
  per character; `ns.TargetLoaded` asks `IsAddOnLoaded`. A failing factory or install is reported
  once through the error handler and never retried.
- **Combat:** a factory deferred by combat runs on `PLAYER_REGEN_ENABLED`; with nothing deferred
  that event returns at once. Passes inside a skin are deferred by its shape.
- **Switches:** `EUIAdditionalSkinningDB.disabled` (master) and `.skins[id] = false` (per row) gate
  `ns.IsEnabled`. Switching on applies at once; switching off needs a reload (hooks stay).

## Skin shapes

| Shape | Used by | What it gives |
| --- | --- | --- |
| `ns.Skin(id, spec)` | Auctionator, new skins | Roots by mode, `before`/`visit`/`after` passes, one coalesced pass per frame, combat deferral, visible-only rewalks, `build(C)` for big skins, `ace`, timing for `/eas perf` |
| `ns.RegisterScopedSkin(id, label, config)` | Altoholic, Attune, BugSack, What's Training? | Roots per pass, `hooks`, `visit`, panel painting, `C.RefreshControlsNow` for subtree repaints, `immediateShow` |
| `ns.RegisterModule(id, label, available, install)` | OneForAll, Forever Dungeon Journal | Nothing beyond install-once; the skin owns its own scheduling |

The first two overlap. They are kept separate on purpose: four working skins are written in the
scoped shape, and merging the shapes would mean rewriting four
working skins for no runtime gain. Both use the same `H` and the same `H.Ace`.

## Naowh Forever

Not a frame skin. Naowh Forever builds almost every frame from shared factories on its namespace
(`_G.NaowhForever`: `THEME`, `Border`, `Button`, `Color`, `UIFontPath`, `ApplyThemeColors`,
`Shared.ItemBar.NewButton`, `Shared.Parts.HudBackdrop`), and its modules read them from the
namespace at call time. `Runtime.lua` repaints `THEME` in place, post-hooks `ApplyThemeColors` and
the backdrop class's `Paint`, and wraps the other factories (they must return their result) before
the modules load. That replacement is the addon's one exception to "post-hooks only".

- **Load order (verified against Naowh Forever 1.2.32's source):** Naowh's modules build their
  frames at `PLAYER_LOGIN` or later (130 login handlers); their 19 `ADDON_LOADED` handlers wait
  for Blizzard's load-on-demand UIs or other addons, never their own load. No Naowh file builds a
  frame at file scope. The integration installs at NaowhForever's `ADDON_LOADED`, or at its own
  `ADDON_LOADED` when Naowh is already loaded: both are before `PLAYER_LOGIN` whatever the folder
  order, so every frame goes through the wrapped factories. The folder name sorting before
  `NaowhForever` (and no dependency on it) additionally puts the wrap before Naowh's own files
  finish, which only matters for two colour strings `NaowhForever_DungeonJournal` builds at file
  scope (`ItemRows.lua` `PERCENT`, `TeamRow.lua` `YOU`): in any other order they keep Naowh's muted
  colour. `/easnf debug` says when Naowh loaded first.
- **What counts as a window:** a top-level frame Naowh outlines with its black edge or paints
  through the backdrop class, at least 160x100, gets EllesmereUI's shell. Frames built by
  `Parts.HudBackdrop` (alerts, restock, trackers, waypoint cards) are HUD elements and never do,
  whatever their size: their background follows Naowh's own background mode.
- **Borders and clipping:** EllesmereUI draws a border on child frames at the frame's edge. A frame
  that clips its children (`SetClipsChildren`, e.g. the waypoint's Quest Objectives card) gets its
  border on a host beside it (same parent and rectangle, shown with it). HUD borders apply one
  frame after the factory, so the module's own setup (clipping, size, hidden state) is seen.
- **EllesmereUI windows and bags** (Skins page, `euiWindows` / `euiBags`): independent of Naowh
  Forever. They share `Runtime.lua`'s border engine and the border style set on the Skins page,
  but only skinning being on and their own toggles gate them (`EuiLive`, `EuiOption`): they work
  with Naowh Forever absent, its row off, or its custom borders off. Every frame the window
  engine shells (`WSkin.Shell(key, frame)`) of at least 160x100 gets the border on a host above
  its content; the `lootroll` and `loottoast` packs'
  frames qualify whatever their size. On toasts the host is published under
  `EUIAdditionalSkinningBorder`, so EllesmereUI's per-reuse art sweep (which clears child textures
  of frames it doesn't read as foreign) leaves it alone. Every border frame this addon creates is
  in `ns.OwnFrames`, which `H.Allowed` refuses, so a skin walking the same window never styles it.
- **Gate:** `NS.Live()` (skinning on, Naowh row on) guards every entry point;
  the EllesmereUI-window and bag borders work without Naowh Forever loaded.
- **Borders** copy the EllesmereUI main action bar's border (`EllesmereUI.ApplyBorderStyle`), read
  once after login and cached, or with copying off draw the manual border (`naowh.manual`, the
  action bar's border option set) through the same call; Show Behind skips raising the border.
  Reading the copied style uses EllesmereUI internals (`_ModuleNS`, the action-bar profile,
  `PP.GetBorders`, the window engine's `Shell` and frame data), all guarded: an EllesmereUI update
  can switch the border to the plain solid edge, never error.
- **Work after install:** show/hide/size hooks on the frames whose state really changes, one
  `UNIT_SPELLCAST_SUCCEEDED` for the player (GCD icons, only when the pool grows) and one-shot
  `C_Timer.After(0)` deferrals. No ticker, no `OnUpdate`, no scan of `UIParent`.

## Settings

`EUIAdditionalSkinningDB`: `disabled`, `skins[id]`, `naowh` (the Naowh keys and the `manual`
border table, validated by `Integrations/NaowhForever/Config.lua`), `euiWindows`, `euiBags`,
`debug` (Debug Mode), `dumps` (dev tools). The
options section (`Options.lua`,
EUI's plugin API) has a Skins page (the master switch, one row per catalog entry, and the
EllesmereUI window and bag borders, then the border settings: the style, copied or manual, and
Naowh's border switches, built by the Naowh options file as `ns.BorderSections`) and the Naowh
Forever Additional Settings page (Naowh's look and components); changes
save at once and a reload is offered once the player stops changing things.


## Menus

`Menus.lua` styles a dropdown only while its owner was bound by an enabled skin
(`ns.BindPopupOwner`), restores it when reused by anyone else, and paints synchronously so a menu
never shows unskinned. Its global hooks (`ToggleDropDownMenu`, `UIDropDownMenu_AddButton`, the
LibUIDropDownMenu copies) install on the first bind and return at once unless a bound menu is
shown or one of ours needs restoring.

## Dependencies

- Required: `EllesmereUI` (public skin API, plugin API, widgets, popups, border style).
- Optional, loaded first when present: `EllesmereUIBlizzardSkin` (dispatches the skin facade; without
  it no frame skin activates, the Naowh borders still work), `EllesmereUIActionBars` (border style),
  `EllesmereUIFriends`, `EllesmereUIBags` (windows and bags the EllesmereUI borders reach).
- Never: the target addons or NaowhForever.

## Extension points

- A skin: catalog entry + `Skins/<Addon>.lua` (`python scripts/new_skin.py`).
- A helper: `Helpers.lua` (`ns.AddSkinHelpers`), documented by its comment (`api_index.py`).
- An options page: append to `ns.OptionPages` before `Options.lua` loads.
- A slash subcommand: `ns.SlashCommands[name] = function(argument, Print)`.
- A non-frame integration: its own folder under `Integrations/`, a catalog entry with
  `integration = true`, `entry.onSkin` / `entry.active`, gated like `NS.Live()`.
