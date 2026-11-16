# Skin development

A skin is one file, `Skins/<Addon>.lua`, plus its catalog entry in `Catalog.lua`, a spec and a doc.
The file hands a factory to `ns.RegisterSkinDefinition(id, factory)`; Core runs the factory only
once the target addon is enabled for the character and loaded, so a skin costs nothing while its
addon is absent (ARCHITECTURE.md, "Lifecycle").

Inside the factory a skin takes one of two shapes:

- **`ns.Skin(id, spec)`** (`Skin.lua`): the house shape, for new skins. The spec says *what* to
  style; the framework decides *when*: one coalesced pass per frame, deferred through combat,
  hidden windows walked once then only while visible, refreshed when EUI's looks change.
  `Skins/Auctionator.lua` is the full worked example.
- **`ns.RegisterScopedSkin(id, label, config)`** (`Scoped.lua`): the scoped shape, which the
  skins Altoholic, Attune, BugSack and What's Training? are written in. Keep using it there; don't
  start new skins in it.

OneForAll and Forever Dungeon Journal call `ns.RegisterModule` directly (the lowest level). The
Naowh Forever integration is not a frame skin at all (ARCHITECTURE.md).

Each skin's EUI toggle and its row on the **Additional Skinning** options page come from its
catalog entry: nothing to add by hand (`tests/options_spec.lua` checks every TOC skin defines one).

**Code and notes are kept apart.** The skin file says *what* is done, with one-line comments.
Each skin's `docs/skins/<Addon>.md` keeps the rest: the frame map, the reasoning behind each
decision, performance notes, known limits and history. Read it before changing a skin, and
update it in the same change.

## The recipe

1. **Scaffold.** `python scripts/new_skin.py <AddonFolder> [--label "Name"] [--global GlobalTable]`
   creates `Skins/<Addon>.lua`, `tests/<addon>_spec.lua` and `docs/skins/<Addon>.md` from
   `scripts/templates/`, adds the catalog entry (`targets = {"<AddonFolder>"}`) and the TOC line,
   then runs lint and the tests (green from the start). Don't add the target to `## OptionalDeps`:
   the catalog waits for it, and an optional dependency could pull Naowh Forever in early.
2. **Find the frames** and write them into the doc's frame map. Faster than `/fstack`:
   with **Enable Debug Mode** on (Skins page), `/eas dump <GlobalFrame>` (or `dump mouse`),
   `/reload`, then `python scripts/read_dump.py <GlobalFrame>` prints every child's key, type, size, state, first anchor, art and text, plus each frame's own methods
   (`fn=Refresh,SetView,...`): the mixin functions worth hooking. `--spec` turns the same dump into a
   `tests/support.lua` fixture that rebuilds the real tree for the skin's spec. In game, open the addon and use `/fstack`, then hover each part. Note:
   - the global names of the windows;
   - the keys of special parts (`f.ScrollBox`, `f.Inset`, `f.Tabs`, ...);
   - the functions that create or redraw them (`OnLoad` mixins, `Show...`, `Update...`, pools).
3. **Roots and hooks.** In `setup(C)`, add each window with `C.AddRoot(frame, mode)`, and hook the
   functions that create or redraw frames with `C.H.Hook(object, "Method", C.refresh)`. Frames
   created later go in from the hook, through `C.AddRoot`.
4. **Special frames.** Buttons, inputs, checkboxes, dropdowns, scroll bars and status bars are
   styled automatically by kind. Use `visit(C, f, kind)` for everything else, and return `true`
   for frames you styled so the automatic pass leaves them alone.
5. **Test.** Follow [TESTING.md](TESTING.md): mirror the real frame layout in the spec (`tests/support.lua`) and assert each
   behaviour. Then break each feature once on purpose (comment it out) and check that a test
   fails.
6. **Write down the why.** Add each non-obvious choice to the doc's Decisions section.
7. **Check in game.** Test with EUI's window style set to EllesmereUI and to Modern, and once
   with the Classic or Blizzard look. Open every window, tab and popup. Check in and out of
   combat, and after a `/reload` with the window open. Then the switch: in EUI's options,
   **Additional Skinning**, the skin's row is there under its catalog label, locked while its
   addon is disabled. Every change offers a reload: off and reloaded, the addon is stock; on again,
   it is skinned.

## `ns.Skin(id, spec)`

