# SaveStream Mobile

Flutter client for SaveStream V2.

## Architecture

The mobile app is a Material 3 Flutter application using Riverpod for dependency/state management and `go_router` for navigation. Production builds use typed API repositories backed by `ApiClient`; mock repositories remain available for isolated UI tests and developer scenarios.

Main layers:

- `lib/app` — bootstrap, routing, shell, theme, session and global gates.
- `lib/core` — API client, configuration, storage helpers and shared widgets.
- `lib/features` — auth, Home, Channels/Watches, Recordings, local recording, entitlement/store, rewards/ads, settings and app-status flows.
- `lib/platform` — native contracts plus production/fake implementations for local recording, playback, sharing, purchases, ads and device services.

## V2 product behavior

Implemented on `main` before C9:

- real auth/session flow with secure refresh-token storage;
- backend-authoritative Free/paid entitlement, Watch limits and cloud-concurrency limits;
- Channels/Watch CRUD, LIVE state and auto-record state;
- Android local recording in app-private storage with foreground-service recovery and ownership isolation;
- cloud recording lifecycle including per-user slot queue, player, download/resume, sharing and deletion;
- native App Store / Google Play cloud-hour purchases with backend receipt verification and durable retry;
- Free-plan AdMob banners/rewarded ads with UMP consent and rewarded SSV; paid users do not initialize ads;
- persisted notification preferences, legal links, maintenance/minimum-version gates and EN/VI localization;
- Light/Dark/System theme plus responsive/accessibility coverage.

C8 Firebase push is intentionally not shipped yet. Do not claim production push notifications in store copy until C8 is completed with the production Firebase project.

## Requirements

- Flutter `3.47.0` for CI parity.
- Dart bundled with that Flutter release.
- Android SDK and Java 17 for Android builds.
- Xcode for the compile-only iOS regression gate.
- Python 3 plus Cairo for native brand raster generation.

After cloning:

```bash
cd apps/mobile
flutter pub get --enforce-lockfile
bash tool/generate_native_assets.sh
```

## Run locally

Android emulator against a backend on the host machine:

```bash
flutter run \
  --dart-define=APP_ENV=local \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Production defaults are defined in `AppConfig`: `https://api.savestream.online`, `https://savestream.online/privacy`, and `https://savestream.online/terms`.

## Tests and local gates

```bash
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib/app lib/core lib/features lib/l10n/l10n.dart test
flutter analyze --fatal-infos
flutter test
bash tool/release_audit.sh
```

The repository also runs **Mobile Backend E2E**. It boots the real backend stack and exercises mobile auth, entitlement, the Free Watch limit, billing, cloud recording/artifacts and the per-user cloud-slot queue without a physical device.

## Production build inputs

Current Dart defines:

```text
APP_ENV=production
APP_VERSION=2.0.0
API_BASE_URL=https://api.savestream.online            # optional override
PRIVACY_POLICY_URL=https://savestream.online/privacy # optional override
TERMS_OF_USE_URL=https://savestream.online/terms     # optional override
ADMOB_BANNER_HOME_ANDROID
ADMOB_BANNER_WATCH_ANDROID
ADMOB_BANNER_LIBRARY_ANDROID
ADMOB_REWARDED_ANDROID
ADMOB_BANNER_HOME_IOS
ADMOB_BANNER_WATCH_IOS
ADMOB_BANNER_LIBRARY_IOS
ADMOB_REWARDED_IOS
```

The iOS ad-unit defines are retained for the deferred iOS release. Do not pass secrets through `--dart-define`.

Android release signing and the AdMob application ID are supplied outside Git:

```text
SAVESTREAM_ANDROID_KEYSTORE_PATH
SAVESTREAM_ANDROID_KEYSTORE_PASSWORD
SAVESTREAM_ANDROID_KEY_ALIAS
SAVESTREAM_ANDROID_KEY_PASSWORD
SAVESTREAM_ADMOB_ANDROID_APP_ID
```

See `MOBILE_RELEASE.md` and `docs/v2/RELEASE_CHECKLIST_MOBILE.md` for the authoritative release procedure, manual device/store checks and data-safety inventory.

## Current release target

The first V2 store release is Android-only by owner decision. CI keeps the iOS production configuration compiling, but a signed iOS archive, TestFlight run and iOS runtime claim are not part of this release.
