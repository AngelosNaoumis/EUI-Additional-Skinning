# Auctionator

`Skins/Auctionator.lua` · tests: `auctionator_modern_spec`, `auctionator_legacy_spec`,
`auctionator_integration_spec` · benchmark: `benchmarks/auctionator.lua`

Skins Auctionator inside the auction house so it reads as part of EUI's own auction house skin
(the "pack" in EllesmereUI Blizzard Skins+), on both auction house generations.

## Scope

| Auction house | Look |
| --- | --- |
| Modern (`AuctionHouseFrame`) | Matches EUI's pack: bordered controls, Auctionator's tabs in the native tab row, washed results tables, gold form labels. |
| Legacy (`AuctionFrame`) | The softer, borderless style: Auctionator panels get their own shells and soft panels. |
| Either, under the Blizzard or Classic look | Stock. EUI leaves the auction house on Blizzard art, so Auctionator does too. |

It loads lazily once Auctionator is enabled and loaded.

## Frame map

| What | Where |
| --- | --- |
| Tab panels | `_G[details.tabFrameName]` for each `Auctionator.Tabs.State.knownTabs` entry (Shopping, Selling, Cancelling, Auctionator) |
| Modern tab buttons | `AuctionatorAHTabsContainer.Tabs` (LibAHTab buttons); `tab.frameRef` is the panel |
| Legacy tab buttons | `AuctionatorTabs_<name>`, `tab.wrapperFrame`; Blizzard's `AuctionFrameTab1..3` |
| Results tables | Listings with `HeaderContainer` and `ScrollArea.ScrollBox` (rows have `.cells`) |
| Sell form | `AuctionatorSellingFrame.SaleItemFrame`: money input (`GoldBox`, `SilverBox`, `CopperBox`), `Quantity`, radio duration widgets (`isAuctionatorRadio`) |
| Selling price tabs | Container with `CurrentPricesTab`, `PriceHistoryTab`, `YourHistoryTab`; table `CurrentPricesListing` |
| Shopping | `SearchOptions` (`SearchString`), `ContainerTabs` (`ListsTab`, `RecentsTab`), `ListsContainer`, `NewListButton`, `ImportButton`, `ExportButton` |
| Refresh buttons | Keyed `RefreshButton`, or icon-only buttons directly on Cancelling, the sale form and the two buy views |
| Bag items | Buttons with `Icon` plus `IconBorder`, `EmptySlot` or `IconSelectedHighlight` |
| Option widgets | Frames with `DropDown` (arrow on a child button) and `ResetButton` (`.texture`) |
| Popups | `AuctionatorShoppingTabItemFrame` (Extended Search Options), export/import/item history dialogs, numbered `AuctionatorDialog<n>` |
| Elsewhere | `AuctionatorConfig*Frame` options panels; crafting price frames on the profession windows |
| Created later | Mixins hooked on `OnLoad`; `Auctionator.Dialogs.Show*`; `Auctionator.CraftingInfo.Initialize*`; LibAHTab `CreateTab` |

## Decisions

**Following EUI's style.** `Stock()` reads `EllesmereUI.GetBlizzWindowStyle("auctionhouse")`.
Under `off` or `blizzard` the skin does nothing. This global sits outside the `S` facade, so the
call is guarded. Switching away from a skinned style needs a reload, as with EUI's own skins.

**Controls.** On the modern auction house the `style` proxy hands out EUI's bordered primitives,
matching the pack's buttons and inputs. On `AuctionFrame` it hands out `ns.CreateSoftSkin`'s
borderless ones. `S.SortHeaderBar` is routed to the skin's own `Headers`.

**Tab row.**
- Auctionator's tabs are chained after the last Blizzard tab, one physical pixel apart and 2px
  shorter, as the pack's tab rows are.
- Selection comes from `tab.frameRef:IsShown()`.
- Opening an Auctionator tab clears the auction house display mode, and the pack's own tab sync
  skips that case. So while an Auctionator tab is active, the Blizzard tabs are forced unselected.

