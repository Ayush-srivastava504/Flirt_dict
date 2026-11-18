# Flirt Dictionary ♥

An offline Android dictionary of flirting, dating and romance vocabulary, built with Flutter. It covers everything from Gen Z dating slang (*rizz, situationship, delulu*) to timeless romantic words from around the world (*coup de foudre, ishq, saudade*).

- **956 hand-written entries** in 11 categories, each with a definition, an example sentence and related words
- **Word of the Day**, **A–Z browsing**, categories
- **Fast, typo-tolerant search** that ignores accents and offers "did you mean" suggestions
- **Favourites, collections, history and recent searches**, stored only on the device
- Copy and share, light and dark mode, accessible (48 dp targets, screen-reader labels, 2× text scale)
- Ads (AdMob interstitials with a frequency cap and UMP consent) and anonymous Firebase Analytics

Privacy policy: <https://ayush-srivastava504.github.io/Flirt_dict/privacy-policy.html>

## Project structure
```
lib/
  app/        bootstrap, theme, dependency scope
  core/       text normalisation (accent folding, slugs, edit distance)
  data/       models, dictionary repository, search engine, key-value storage
  services/   AdMob (consent + frequency-capped interstitials), Firebase Analytics
  state/      LibraryController: favourites, collections, history
  ui/         screens and widgets
assets/data/dictionary.json   the dictionary (single source of content)
test/                         unit, widget, responsive, accessibility and journey tests
integration_test/             on-device journey test
docs/                         PRD, architecture, data model, QA, release docs and the GitHub Pages site
```

## Development
```bash
flutter pub get
flutter analyze
flutter test                                  # 116 tests
flutter test integration_test -d <device-id>  # on a phone or emulator
flutter run
```

## Release build
Release signing reads `android/key.properties`, which is git-ignored and points to an upload keystore stored outside the repo. Without it, release tasks fail on purpose instead of falling back to debug keys.

```bash
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

Debug builds always use Google's AdMob **test** IDs; only release builds use the live ad units.

## Adding words
Add entries to `assets/data/dictionary.json`. The data-integrity tests check that every entry has an example, that IDs are unique and that every `related` word exists:
```json
{"word": "Rizz", "pos": "noun", "category": "slang",
 "definition": "Charm or skill in attracting a romantic interest.",
 "examples": ["He got her number in two minutes — that's serious rizz."],
 "related": ["Rizzler", "Charisma"], "note": "Optional usage note."}
```

## Documentation
See [`docs/`](docs/): [PRD](docs/PRD.md) · [Architecture](docs/ARCHITECTURE.md) · [Data model](docs/DATA_MODEL.md) · [QA strategy](docs/QA_STRATEGY.md) · [Release runbook](docs/RELEASE.md) · [Release report](docs/RELEASE_REPORT.md)
