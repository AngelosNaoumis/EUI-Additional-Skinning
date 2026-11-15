# Forever Dungeon Journal

`Skins/ForeverDungeonJournal.lua` · tests: `foreverdungeonjournal_spec`

## Scope

The ForeverDungeonJournal addon's journal, settings, notice, loot filter, favourites and bug-report windows: soft shells, flat tabs and controls, its own palette for headings, cached font writes.

Not installed on Forever: mock-tested only.

## Frame map

| Part | Frames and hooks |
| --- | --- |
| Namespace | `ForeverDungeonJournal_NS` (needs `ToggleJournal`) |
| Exports hooked | `ToggleJournal`, `ShowUpdateNotice`, `ToggleSettingsPanel`, the loot-filter and favourites functions, quest renderers, ... |
| Windows | `ForeverDungeonJournalSettings`, `...Notice`, `...OptionsPanel` (controls only), `...LootFilter`, `...LootFilterResults`, `...Favourites`, `...FavouriteContextMenu` |

## Decisions

- Fonts are cached per FontString and rewritten only when the font, size or flags changed.
- The Blizzard Settings category is embedded, so only its controls are styled.

## Performance

21 hook sites. Legacy journals without exported quest renderers repaint once when their one-shot quest worker hides (see Fixes).

## Fixes

- **Quest worker:** hooking the worker frame's `OnUpdate` would queue a refresh every frame it was shown. The worker is one-shot and hides itself after rendering, so this hooks `OnHide` instead: one refresh, after rendering. Only reached on journals that do not export `RefreshQuestList`/`RefreshQuestDetail`.
- **Combat-retry frame:** lint exceptions tagged on its own event frame (not a target frame).

## Known limits

- Runs on `Scoped.lua`/`Menus.lua` and the shared helpers.
- Mock specs check the behaviour listed in the spec header; the look itself needs an in-game check.

## History

- 2.0.0: added.
