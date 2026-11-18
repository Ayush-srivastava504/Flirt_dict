# Release Report — Flirt Dictionary 1.0.0 (build 1)

**Date:** 18 November 2026 · **Package:** `com.flirtdict.app` · **Status:** ✅ ready for the Play internal testing track

## Deliverables
| File | Size | Purpose |
|---|---|---|
| `build/app/outputs/bundle/release/app-release.aab` | 55.0 MB | **Upload this to Google Play** |
| `build/app/outputs/mapping/release/mapping.txt` | 44.7 MB | Upload in Play Console → App bundle explorer → Downloads → ReTrace mapping, so crash reports are readable |
| `build/app/outputs/flutter-apk/app-release.apk` | 20.8 MB | arm64 test build (sideloading only, not for Play) |

AAB SHA-256: `21063ecfead86ad2b12dfb3ef08ee4c1c693d64c86f5012607c4c63f6d9645fc`

## AAB verification
| Check | Result |
|---|---|
| Signature | ✅ Upload key `CN=Flirt Dictionary, O=Flirt Dictionary, C=IN`, cert SHA-256 `49:BA:2C:4B:…:1B:F3` (not the debug key) |
| Application ID | ✅ `com.flirtdict.app` |
| Version | ✅ versionCode 1, versionName 1.0.0 |
| SDK | ✅ minSdk 24 (Android 7.0), targetSdk 36 |
| Debuggable | ✅ No |
| Dictionary asset in bundle | ✅ 956 entries, 11 categories |
| AdMob App ID (release) | ✅ `ca-app-pub-5594205569635986~9933874844` |
| ABIs | ✅ arm64-v8a, armeabi-v7a, x86_64 |
| Permissions | INTERNET, ACCESS_NETWORK_STATE, AD_ID, ad-services (AD_ID/ATTRIBUTION/TOPICS), WAKE_LOCK, FOREGROUND_SERVICE, install-referrer. All come from the AdMob/Firebase SDKs; the app's own manifest requests none |

## Content
956 hand-written entries. Each has a part of speech, definition, example and at least one working cross-reference. Every letter A–Z is covered.

| Category | Entries | Category | Entries |
|---|---|---|---|
| Love & Feelings | 170 | Dating Slang | 77 |
| French & World Words | 116 | Flirting & Charm | 65 |
| Classic Romance | 115 | Sayings & Idioms | 58 |
| Compliments & Pet Names | 108 | Texting & Online | 57 |
| Relationship Stages | 97 | Red & Green Flags | 53 |
| Weddings & Marriage | 40 | | |

## Test results
| Suite | Result |
|---|---|
| Unit: search, storage, favourites, collections, history, ad frequency, data integrity | ✅ pass |
| Widget: every screen, button and interaction | ✅ pass |
| Responsive: 4 screen sizes × 3 text scales, plus dark mode | ✅ pass, no overflow |
| Accessibility: tap targets, labels, contrast (light and dark) | ✅ pass |
| Journey: full use → restart → state restored; corrupt storage at launch | ✅ pass |
| **Total (final run)** | **✅ 116 / 116** |
| `flutter analyze` | ✅ No issues |

### Real device: Samsung Galaxy A36 (SM-A366E), Android 16 / API 36
| Check | Result |
|---|---|
| Install of release APK | ✅ |
| Cold start | ✅ 577–707 ms; warm start 262 ms |
| Firebase Analytics initialised | ✅ "App measurement initialized" |
| AdMob consent SDK (UMP) | ✅ runs (no form in India, as expected) |
| 2,000-event monkey stress test, **airplane mode** | ✅ 0 crashes, 0 ANRs, 0 Flutter errors; dictionary fully usable offline |
| Memory (PSS) | 188 MB idle, 231 MB after stress (mostly the AdMob WebView and Firebase) |

## Bugs found and fixed during QA
| # | Bug | How it was found | Fix |
|---|---|---|---|
| 1 | Double-tap guard would crash release builds (frame timestamp read outside a frame) | Widget tests | Guard now tied to the route transition |
| 2 | Pushed pages (word, category, letter) could not see app services | Widget tests | `AppScope` moved above the Navigator |
| 3 | Letter chips 40 dp tall (minimum is 48) | Accessibility tests | Strip height increased |
| 4 | **Release app crashed on launch** (R8 stripped WorkManager's Room database, pulled in by AdMob) | Real device + logcat | ProGuard keep rules in `android/app/proguard-rules.pro` |
| 5 | Typing "h" returned 213 of 214 words | Real device use | 1–2 letter queries now match word starts only |
| 6 | Search ignored "œ" (e.g. "coeur") | New content | Added œ/æ/ß folding |
| 7 | `debugPrint` logged to logcat in release | Security audit | Debug-only logger |
| 8 | Kotlin build failed: project and pub cache on different drives | Build | `kotlin.incremental=false` |
| 9 | Gradle heap set to 8 GB on a 7.7 GB PC (swapping, OOM kills) | Build | Heap 3 GB, 2 workers, in-process Kotlin |

## Ads and analytics
- **Interstitial** `…/7307711501`. None before the 4th word opened in a session; after that, at most one every 3 minutes **and** every 4 words. Never on startup. Covered by unit tests.
- Debug builds always use Google's test IDs. Release builds use the real IDs.
- **Firebase Analytics** events: screen views, `view_word` (with source), `search`, `favourite_add/remove`, `share`, `copy_word`, `collection_create`, `word_of_the_day_open`. No personal data.
- The app keeps working if Firebase or AdMob fail to start.

## Known limitations
1. **Frame-timing (jank) metrics were not measured.** Android's `gfxinfo` doesn't capture Flutter frames; a `--profile` build is needed. Scrolling looked smooth during manual use.
2. **The on-device integration test** (`integration_test/app_test.dart`) was not run on the phone, to avoid another 30-minute debug build on this PC. The same journey passes as a host test.
3. **Interstitial display was not visually confirmed on the device.** The release build uses live ads, and tapping them risks invalid-click penalties. Add the phone as an AdMob test device, then verify.
4. **Builds are slow on this PC.** The project is on a removable exFAT drive and the PC has 7.7 GB of RAM. Building from a fixed NTFS drive is much faster.
5. The privacy policy (`docs/PRIVACY_POLICY.md`) still needs a support email and a public URL.

## Before you press "Publish"
- [ ] Make sure no Firebase **Admin SDK** service-account key is ever bundled or committed (revoke any that were shared)
- [ ] Back up `%USERPROFILE%\.flirtdict-keys\` (upload keystore and passwords)
- [ ] Host the privacy policy and add its URL in Play Console
- [ ] Complete the Data safety, Ads, Advertising ID, content rating and target audience (18+) forms (see `RELEASE.md`)
- [ ] AdMob: add a test device; set up the GDPR consent message; link the app after it's published
- [ ] Upload the AAB to **Internal testing** first, plus `mapping.txt`
- [ ] Store listing: 512 px icon, 1024×500 feature graphic, phone screenshots