| Field | When it runs | Purpose |
| --- | --- | --- |
| `available()` | until true | The target addon is loaded (usually `_G.Target ~= nil`). Required. |
| `label` | | Overrides the catalog label for the module (default: the catalog entry's). |
| `ace` | every frame walked | The target builds its UI with AceGUI/AceConfig: style its dropdowns and checkboxes (`H.Ace`) before `visit`. |
| `style(S, module)` | install | Return the `S` facade to use, e.g. `ns.CreateSoftSkin(S, module)` for borderless controls. |
| `build(C)` | install | Return any handlers below as a table, so a big skin's helpers share locals. Spec fields fill gaps. |
| `setup(C)` | install | Add roots, install hooks. |
| `events` / `event(C, event, ...)` | on event | Extra events that refresh the skin, and a handler that sees every event. |
| `active(C)` | each pass | Return false to leave the target stock this pass (e.g. follow EUI's window style). |
| `before(C)` | each pass | Before the walk: sync tab state, add roots discovered this pass. |
| `roots(C)` | each pass | Extra roots: frames, or `{frame = f, mode = "window"}`. Prefer `C.AddRoot` in `setup`. |
| `visit(C, f, kind)` | every frame walked | Style special frames; return true to claim the frame. |
| `after(C)` | each pass | After the walk: layout that needs styled controls in place (measured gaps, alignment). |

**Root modes:**

- `"controls"`: the default; controls only, no window shell.
- `"window"`: a themed shell.
- `"content"`: a shell without the title strip.
- `"dialog"`: a shell with a footer strip.

A window inside another skinned window (a tab panel) is `"controls"`.

**The context `C`:**

- `C.S`: the EUI facade.
- `C.H`: the helper, described below.
- `C.module`
- `C.refresh()`: queue a pass.
- `C.AddRoot(frame, mode)`: re-adding changes the mode; adding without a mode keeps the current
  one.

## What the walk does for you

`H.Scan` walks each root's children, skipping protected and forbidden frames, models and tooltips:

- **Controls styled by kind:**
  - `Button` with a text label → `S.Button` + `S.StateButtonLabel`;
  - `EditBox` → `S.EditBox{padInput}`;
  - `CheckButton` → `S.Checkbox`;
  - `DropdownButton` → `S.Dropdown`;
  - vertical `Slider` → `S.ScrollBar`;
  - `StatusBar` → `S.ApplyBarFill`;
  - minimise-art close buttons → `S.CloseButton`.
- **Square icon buttons:** their icon is squared.
- **Fonts:** every FontString is re-fonted once.
- **Hooks:** `OnShow`, `OnClick`, `OnEnable` and `OnDisable` queue a refresh, so new and changed
  controls get styled. A `ScrollFrame` refreshes only its own subtree on scroll.
- **Header bars:** a list with a `HeaderContainer` gets `S.SortHeaderBar`. Override it in
  `style()` if the target's header is a different height (Auctionator does).

## `C.H`: helper reference (`Widgets.lua`, `Helpers.lua`)

| Call | Use |
| --- | --- |
| `H.Allowed(f)` | A real, unprotected, unforbidden UI object. Check before touching any frame. |
| `H.Hook(object, "Method", fn)` | Post-hook once per object and method; skipped while the skin is disabled; errors isolated. |
| `H.Script(frame, "OnShow", fn)` | Same for frame scripts (`HookScript`, never `SetScript`). |
| `H.Queue(key, fn)` | Coalesce work into the next frame (`C.refresh` already does this). |
| `H.Fade(texture)` | Alpha 0, kept at 0 if the target re-shows it. Never `Hide()` someone else's art. |
| `H.Font(text [, r, g, b])` | EUI font (and colour); a no-op when already applied. |
| `H.Texture(v)` / `H.Icon(f)` | A Texture region or nil; an item/spell button's icon texture. |
| `H.Shell(f, refresh, options)` | Themed window shell without a coloured top accent line; root modes call this. |
| `H.Tab(tab, selected)` | House tab with an explicit selected state. |
| `H.Regions(f)` / `H.Children(f)` | Region and child lists (cheap for frames with none). |
| `H.Action(f, keepKeys)` / `H.LegacySlider(f)` | Backdrop-template buttons; classic `Slider` scroll bars. |
| `H.ScrollBar(bar)` | Any scroll bar: classic `Slider` or `WowTrimScrollBar` (caps and Background track faded). |
| `H.Strip(f)` | Clear an inset or list panel, keeping its foreground art (spinners, icons). Once per frame. |
| `H.Wash(f)` | EUI's results-area tint: a 2% fill with 1px top and left seams, on a child layer. Once. |
| `H.Glyph(button)` | EUI's white refresh glyph replacing a button's art; native if the atlas is missing. |
| `H.Squared(button, icon [, inset])` | Square, inset icon, re-applied whenever a pooled button is refilled. |
| `H.Pooled(scrollBox, styleRow)` | Restyle a ScrollBox's rows on every refill, without a skin pass. |
| `H.Once(f, key)` | True the first time for this frame and key. |
| `H.Ace(f, refresh)` | AceGUI widget frames: dropdown and checkbox styled; true when `f` was one. |
| `H.Artwork(f)` | A panel's foreground art and alphas, to restore after a fade. |
| `H.Shift(f, dx, dy)` / `H.Pixel(f)` | Move a frame keeping its anchors; one physical pixel. |
| `H.Safe(fn, ...)` | Call with one error report per distinct error. |
| `H.ThinBackdrop(f)` | A backdrop frame redrawn with a 1px flat edge, keeping its colours. |
| `H.Selection(f, selected)` | Flat row with an accent fill while selected. |
| `H.Toggle(f, expanded)` | Expand/collapse button drawn as a `+` / `-` glyph. |
| `H.Portrait(f, player, noAccent)` | A window's round portrait replaced by a square one. |
| `H.Resize(f, force)` | A size grabber's art faded, replaced by a small `+`. |

Also in `ns`:

- `ns.CreateSoftSkin(S, module, borderless)`: the softer, borderless control variant;
  `borderless(f)` hides the soft edge on chosen controls.
- `ns.AttachAccent(S, frame)`: compatibility no-op; Additional Skinning windows intentionally do
  not add a class/accent-coloured line along their top edge.
- `ns.BindPopupOwner(S, module, owner, options)` / `ns.BindPopupList(...)` (`Menus.lua`): skin the
  dropdown menus a target opens from `owner`. The shared menu hooks install on first use.

## `C.S`: the EUI facade

These are EllesmereUI's public primitives (its `SKINNING_API.md`):

- **Window and panels:** `Shell`, `Panel`, `Inset`.
- **Controls:** `Button`, `EditBox`, `Checkbox`, `Dropdown`, `ScrollBar`, `Tab`, `SetTabSelection`,
  `CloseButton`, `PageButton`, `SquareIcon`, `SortHeaderBar`.
- **Fading and text:** `FadeRegions`, `FadeNineSlice`, `Font`, `White`, `ApplyBarFill`.
- **Queries:** `GetAccentColor`, `GetPanelColor`, `GetFont`, `GetStyle`, `OnLooksChanged`.

Prefer them over drawing your own. Every primitive is safe to call again on the same frame.

## Recipes

Copy-ready starting points. Frame and method names are placeholders; take the real ones from a
dump (`fn=` lists the methods to hook).

**An addon with its own windows.** Shell the main window, scan the options window as controls,
and hook what opens them.

```lua
ns.Skin("Foo", {
    available = function() return _G.Foo ~= nil end,
    setup = function(C)
        C.AddRoot(_G.FooMainFrame, "window")
        C.AddRoot(_G.FooOptionsFrame, "dialog")
        C.H.Hook(_G.Foo, "ToggleMainFrame", C.refresh)
    end,
})
```

**A window created on first use.** Add it from the hook that creates it; the framework walks it
on the next pass.

```lua
setup = function(C)
    C.H.Hook(_G.Foo, "CreateHistoryWindow", function(_, frame) C.AddRoot(frame, "window"); C.refresh() end)
end,
```

**A list whose rows are reused.** Style each row from the box's own refill, not a skin pass.

```lua
visit = function(C, f)
    if f.ScrollBox then C.H.Pooled(f.ScrollBox, function(row) C.H.Strip(row) end) end
end,
```

**An AceConfig options panel.** `ace = true` styles the AceGUI dropdowns and checkboxes; the
panel itself is the root.

```lua
ns.Skin("Foo", {
    ace = true,
    available = function() return _G.Foo ~= nil end,
    roots = function()
        local dialog = LibStub and LibStub("AceConfigDialog-3.0", true)
        local open = dialog and dialog.OpenFrames and dialog.OpenFrames.Foo
        return open and {{frame = open.frame, mode = "window"}} or {}
    end,
})
```

**A panel inside a Blizzard window EUI already skins.** Follow EUI's style for that window,
don't shell the panel, and match the host's values (see the Auctionator doc).

```lua
active = function()
    local EUI = _G.EllesmereUI
    local style = EUI and EUI.GetBlizzWindowStyle and EUI.GetBlizzWindowStyle("auctionhouse")
    return style ~= "off" and style ~= "blizzard"
end,
setup = function(C) C.AddRoot(_G.FooPanel, "controls") end,
```

**Item slots and refresh buttons.** Square icons kept square on refill; the house refresh glyph.

```lua
visit = function(C, f, kind)
    if kind == "Button" and f.Icon and f.IconBorder then C.H.Squared(f, f.Icon); return true end
    if f.RefreshButton then C.H.Glyph(f.RefreshButton) end
end,
```

**A layout fix that needs real positions.** Measure in `after`, once the numbers exist, and only
then mark it done.

```lua
after = function(C)
    local box, button = _G.FooInput, _G.FooGoButton
    if not (box and button and box:GetRight() and button:GetLeft()) or not C.H.Once(box, "gap") then return end
    local gap = button:GetLeft() - box:GetRight()
    if gap < 4 then C.H.Shift(button, 4 - gap, 0) end
end,
```

## Detecting the addon

- **The catalog decides when.** `targets` lists the addon folders that count as installed; the
  factory runs once one is enabled for this character (`ns.TargetEnabled`, by player GUID) and
  loaded (`ns.TargetLoaded`). Never call `LoadAddOn`.
- **`available()` decides whether.** Inside the factory, `available()` says the target's own
  frames or namespace exist (`_G.Foo ~= nil`); the module installs the first time it is true
  (re-checked on every `ADDON_LOADED`).
- **Load-on-demand targets** need nothing extra: their `ADDON_LOADED` runs the factory.

## Patterns that work

- **Pooled frames** (list rows, bag slots) are reused with new content. Hook what refills them
  (`ScrollBox.Update`, an icon's `SetTexture`), not just their creation, and restyle only that
  frame, not the whole skin. See `Item`/`Square` and `Row` in the Auctionator skin.
- **Re-entry guards:** when a hook restyles the thing it hooks, guard it (`if busy[f] then return
  end`) so your own `SetPoint`/`SetTexture` calls don't loop.
- **Measure layout once it exists:** `GetLeft`/`GetRight` are nil until a frame has been laid out.
  Do measured fixes in `after()`, mark them done only once the numbers exist, and move whichever
  frame is anchored to the other.
- **Follow the host's style:** when skinning inside a Blizzard window EUI also skins, read EUI's
  style for it and stay stock under the Blizzard or Classic look (`active`, see `Stock()` in the
  Auctionator skin). Match the host's own values (colours, line widths, heights) so the two read as
  one window.
- **Visual only:** never replace callbacks, `SetScript` someone else's frame, or touch protected
  frames. Post-hook only, and fade art with alpha.
- **Combat:** passes are deferred automatically. A hook that resizes or re-anchors should call
  `C.refresh()` in combat instead of acting.
- **Discovery:** never scan `_G` or `UIParent` on every pass. Discover at install, on
  `ADDON_LOADED`, or from the target's own initialiser (Auctionator's `discoveryDirty`).

## Performance checklist

- No `OnUpdate`, no tickers, no polling; hooks and events only.
- Nothing in `visit` or per-pass code builds tables: keep constant lists in locals outside it,
  and cache per-frame answers (`refreshes[button]`).
- Check before writing: compare the current font, alpha, points or size before setting them
  (`H.Font` does this for fonts).
- Measure in game: `/eas perf` times every skin pass (count, average and worst ms) and shows
  WoW's own addon CPU metric where the client has it; `perf off` / `perf reset`.
- Benchmark before and after a change that touches per-pass code:
  `python scripts/benchmark.py auctionator --before <copy of the previous version>`.

## Style

- A skin file keeps one order, with numbered section comments:
  1. state;
  2. context (style or host checks);
  3. panels and tables;
  4. controls;
  5. target-specific forms;
  6. layout;
  7. detection;
  8. host integration;
  9. `Visit`;
  10. passes and install.

  A small skin only needs the sections it uses.
- 4 spaces, LF; `local ADDON, ns = ...` first; one skin per file.
- Local helpers in PascalCase (`Zone`, `Glyph`); state tables plural, keyed by frame (`rows[row] = true`).
- Comments explain *why*: what the target does that makes the code necessary. They don't restate the code.
- ASCII only; specs start with one comment line naming every behaviour they cover.

## Before a release

1. `python tests/run.py`: lint clean, every file compiled as Lua 5.1 (WoW's Lua, with its 60-upvalue and
   200-local limits), every spec green, and each new feature shown to fail a test when broken.
   Lint covers ASCII, tabs, trailing whitespace, `SetScript` in skins, and a doc and spec for every skin.
2. Check in game: both EUI styles and the Classic/Blizzard look, combat, `/reload`, and each new
   skin's off/on switch on the Additional Skinning options page.
3. `CHANGELOG.md` entry; bump `## Version` in the TOC and `ns.VERSION` in `Core.lua` together.
4. `python scripts/package.py`: builds and verifies `dist/EUIAdditionalSkinning-<version>.zip`.
