# Architecture

```
lib/
├── main.dart                  Entry point
├── app/
│   ├── app.dart               AppServices.bootstrap(), MaterialApp, splash and startup-error screens, lifecycle flush
│   ├── app_scope.dart         InheritedWidget exposing services to the tree
│   └── theme.dart             Material 3 light/dark themes, 4-pt Spacing scale
├── core/
│   └── text_utils.dart        foldText (diacritics), normalizeForSearch, slugify, boundedLevenshtein
├── data/
│   ├── models.dart            Category, WordEntry, WordCollection (with JSON validation)
│   ├── dictionary_repository.dart  Loads the asset, validates it, indexes by id/category/letter, Word of the Day
│   ├── search_engine.dart     Pre-normalised in-memory index, ranked search, suggestions, did-you-mean
│   └── local_store.dart       KeyValueStore interface, SharedPrefsStore and MemoryStore implementations
├── state/
│   └── library_controller.dart  ChangeNotifier for favourites, collections, history and recent searches
└── ui/
    ├── navigation.dart        Typed route helpers with a double-push guard
    ├── widgets/               WordTile, FavouriteButton, EmptyState, SectionHeader, StorageWarningBanner, collection sheet/dialog
    └── screens/               home_shell, today, browse, letter, category, search, saved, collection, word_detail
```

## Layers and data flow
1. **Bootstrap.** `AppServices.bootstrap()` loads the JSON asset and opens SharedPreferences in parallel. If storage cannot be opened, it falls back to `MemoryStore`: the app keeps working, but changes are not persisted. If the dictionary itself fails to load, a retry screen appears.
2. **Read-only data.** `DictionaryRepository` is immutable after construction. It builds O(1) lookup maps by id, and precomputed lists by category and by letter.
3. **Search.** `SearchEngine` normalises every entry once (folded headword, compact headword, related words, definition, examples and notes). Each query is a single linear scan with early rejection, followed by a sort on precomputed keys.
4. **User state.** `LibraryController` updates memory first and notifies listeners straight away, so the UI never waits on disk. Persistence goes through a **serialised write queue** (`_writeQueue`), which keeps rapid taps in order. A failed write sets `hasStorageError`, and the next successful write clears it. On load, the controller drops IDs that are no longer in the dictionary and tolerates corrupt JSON one record at a time.
5. **UI.** Widgets read services through `AppScope.of(context)`. Only widgets that display user state wrap themselves in `ListenableBuilder(library)`, so a favourite tap rebuilds the heart icons and Saved lists, not whole screens. Tabs live in an `IndexedStack`, which preserves scroll positions and the search query.

## Key decisions
| Decision | Rationale |
|---|---|
| Bundled JSON instead of SQLite | Around 214 entries (about 60 KB) load in milliseconds. It also avoids native database dependencies, keeps the AAB small and makes the content easy to edit. If the dictionary grows past roughly 10k entries, revisit this with SQLite FTS. |
| `shared_preferences` for user data | The data is small (lists of string IDs plus one JSON blob). Writes are asynchronous and app-private. |
| `ChangeNotifier` + `InheritedWidget` instead of a state library | One controller, so no third-party state dependency is needed. |
| Slug IDs derived from headwords | Stable across app updates. Renaming a headword is a migration event, and unknown IDs are dropped on load. |
| Route-animation-based push guard | Rapid taps cannot stack duplicate pages, and the guard is independent of the clock. |

## Dependencies
Runtime: `flutter`, `shared_preferences`, `share_plus`. Dev: `flutter_test`, `flutter_lints`, `integration_test`.
