# SaveStream Mobile

Flutter client for SaveStream. The mobile app lives in the monorepo under `apps/mobile` and is developed on `feat/flutter-mobile` until a mobile milestone is ready to merge.

## SDK

Phase 0 is pinned in CI to Flutter `3.47.0` (stable).

## Run locally

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define=APP_ENV=local
```

The Android emulator default local API URL is `http://10.0.2.2:8000`.

For a physical device, iOS simulator, staging, or production, pass the API URL explicitly:

```bash
flutter run \
  --dart-define=APP_ENV=staging \
  --dart-define=API_BASE_URL=https://your-staging-api.example
```

Production and staging intentionally have no baked-in API hostname. CI/CD must inject `API_BASE_URL`.

## Checks

```bash
flutter pub get

dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
```

## Package identifiers

- Android application ID: `com.savestream.app`
- iOS bundle identifier: `com.savestream.app`

## Current scope

Phase 0 only contains the platform runners, Brand Kit asset, environment bootstrap, placeholder app, lint rules, smoke test, and CI. Product screens begin in Phase 1+ according to `docs/flutter-mobile-plan.md`.
