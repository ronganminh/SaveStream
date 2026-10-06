# SaveStream Mobile Release

Phase 17 turns the Flutter client into a release-ready native package while keeping cloud recording authoritative.

## Product model

SaveStream V2 supports both cloud recording and local recording on the user's device. Cloud artifacts remain authoritative for cloud recordings; local recording files stay in app-private device storage.

Recording Play / Download requests a fresh backend presigned artifact URL and opens it through the platform/browser. The backend/cloud storage remains the source of truth.

## Production build

Production API defaults to:

```text
https://api.savestream.online
```

Build Android production:

```bash
flutter pub get --enforce-lockfile
bash tool/generate_native_assets.sh
flutter build appbundle --release \
  --dart-define=APP_ENV=production
```

Launcher icons and the native splash are generated from `assets/branding/savestream_mark.svg` and are **not committed**. `tool/generate_native_assets.sh` must run once after cloning, and again whenever the brand mark changes, before any Android or iOS build; without it the build cannot resolve `@mipmap/ic_launcher` or the iOS `AppIcon`. It needs Python 3 and the Cairo library (`brew install cairo` on macOS).

Mobile cloud-hour purchases use the native App Store / Google Play billing flow. The mobile app has no external hosted checkout switch.

## Store purchase sandbox verification

C6 code and CI use fake store/plugin behavior; no real store transaction is run in CI. Before release, verify:

- App Store Sandbox: load all three consumable products, confirm localized prices come from StoreKit, buy each product, cancel once, and exercise a pending approval flow if available.
- Google Play license tester: load all three one-time products, buy each product, cancel once, and exercise a pending purchase flow.
- For a successful purchase, confirm the backend returns `credited` before the app completes the store transaction, then verify entitlement, Channels and Home refresh.
- Disable networking after store purchase but before backend verification, relaunch, restore connectivity, and confirm the persisted transaction retries without double credit.
- Relaunch with an unfinished transaction and confirm backend replay is idempotent and the store transaction completes only after `credited`.
- Restore purchases and confirm restored transactions are verified by the backend before completion.

Record device/OS, store environment, product ID, transaction ID (non-secret), backend result, and final cloud-minute balance in release evidence.

## C7 ads and consent

Free-plan ads use Google Mobile Ads with UMP consent. Production ad unit IDs are supplied at build time; when omitted, the app uses Google demo/test units so CI and development do not generate live traffic.

Android production ad unit defines:

```text
ADMOB_BANNER_HOME_ANDROID
ADMOB_BANNER_WATCH_ANDROID
ADMOB_BANNER_LIBRARY_ANDROID
ADMOB_REWARDED_ANDROID
```

iOS production ad unit defines:

```text
ADMOB_BANNER_HOME_IOS
ADMOB_BANNER_WATCH_IOS
ADMOB_BANNER_LIBRARY_IOS
ADMOB_REWARDED_IOS
```

The Android AdMob app ID continues to come from `SAVESTREAM_ADMOB_ANDROID_APP_ID`. For iOS release signing, set the real `ADMOB_APP_ID` in the private release xcconfig. Configure GDPR/privacy messages and the iOS IDFA/ATT message in AdMob Privacy & messaging before store release.

Manual C7 checks:

- Free account with zero watched creators: confirm no UMP prompt and no ad request occurs.
- Free account after the first creator is added: complete the in-app explanation, then verify UMP appears only when required for the region.
- iOS: verify the localized ATT description appears only when the AdMob IDFA flow needs the system prompt.
- Pro account: confirm Google Mobile Ads is never initialized and no consent prompt appears.
- Home, Watch list and Library: verify adaptive banners collapse to zero height on no-fill.
- Recording, purchase and player screens: confirm no banner request is made.
- Rewarded local-minutes/local-slot flow: verify `ssv_user_id` and `ssv_custom_data` from `POST /v1/rewards` reach AdMob SSV, then wait for backend `valid` before granting the reward.

## Android signing

Never commit a keystore or passwords. The Gradle release config reads:

```text
SAVESTREAM_ANDROID_KEYSTORE_PATH
SAVESTREAM_ANDROID_KEYSTORE_PASSWORD
SAVESTREAM_ANDROID_KEY_ALIAS
SAVESTREAM_ANDROID_KEY_PASSWORD
```

A CI/store release must provide all four values. Without them, CI may compile an unsigned release bundle for validation, but that artifact is not publishable.

## iOS signing

CI has no Apple Team ID, so it only compiles the production configuration for the simulator in debug mode (Flutter does not support release builds on the simulator). That check does not validate a signed archive; run `flutter build ipa --release` with the signing config below before a store submission.

For a signed App Store/TestFlight build, copy:

```text
ios/Flutter/ReleaseSigning.xcconfig.example
```

to:

```text
ios/Flutter/ReleaseSigning.xcconfig
```

and set the real `DEVELOPMENT_TEAM`. The real signing config is gitignored. Install the matching signing certificate/profile through the release system. No private signing material is committed.

## Legal

Published production URLs:

```text
https://savestream.online/privacy
https://savestream.online/terms
```

The app opens these published documents externally.

## Notifications

Mobile notification preferences use the persisted backend contract:

```text
GET   /v1/me/notification-preferences
PATCH /v1/me/notification-preferences
```

Current backend delivery is in-app only. The app does not claim email/push delivery when the backend does not support it.

## Release checklist

- Mobile CI green on the exact release commit.
- `pubspec.lock` committed and `flutter pub get --enforce-lockfile` succeeds.
- Android release is not using debug signing.
- Store signing secrets are installed outside Git.
- `assets/branding/savestream_mark.svg` matches the official Brand Kit mark.
- The official SVG rasterizes successfully before launcher icon/native splash generation.
- Launcher icon and native splash generators run successfully.
- Production API resolves over HTTPS.
- Privacy/Terms URLs are reachable.
- Mobile uses native App Store / Google Play purchases only; no external checkout route is exposed.
- Backend checkout-disabled/503 state renders as unavailable, not as payment success.
- Auth, Watch, Recording, artifact URL, Credits, Billing history, notification preferences and account deletion smoke tests pass.
- Version/build numbers are incremented before submission.


## C3 Android local-recording final APK checks

Real-device checks are intentionally deferred to the final APK pass. Record model, Android version, battery start/end, free storage start/end, recorded duration and resulting file size for each run.

- Record for 10 minutes in foreground, then repeat with the screen locked.
- Start recording, switch to another app for 10 minutes, and confirm the foreground service remains active.
- Disconnect networking for 30 seconds, reconnect, and verify reconnecting returns to recording without charging/claiming disconnected time.
- Force-stop or kill the app during capture, relaunch, and verify the interrupted file is detected and recovery ends as recovered or partial.
- Reduce free storage below 250 MB and verify recording stops safely without deleting captured bytes.
- Use the notification Stop action and verify stopping finalizes the file without opening the app.
- Sign out while a granted lease is active and verify capture is not truncated solely because the auth session ended.
- Verify app-private files remain under the source `user_id` and are hidden after a different account signs in; sign back into the original account and confirm they are visible again.
- Check the Android battery-optimization state shown by the app, open the corresponding system battery settings, switch to unrestricted where supported, then return and confirm the state refreshes.
