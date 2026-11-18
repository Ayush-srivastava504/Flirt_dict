# QA Strategy

## Test pyramid
| Layer | Location | Runs on | Covers |
|---|---|---|---|
| Unit | `test/unit/` | host (`flutter test`) | Text normalisation, dictionary parsing and integrity, search ranking, filtering, typo suggestions, search performance budget, favourites/history/collections/recent searches, persistence round-trips, corrupt data, storage failures, rapid toggles |
| Widget | `test/widget/screens_test.dart` | host | Every screen and every button: navigation, favourite, copy (clipboard channel), share (share_plus channel, including double-tap and failure), collection dialogs and validation, swipe-to-remove with undo, history clear confirmation, back-button behaviour, storage warning banner, rapid double-tap guard |
| Responsive | `test/widget/responsive_test.dart` | host | All screens at 4 screen sizes × 3 text scales (1.0, 1.5, 2.0); dark theme. Fails on any overflow or layout exception |
| Accessibility | `test/widget/accessibility_test.dart` | host | Android tap-target size, labelled tap targets, text contrast, in light and dark themes |
| Journey | `test/journey_test.dart` | host | Launch → browse → favourite → search → collection → kill → relaunch, with state verified after restart; corrupt storage at launch |
| Integration | `integration_test/app_test.dart` | device/emulator | The same journey against real SharedPreferences and the real asset bundle |

## Edge cases covered
- Empty, whitespace-only, punctuation-only, 10,000-character and regex-metacharacter queries
- Empty collection names, over-long names and duplicate names (ignoring case)
- 101 rapid favourite toggles; 20 rapid collection creations; double-tapping list rows and the Share button
- Write failures (simulated), read failures (throwing store), corrupt JSON, wrong value types, stale IDs
- Unknown word or category IDs passed to detail screens
- Collection deleted while its screen is open

## Commands
```bash
flutter analyze
dart format --output=none --set-exit-if-changed lib test integration_test
flutter test                                   # unit + widget + journey
flutter test integration_test -d <device-id>   # on a phone/emulator
```

## Manual device checklist (per release)
1. Install the release build: `flutter install --release` or `bundletool` from the AAB.
2. Cold start: the home screen appears; Word of the Day is shown.
3. Turn on airplane mode and repeat steps 4–7 with it still on.
4. Browse A–Z, open a word, follow a related link, open its category.
5. Search with a typo and accept a suggestion; apply a filter.
6. Favourite a word, create a collection, copy a word, share it to a messaging app.
7. Force-stop the app and relaunch: all saved data is still there.
8. Set system font size to the largest and enable TalkBack; navigate all tabs.
9. Rotate to landscape on every screen.
10. Watch `adb logcat -s flutter AndroidRuntime ActivityManager:E` throughout: no exceptions, `FATAL` or `ANR` lines.

## Regression policy
After every significant fix, run the full `flutter test` suite. A release requires all suites green, plus the manual device checklist on at least one physical device.
