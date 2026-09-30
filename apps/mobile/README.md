# SaveStream Mobile

Flutter mobile client for SaveStream.

## Current milestone

Phase 5 includes:

- Material 3 Light / Dark / System themes and VI / EN localization from Phase 1;
- `MaterialApp.router` with `go_router`;
- complete onboarding UI with cloud-recording explanation and authorization consent;
- Sign in, Register, Verify Email, and Forgot Password flows backed by an AuthRepository;
- stateful four-tab shell: Home, Channels, Recordings, Settings;
- preserved navigation stacks with `StatefulShellRoute.indexedStack`;
- global Flutter/router error handling and app lifecycle observer hooks;
- Riverpod repository providers;
- repository interfaces for Watches and Recordings;
- mock scenarios: success, loading, empty, error, and offline-like;
- seed mock Watches and Recordings using backend-aligned statuses;
- full Channels / Watches list with LIVE/offline, Watch status, auto-record, last checked/live metadata;
- Add Channel / Watch flow with TikTok username/profile URL input, auto-record setting, and authorization confirmation;
- Channel Detail with monitoring status, auto-record toggle, pause/resume, delete, latest recording, and recording history;
- mock Watch mutations for create, pause, resume, toggle auto-record, and delete;
- Watch status coverage for active, paused, paused_insufficient_credit, paused_error, and disabled;
- mock list/detail routes for Recordings;
- auth mock outcomes for invalid credentials, unverified email, rate limits, server failure, and offline-like behavior;
- aggregated Home Dashboard via `HomeDashboardViewModel` / `homeDashboardProvider`;
- responsive Home metrics for available credit, active recordings, and monitored channels;
- usage summary, Add Channel CTA, low-credit and failed-recording alerts;
- active recording, monitored channel, and recent recording cards linked to detail routes;
- Home skeleton, empty-account, retryable error, and pull-to-refresh states;
- the Phase 1 component gallery retained at `/dev/components`.

Auth, onboarding, Home, and Channels/Watch management are now functional with mock repositories. Recordings, Billing, and Settings feature depth remains phase-scoped.

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

## Current architecture

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
