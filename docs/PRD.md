# Flirt Dictionary — Product Requirements Document

**Version:** 1.0.0 (build 1) · **Platform:** Android (Flutter) · **Application ID:** `com.flirtdict.app`

## 1. Summary
Flirt Dictionary is an offline, ad-supported pocket dictionary of flirting, dating and romance vocabulary — from modern slang ("rizz", "breadcrumbing") to classic literary terms ("billet-doux", "swain"). Each entry has a part of speech, a plain-English definition, example sentences, related words and, where useful, an etymology or usage note.

## 2. Goals
| Goal | Measure |
|---|---|
| Instant answers | Search results update as you type; under 16 ms per query on a mid-range phone |
| Works anywhere | 100% of features work with no network connection |
| Personal library | Favourites, named collections, viewing history and recent searches persist across restarts |
| Daily habit | A deterministic Word of the Day on the home screen |
| Inclusive | Meets Android tap-target, labelling and contrast guidelines; usable at 200% font scale |

**Non-goals for v1:** user accounts and cloud sync, user-submitted words, audio pronunciation, localisation beyond English.

### 4.6 Monetisation & analytics (added 2026-11-18)
- FR-20: AdMob interstitial ads. None before the 4th word opened in a session; after that, at most one every 3 minutes and every 4 words. Never on startup or while typing.
- FR-21: Google UMP consent before personalised ads in the EEA/UK. An "Ad privacy choices" entry is shown when required.
- FR-22: Firebase Analytics records anonymous events only: `screen_view`, `view_word` (with source), `search`, `favourite_add/remove`, `share`, `copy_word`, `collection_create`, `word_of_the_day_open`. No personal data.
- FR-23: If Firebase or AdMob fail to start (no Play services, no network, no consent), the dictionary still works fully.

## 3. Users
- **Curious learners** who hear a new dating term and want to understand it quickly.
- **Daters** who want to understand messages and app culture ("what does *orbiting* mean?").
- **Word lovers** who enjoy classic and foreign romance vocabulary.

## 4. Functional requirements
### 4.1 Dictionary
- FR-1: Bundle at least 900 entries (v1.0 ships 956) across 11 categories, stored as a JSON asset.
- FR-2: Each entry has a headword, part of speech, category, definition, at least one example, optional related words and an optional note.
- FR-3: Skip malformed, duplicate or unknown-category entries at load time instead of crashing.

### 4.2 Browsing
- FR-4: An A–Z grid shows the entry count for each letter. Letters with no words are visibly disabled.
- FR-5: The letter screen lists that letter's words and has a letter strip for jumping between letters.
- FR-6: Each category screen lists its words alphabetically, with a description and a count.
- FR-7: The word detail screen shows every field. Related words and the category are tappable links.

### 4.3 Search
- FR-8: Search runs live as you type (120 ms debounce). It ignores case and accents ("tete" finds "Tête-à-Tête") and ignores punctuation and spacing ("sweettalk" finds "Sweet-Talk").
- FR-9: Results are ranked: exact match, then headword prefix, word prefix inside the headword, headword contains, related words, definition, and finally anything else (examples and notes).
- FR-10: Results can be filtered by category.
- FR-11: Empty states cover no query (show recent searches or a hint) and no results (offer "Did you mean" typo suggestions plus a "Search all categories" reset).
- FR-12: Keep up to 10 recent searches. Each can be removed individually, or all can be cleared.

### 4.4 Personal library
- FR-13: Users can favourite or unfavourite a word from any list or the detail screen. The favourites list supports swipe-to-remove with undo.
- FR-14: Users can create, rename and delete collections. Names are trimmed, limited to 40 characters and must be unique ignoring case.
- FR-15: Users can add a word to or remove it from any number of collections from the detail screen. Removal supports undo.
- FR-16: Keep up to the 50 most recently viewed words, with duplicates collapsed. Entries can be swiped away, or the whole history cleared after a confirmation.
- FR-17: The Word of the Day is stable for a calendar day and cycles through every entry before repeating.

### 4.5 Actions
- FR-18: Copy places the formatted entry on the clipboard and shows a confirmation.
- FR-19: Share opens the Android share sheet. Double-taps must never open two sheets, and failures show a friendly message.

## 5. Non-functional requirements
- NFR-1 **Offline:** all dictionary features work without a network connection. Only ads and analytics use the network.
- NFR-2 **Privacy:** no accounts and no personal data collected by the app. Saved words stay in app-private storage. Third-party data is limited to AdMob and Firebase Analytics, as declared in `PRIVACY_POLICY.md` and the Data safety form.
- NFR-3 **Resilience:** corrupt or unreadable stored data must never block startup. Write failures keep in-memory state and show a warning banner.
- NFR-4 **Performance:** cold start to an interactive home screen in under 1.5 s on a mid-range device. Scrolling at 60 fps.
- NFR-5 **Compatibility:** Android minSdk follows the Flutter default; target SDK is the latest stable.
- NFR-6 **Accessibility:** 48 dp tap targets, semantic labels on every icon button, WCAG AA text contrast in both themes, and layouts that hold up at 2× text scale.

## 6. Release criteria
All unit, widget and journey tests pass. `flutter analyze` reports no errors or warnings. The release app bundle is signed with the production upload key, and the version code and application ID are verified.
