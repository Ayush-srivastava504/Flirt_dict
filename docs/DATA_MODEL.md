# Data Model & Storage Design

## 1. Bundled dictionary (`assets/data/dictionary.json`)
Read-only. It ships inside the APK/AAB and is never modified at runtime.

```json
{
  "version": 1,
  "categories": [{ "id": "slang", "label": "Dating Slang", "description": "…" }],
  "entries": [{
    "word": "Ghosting",              // required, headword; id = slug(word) e.g. "ghosting"
    "pos": "noun",                   // required, part of speech
    "category": "slang",             // required, must match a category id
    "definition": "…",               // required
    "examples": ["…"],               // optional list of strings
    "related": ["Orbiting"],         // optional, headwords of other entries
    "note": "…"                      // optional usage/etymology note
  }]
}
```

**Validation:** malformed entries, unknown categories and duplicate IDs are skipped at load time. The unit tests enforce that every `related` reference resolves to a real entry, that IDs are unique, and that every entry has at least one example.

**Current content:** 956 entries in 11 categories (feelings 170, world 116, classic 115, compliments 108, stages 97, slang 77, flirting 65, sayings 58, texting 57, flags 53, weddings 40). Every letter A–Z is covered.

## 2. User data (SharedPreferences, app-private)
| Key | Type | Content | Limit |
|---|---|---|---|
| `favourites.v1` | `List<String>` | Word IDs, oldest first (the UI shows newest first) | unbounded (max 214) |
| `history.v1` | `List<String>` | Word IDs, most recent first, de-duplicated | 50 |
| `recent_searches.v1` | `List<String>` | Raw queries, most recent first, de-duplicated ignoring case | 10, each ≤ 100 chars |
| `collections.v1` | `String` (JSON) | `[{id, name, wordIds[], createdAt}]` | names ≤ 40 chars, unique ignoring case |

The `.v1` suffix allows a future migration without misreading old data.

**Integrity rules on load:**
- Values of the wrong type are ignored.
- Corrupt collection JSON is discarded without affecting the other keys.
- Individual malformed collection records are skipped.
- Word IDs that no longer exist in the dictionary are filtered out.

**Writes:** every mutation is persisted through a serialised queue. The queue is flushed when the app is paused or detached, to protect against termination by the OS.

## 3. Backup
Android Auto Backup is left at its default, so favourites and collections are restored when the user reinstalls the app. No sensitive data is stored.
