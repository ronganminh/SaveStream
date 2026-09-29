# SaveStream Mobile

Flutter mobile client for SaveStream.

## Current milestone

Phase 2 includes:

- Material 3 Light / Dark / System themes and VI / EN localization from Phase 1;
- `MaterialApp.router` with `go_router`;
- auth, onboarding, and session-expired guard foundation;
- stateful four-tab shell: Home, Channels, Recordings, Settings;
- preserved navigation stacks with `StatefulShellRoute.indexedStack`;
- global Flutter/router error handling and app lifecycle observer hooks;
- Riverpod repository providers;
- repository interfaces for Watches and Recordings;
- mock scenarios: success, loading, empty, error, and offline-like;
- seed mock Watches and Recordings using backend-aligned statuses;
- mock list/detail routes for Channels and Recordings;
- the Phase 1 component gallery retained at `/dev/components`.

Feature UI remains intentionally skeletal until its assigned phase.

## Requirements

- Flutter 3.47.0 stable for CI parity.
- Dart bundled with Flutter.

## Run locally

```bash
cd apps/mobile
flutter pub get
flutter gen-l10n
flutter run
```

Local environment defaults to:

```text
APP_ENV=local
API_BASE_URL=http://10.0.2.2:8000
```

Override build configuration with Dart defines:

```bash
flutter run \
  --dart-define=APP_ENV=staging \
  --dart-define=API_BASE_URL=https://api-staging.example.com
```

## Phase 2 architecture

```text
Screen
  -> Riverpod provider/controller
  -> Repository interface
  -> Mock repository

MaterialApp.router
  -> guards
  -> StatefulShellRoute
  -> four preserved tab stacks
```

The mock layer is replaceable by API repositories in later phases without moving raw HTTP into presentation code.

## Validation

```bash
flutter gen-l10n
dart format --output=none --set-exit-if-changed \
  lib/app lib/core lib/features lib/l10n/l10n.dart test
flutter analyze --fatal-infos
flutter test
```

CI runs the same checks on `feat/flutter-mobile`.
