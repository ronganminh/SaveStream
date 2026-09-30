# SaveStream Mobile

Flutter mobile client for SaveStream.

## Current milestone

Phase 7 includes:

- Material 3 Light / Dark / System themes and VI / EN localization from Phase 1;
- `MaterialApp.router` with `go_router`;
- complete onboarding UI with cloud-recording explanation and authorization consent;
- Sign in, Register, Verify Email, and Forgot Password flows backed by an AuthRepository;
- stateful four-tab shell: Home, Channels, Recordings, Settings;
- preserved navigation stacks with `StatefulShellRoute.indexedStack`;
- global Flutter/router error handling and app lifecycle observer hooks;
- Riverpod repository providers;
- repository interfaces for Watches, Recordings, Credits, and Billing;
- mock scenarios: success, loading, empty, error, and offline-like;
- seed mock Watches and Recordings using backend-aligned statuses;
- full Channels / Watches list with LIVE/offline, Watch status, auto-record, last checked/live metadata;
- Add Channel / Watch flow with TikTok username/profile URL input, auto-record setting, and authorization confirmation;
- Channel Detail with monitoring status, auto-record toggle, pause/resume, delete, latest recording, and recording history;
- mock Watch mutations for create, pause, resume, toggle auto-record, and delete;
- Watch status coverage for active, paused, paused_insufficient_credit, paused_error, and disabled;
- full Recordings list with All / Active / Completed / Failed filters;
- cursor-based mock pagination with Load More, pull-to-refresh, filter-specific empty states, skeletons, and retryable errors;
- recording cards with creator, lifecycle status, start time, duration, size, cost, artifact, thumbnail, and progress metadata;
- lifecycle-specific detail UI for queued, resolving, waiting_live, recording, processing, uploading, completed, failed, stop_requested, and stopped;
- Stop / Retry / Delete actions driven by backend-aligned `actions.can_stop`, `actions.can_retry`, and `actions.can_delete` flags;
- mutable mock recording actions for stop, retry, and delete, with Home and Channel recording history refresh signals;
- artifact Play / Download UI gated by artifact readiness and reserved for real backend integration in Phase 12;
- Credits / Usage screen with backend-aligned posted, reserved, and available balances;
- low-credit explanation, recording usage totals, recent credit transactions, empty/loading/error states, and pull-to-refresh;
- Billing screen with credit packages, recommended package treatment, recent payment orders, and buy CTA;
- payment order status coverage for pending, paid, failed, cancelled, and expired;
- mock checkout flow that creates pending orders and only transitions to paid after a repository status refetch, matching the backend-confirmation rule;
- Settings entries for Credits and Billing plus direct Home low-credit navigation;
- auth mock outcomes for invalid credentials, unverified email, rate limits, server failure, and offline-like behavior;
- aggregated Home Dashboard via `HomeDashboardViewModel` / `homeDashboardProvider`;
- responsive Home metrics for available credit, active recordings, and monitored channels;
- usage summary, Add Channel CTA, low-credit and failed-recording alerts;
- active recording, monitored channel, and recent recording cards linked to detail routes;
- Home skeleton, empty-account, retryable error, and pull-to-refresh states;
- the Phase 1 component gallery retained at `/dev/components`.

Auth, onboarding, Home, Channels/Watch management, Recordings, Credits/Usage, and Billing are now functional with mock repositories. Settings profile/preferences depth remains phase-scoped.

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