**Zone seams.** The pack draws two full-width 1px seams, placed for Blizzard's views, on an unnamed
child of `AuctionHouseFrame` that the facade doesn't expose. The skin finds it by shape (unnamed,
two thin textures, two sub-frames) and lowers its alpha while an Auctionator tab is open. If EUI
changes that frame, nothing is found and the seams simply stay.

**Panels and tables.**
- Tab panels inside the skinned window get no shell (`ContentMode`); a second shell darkened them
  against Blizzard's panels.
- Insets are stripped (`H.Strip`).
- Each results table washes its own `ScrollArea` (`H.Wash`), and its header strip spans that same
  area, so wash, seams and header share corners. The header row itself can start outside the list
  and the window. EUI's fixed 24px `SortHeaderBar` hung into the first row.
- Rows use the pack's white hover (0.1) and selection (0.15) washes and are restyled per
  `ScrollBox:Update` (`H.Pooled`).

**Bag icons.** Auctionator re-masks and re-crops its pooled bag icons on every refill, so
`H.Squared` re-squares them from the icon's own setters. Quality rings hug the inset icon, and grey
or white rings (poor, common) fall back to the black edge, as in the pack.

**Sell form.**
- **Coins and edges:** money boxes keep their coin icons (small square textures) and lose their
  edge art (global `<name>Left/Middle/Right` too).
- **Height:** the money boxes are 5px shorter, like the pack's sell inputs.
- **Copper and Post:** the copper box keeps 4px from the button right of it (Post). The gap is
  measured after the walk (`Clear`), because Auctionator anchors it differently between builds.
- **Quantity:** centred.
- **Labels:** gold, as on Blizzard's Sell tab. A label has letters and no digits, so values
  (deposit, coins, hours) keep their colour.

**Refresh buttons.** These become EUI's white refresh glyph (`H.Glyph`). Some are found by icon
name. Cancelling's icon is set by file ID, so icon-only buttons directly on a known panel count
too, the approach Luckyone's Auctionator skin uses. Without the `UI-RefreshButton` atlas the native
button stays.

**Inner tabs.** Lists/Recents use the pack's dark-active tabs. Selling's price tabs sit just above
the main tab row, so they're flat (no plate), and the row is aligned to the current prices table.

**Layout fixes, measured once the layout exists:**
- the Shopping search row is lifted until 6px clear of the list tabs;
- New List / Import / Export become three equal buttons, 4px apart, inside the lists column.

**Option widgets.** Wrapped dropdowns get `S.Dropdown`, and their arrow button's art is faded.
Reset buttons stay a bare icon with a hover wash, because a block around each one read as a stray
empty box wherever Auctionator hides the icon. Popups' insets stay clear, so their form sits
plainly on the window, like the Auctionator (Info) tab.

## Performance

- Constant key lists live outside `Visit`, and refresh detection is cached per button.
- The header strip is only re-anchored when it moves.
- Hidden panels aren't walked after their first pass (framework).
- Config discovery searches `_G` only after an Auctionator-prefixed `ADDON_LOADED` or Auctionator's
  own initialiser. The few Blizzard modules that can add Auctionator surfaces still refresh the
  visible tree, while unrelated addon-load events are ignored.

`benchmarks/auctionator.lua` (about 650 frames, Selling open): about 2.3 ms and 80 KiB per warm
refresh on the Lua 5.4 host.

## Known limits

- The zone seams depend on the shape of a private EUI frame (see above).
- Measured fixes (copper gap, tab alignment, search gap) are decided once per frame and are not
  re-measured if Auctionator rebuilds its layout mid-session.
- Refresh detection is decided the first time a button is seen.

## History

- 2.0.0: the quantity input
  inside Auctionator 341+'s `Quantity.InputBox` wrapper is centered with its number text
  (`81ba5d0`); number inputs use EUI's font (`9e6cd0b`, font only); Auctionator settings inputs
  are styled without the walk's padding, which moved their hit rectangle (`04215f6`).
