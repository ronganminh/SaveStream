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
dart run flutter_launcher_icons
dart run flutter_native_splash:create
flutter build appbundle --release \
  --dart-define=APP_ENV=production \
  --dart-define=MOBILE_EXTERNAL_CHECKOUT_ENABLED=false
```

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

Release/Profile configuration reads:

```text
SAVESTREAM_IOS_DEVELOPMENT_TEAM
```

Provide the Apple Developer Team ID in the Xcode/CI environment and install the matching signing certificate/profile through the release system. No Team ID or private signing material is committed.

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
- Launcher icon and native splash generators run successfully.
- Production API resolves over HTTPS.
- Privacy/Terms URLs are reachable.
- External checkout is disabled unless store policy review explicitly permits it.
- Backend checkout-disabled/503 state renders as unavailable, not as payment success.
- Auth, Watch, Recording, artifact URL, Credits, Billing history, notification preferences and account deletion smoke tests pass.
- Version/build numbers are incremented before submission.
