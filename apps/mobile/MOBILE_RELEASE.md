# SaveStream Mobile Release

Phase 17 turns the Flutter client into a release-ready native package while keeping cloud recording authoritative.

## Product model

The mobile app is a client for SaveStream cloud recording. It does **not** record livestreams on-device and does not persist recording artifacts into app storage.

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
  --dart-define=APP_ENV=production \
  --dart-define=MOBILE_EXTERNAL_CHECKOUT_ENABLED=false
```

Launcher icons and the native splash are generated from `assets/branding/savestream_mark.svg` and are **not committed**. `tool/generate_native_assets.sh` must run once after cloning, and again whenever the brand mark changes, before any Android or iOS build; without it the build cannot resolve `@mipmap/ic_launcher` or the iOS `AppIcon`. It needs Python 3 and the Cairo library (`brew install cairo` on macOS).

The external Lemon Squeezy checkout gate is deliberately **off by default** for native production builds. Enable it only for a distribution channel whose App Store / Google Play payment policy has been reviewed and approved:

```text
--dart-define=MOBILE_EXTERNAL_CHECKOUT_ENABLED=true
```

This flag is a release-policy gate, not a bypass for store rules.

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
- External checkout is disabled unless store policy review explicitly permits it.
- Backend checkout-disabled/503 state renders as unavailable, not as payment success.
- Auth, Watch, Recording, artifact URL, Credits, Billing history, notification preferences and account deletion smoke tests pass.
- Version/build numbers are incremented before submission.
