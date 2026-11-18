# Release Runbook

## Signing credentials
| Item | Location | In git? |
|---|---|---|
| Upload keystore (PKCS12, RSA 4096, alias `upload`, valid 10,000 days) | `%USERPROFILE%\.flirtdict-keys\flirtdict-upload.jks` | **No** — outside the project |
| Passwords and keystore path | `android/key.properties` | **No** — ignored by `android/.gitignore` |
| Backup of `key.properties` | `%USERPROFILE%\.flirtdict-keys\key.properties.backup` | **No** |

> ⚠️ **Back up the `.flirtdict-keys` folder now** to a password manager or offline encrypted storage. If you enrol in Play App Signing, a lost upload key can be reset through Play Console support. Without Play App Signing, a lost key means you can never update the app again.

If `key.properties` is missing, release tasks fail with a clear error. Debug builds still work without it.

## Ads and analytics configuration
| Item | Debug / profile | Release |
|---|---|---|
| AdMob App ID (manifest) | Google test ID `ca-app-pub-3940256099942544~3347511713` | `ca-app-pub-5594205569635986~9933874844` |
| Interstitial unit | Google test unit `…/1033173712` | `ca-app-pub-5594205569635986/7307711501` |
| Firebase project | `flirt-dict` (`android/app/google-services.json`) | same |

Never tap live ads on your own device; AdMob can suspend the account for invalid clicks. To test the release build safely, add your phone as a **test device** in AdMob → Settings → Test devices.

## Build
```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

## Versioning
`version: X.Y.Z+N` in `pubspec.yaml`. `N` is the Android `versionCode` and **must increase** with every Play upload.

## Verify the bundle
```bash
# 1. Signature: the certificate must be CN=Flirt Dictionary, not "Android Debug"
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
# 2. Application ID, version code and permissions (bundletool)
java -jar bundletool.jar dump manifest --bundle build/app/outputs/bundle/release/app-release.aab
# 3. Install on a connected device
java -jar bundletool.jar build-apks --bundle=app-release.aab --output=app.apks --connected-device \
  --ks=%USERPROFILE%/.flirtdict-keys/flirtdict-upload.jks --ks-key-alias=upload
java -jar bundletool.jar install-apks --apks=app.apks
```

## Play Console checklist
- [ ] Enrol in Play App Signing and upload `app-release.aab` to the internal testing track
- [ ] **Data safety form**: *Collects data:* Yes. *Shared:* Yes (with Google for ads and analytics). *Encrypted in transit:* Yes. *Users can request deletion:* No account; data is cleared via app storage.
  - Device or other IDs (advertising ID): collected **and shared**; purposes: Advertising, Analytics, Fraud prevention
  - App activity: app interactions and in-app search history; collected; purpose: Analytics
  - App info and performance: diagnostics; collected; purpose: Analytics
  - Location: approximate (derived from IP by AdMob); collected **and shared**; purpose: Advertising
- [ ] **Ads declaration**: "Yes, my app contains ads"
- [ ] **Advertising ID declaration**: uses the advertising ID for Advertising and Analytics
- [ ] **Target audience**: 18+ (adult dating vocabulary). Do **not** select any under-13 age group, or Families policy and child-directed ad rules apply
- [ ] In the AdMob console, link the app to its Play listing once it's published (ads serve with limited fill until then)
- [ ] In the AdMob console, set up the GDPR consent message (Privacy & messaging → European regulations); without it, EEA users get no consent form and no ads
- [ ] Content rating questionnaire: reference/dictionary app; mild romantic themes, no explicit content
- [ ] Privacy policy URL: host `docs/PRIVACY_POLICY.md` (fill in the support email) on a public page, e.g. GitHub Pages or Google Sites
- [ ] Store listing: icon (512 px), feature graphic (1024×500), at least 2 phone screenshots
- [x] Custom launcher icon (white heart on rose, adaptive + themed + legacy PNGs) is already in place
