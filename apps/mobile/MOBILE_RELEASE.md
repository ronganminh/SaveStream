# SaveStream Mobile Release

Phase 17 turns the Flutter client into a release-ready native package while keeping cloud recording authoritative.

## Product model

The v1.x cleanup build (2.0.1+) records in the cloud only. On-device (Local) recording, rewarded ads and all ad placements were removed; the recordings library lists cloud recordings only. Users can still download a cloud recording to app-private storage to play or share it. Ads return in v2 with IDs supplied by build config.

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

## Ads

This build ships no ads SDK (`google_mobile_ads` removed), no AdMob app/unit IDs, no UMP consent gate and no iOS ATT prompt. Do not add hardcoded ad IDs back; v2 will read them from build config.

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

## Notifications and Firebase Cloud Messaging

Mobile notification preferences use the persisted backend contract:

```text
GET   /v1/me/notification-preferences
PATCH /v1/me/notification-preferences
```

Firebase app configuration is release input and is intentionally not tracked in Git. Before a real build, place:

```text
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

CI generates non-production placeholder files with `tool/generate_firebase_ci_config.sh` only to compile the app.

The mobile client registers the current FCM token, token refreshes, locale and app version through `PUT /v1/me/devices/{device_id}`. Android creates separate notification channels for Creator LIVE and recording events. Push taps route by `resource_type` and `resource_id`; foreground messages render inside SaveStream instead of showing a system notification.

For production delivery, configure `SAVESTREAM_PUSH_PROVIDER=fcm` and provide `SAVESTREAM_PUSH_FCM_SERVICE_ACCOUNT_JSON` to the backend outside Git. For iOS runtime push, upload the APNs authentication key to Firebase and configure the Apple Team/Key IDs before device testing.

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


## C9 production configuration

The release version started at `2.0.0+1`; the v1.x cleanup build is `2.0.1+9`. Increment the build number for every store upload.

Supported production Dart defines:

```text
APP_ENV=production
API_BASE_URL=https://api.savestream.online
PRIVACY_POLICY_URL=https://savestream.online/privacy
TERMS_OF_USE_URL=https://savestream.online/terms
APP_VERSION=2.0.1
```

Firebase app files and signing material remain outside Git.

## C9 permission and privacy audit

Android release permissions are intentionally limited to:

- `INTERNET`: authenticated API, Firebase, store billing and artifact URLs.
- `POST_NOTIFICATIONS`: FCM notifications on Android 13+.

No foreground-service permission is declared (the on-device recorder service was removed).

No location, contacts, camera, microphone, broad storage or media-library permission is declared.

iOS `Info.plist` contains no ATT usage description (ads are removed) and only local-network development transport configuration. No camera, microphone, contacts, location or photo-library usage description is declared.

## C9 R8 / release shrinking

Android release builds enable R8 code shrinking and resource shrinking with `android/app/proguard-rules.pro`. The app keeps SaveStream native entry points, Flutter generated plugin registration and Firebase Messaging plugin classes while relying on SDK consumer rules for the remaining plugins.

Before publishing, run the exact release AAB through the emulator/device smoke flow and verify Firebase push, Store billing, cloud recording and artifact playback after shrinking.

## Store data disclosure inventory

Use this inventory when filling Google Play Data safety / App Store privacy declarations:

- account identity and authenticated device registration identifiers;
- FCM push token and notification preferences;
- purchase/order/transaction history used for store verification and cloud-hour crediting;
- support diagnostics such as request IDs and issue reports actually submitted by the user;
- creator/watch configuration and recording metadata required to provide the SaveStream service.

SaveStream does not require background location, contacts, microphone, camera or broad media-library access for the Android-first release.

The owner-operated release steps are tracked in `docs/v2/RELEASE_CHECKLIST_MOBILE.md`.
