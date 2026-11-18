# Feature Checklist — v1.0.0

| # | Feature | Status | Verified by |
|---|---|---|---|
| 1 | 956-entry offline dictionary, 11 categories | ✅ | `dictionary_repository_test` |
| 2 | A–Z grid with counts; disabled empty letters | ✅ | `screens_test › Browse` |
| 3 | Letter screen with letter strip | ✅ | `screens_test › Browse` |
| 4 | Category screens | ✅ | `screens_test › Today/Browse` |
| 5 | Word detail: POS, category, definition, examples, notes, related words, collection membership | ✅ | `screens_test › Word detail` |
| 6 | Live ranked search, ignoring case and accents | ✅ | `search_engine_test` |
| 7 | Category filters in search | ✅ | `search_engine_test`, `screens_test › Search` |
| 8 | "Did you mean" typo suggestions | ✅ | `search_engine_test`, `screens_test › Search` |
| 9 | Recent searches (add, reuse, remove, clear) | ✅ | `library_controller_test`, `screens_test` |
| 10 | Search-match highlighting | ✅ | visual |
| 11 | Favourites with swipe-to-remove and undo | ✅ | `screens_test › Saved` |
| 12 | Collections: create, rename, delete, add/remove words, undo | ✅ | `library_controller_test`, `screens_test` |
| 13 | Viewing history: remove, clear with confirmation | ✅ | `screens_test › Saved` |
| 14 | Word of the Day (stable per day, full cycle) | ✅ | `dictionary_repository_test` |
| 15 | Copy to clipboard | ✅ | `screens_test` |
| 16 | Share sheet with double-tap guard and error handling | ✅ | `screens_test` |
| 17 | Persistence across restarts | ✅ | `journey_test`, `integration_test` |
| 18 | Storage-failure warning banner | ✅ | `screens_test › Shell` |
| 19 | Light and dark themes (Material 3) | ✅ | `responsive_test`, `accessibility_test` |
| 20 | Predictive back; Back returns to the Today tab first | ✅ | `screens_test › Shell` |
| 21 | Responsive layouts and 2× text scale | ✅ | `responsive_test` |
| 22 | Accessibility guidelines | ✅ | `accessibility_test` |
| 23 | AdMob interstitial with frequency cap + UMP consent | ✅ | `ad_policy_test`, device |
| 24 | Firebase Analytics (anonymous events) | ✅ | device logcat |
| — | Audio pronunciation, cloud sync, user submissions | ⛔ Out of scope for v1 | — |
